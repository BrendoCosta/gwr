import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/yielder

import gleb128
import ieee_float

import gwr/parser/byte_reader
import gwr/parser/parsing_error
import gwr/spec

/// ***************************************************************************
/// parser/binary_parser
/// ***************************************************************************
pub fn parse_locals_declaration(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.LocalsDeclaration),
  parsing_error.ParsingError,
) {
  use #(reader, count) <- result.try(parse_unsigned_leb128_integer(from: reader))
  use #(reader, value_type) <- result.try(parse_value_type(from: reader))
  Ok(#(reader, spec.LocalsDeclaration(count: count, type_: value_type)))
}

pub fn parse_function_code(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.FunctionCode),
  parsing_error.ParsingError,
) {
  use #(reader, locals_declaration) <- result.try(parse_vector(
    from: reader,
    with: parse_locals_declaration,
  ))
  use #(reader, expression) <- result.try(parse_expression(from: reader))
  Ok(#(reader, spec.FunctionCode(locals: locals_declaration, body: expression)))
}

pub fn parse_code(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Code), parsing_error.ParsingError) {
  use #(reader, size) <- result.try(parse_unsigned_leb128_integer(from: reader))
  use #(reader, function_code) <- result.try(parse_function_code(from: reader))
  Ok(#(reader, spec.Code(size: size, function_code: function_code)))
}

pub fn parse_section(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Section), parsing_error.ParsingError) {
  use #(reader, section_type_id) <- result.try(
    case byte_reader.read(from: reader, take: 1) {
      Ok(#(reader, <<section_type_id>>)) -> Ok(#(reader, section_type_id))
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parser.parse_section: can't get section type id raw data",
        )
        |> parsing_error.to_error()
    },
  )

  use #(reader, section_length) <- result.try(parse_unsigned_leb128_integer(
    from: reader,
  ))

  use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
  let remaining_data_length = bit_array.byte_size(remaining_data)

  use <- bool.guard(
    when: section_length > remaining_data_length,
    return: parsing_error.new()
      |> parsing_error.add_message(
        "gwr/parser/parser.parse_section: unexpected end of the section's content segment. Expected "
        <> int.to_string(section_length)
        <> " bytes but got "
        <> int.to_string(remaining_data_length)
        <> " bytes",
      )
      |> parsing_error.to_error(),
  )

  use #(reader, decoded_dection) <- result.try(
    case byte_reader.can_read(reader), section_type_id {
      // the reverse order throws a syntax error xD
      True, id if id == spec.custom_section_id -> {
        use #(reader, custom_section_name) <- result.try(parse_name(
          from: reader,
        ))
        use #(reader, custom_section_data) <- result.try(
          byte_reader.read_remaining(from: reader),
        )
        Ok(#(
          reader,
          spec.Section(
            id: spec.custom_section_id,
            length: section_length,
            content: option.Some(spec.CustomSection(
              name: custom_section_name,
              data: option.Some(custom_section_data),
            )),
          ),
        ))
      }
      True, id if id == spec.type_section_id -> {
        use #(reader, function_types_vec) <- result.try(parse_vector(
          from: reader,
          with: parse_function_type,
        ))
        Ok(#(
          reader,
          spec.Section(
            id: spec.type_section_id,
            length: section_length,
            content: option.Some(spec.TypeSection(
              function_types: function_types_vec,
            )),
          ),
        ))
      }
      // @TODO True, id if id == import_section_id -> {}
      True, id if id == spec.function_section_id -> {
        use #(reader, indices_vec) <- result.try(
          parse_vector(from: reader, with: fn(reader) {
            use #(reader, index) <- result.try(parse_unsigned_leb128_integer(
              from: reader,
            ))
            Ok(#(reader, index))
          }),
        )

        Ok(#(
          reader,
          spec.Section(
            id: spec.function_section_id,
            length: section_length,
            content: option.Some(spec.FunctionSection(type_indices: indices_vec)),
          ),
        ))
      }
      // @TODO True, id if id == table_section_id -> {}
      True, id if id == spec.memory_section_id -> {
        use #(reader, mem_vec) <- result.try(parse_vector(
          from: reader,
          with: parse_memory,
        ))
        Ok(#(
          reader,
          spec.Section(
            id: spec.memory_section_id,
            length: section_length,
            content: option.Some(spec.MemorySection(memories: mem_vec)),
          ),
        ))
      }
      True, id if id == spec.global_section_id -> {
        use #(reader, globals_vec) <- result.try(parse_vector(
          from: reader,
          with: parse_global,
        ))
        Ok(#(
          reader,
          spec.Section(
            id: spec.global_section_id,
            length: section_length,
            content: option.Some(spec.GlobalSection(globals: globals_vec)),
          ),
        ))
      }
      True, id if id == spec.export_section_id -> {
        use #(reader, exports_vec) <- result.try(parse_vector(
          from: reader,
          with: parse_export,
        ))
        Ok(#(
          reader,
          spec.Section(
            id: spec.export_section_id,
            length: section_length,
            content: option.Some(spec.ExportSection(exports: exports_vec)),
          ),
        ))
      }
      // @TODO True, id if id == start_section_id -> {}
      // @TODO True, id if id == element_section_id -> {}
      True, id if id == spec.code_section_id -> {
        use #(reader, codes_vec) <- result.try(parse_vector(
          from: reader,
          with: parse_code,
        ))
        Ok(#(
          reader,
          spec.Section(
            id: spec.code_section_id,
            length: section_length,
            content: option.Some(spec.CodeSection(entries: codes_vec)),
          ),
        ))
      }

      // @TODO True, id if id == data_section_id -> {}
      // @TODO True, id if id == data_count_section_id -> {}
      // Empty sections are allowed
      False, id if id == spec.custom_section_id ->
        Ok(#(
          reader,
          spec.Section(
            id: spec.custom_section_id,
            length: section_length,
            content: option.None,
          ),
        ))
      False, id if id == spec.type_section_id ->
        Ok(#(
          reader,
          spec.Section(
            id: spec.type_section_id,
            length: section_length,
            content: option.None,
          ),
        ))
      // @TODO False, id if id == import_section_id -> {}
      False, id if id == spec.function_section_id ->
        Ok(#(
          reader,
          spec.Section(
            id: spec.function_section_id,
            length: section_length,
            content: option.None,
          ),
        ))
      // @TODO False, id if id == table_section_id -> {}
      False, id if id == spec.memory_section_id ->
        Ok(#(
          reader,
          spec.Section(
            id: spec.memory_section_id,
            length: section_length,
            content: option.None,
          ),
        ))
      // @TODO False, id if id == global_section_id -> {}
      False, id if id == spec.export_section_id ->
        Ok(#(
          reader,
          spec.Section(
            id: spec.export_section_id,
            length: section_length,
            content: option.None,
          ),
        ))
      // @TODO False, id if id == start_section_id -> {}
      // @TODO False, id if id == element_section_id -> {}
      False, id if id == spec.code_section_id ->
        Ok(#(
          reader,
          spec.Section(
            id: spec.code_section_id,
            length: section_length,
            content: option.None,
          ),
        ))
      _, _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parser.parse_section: unknown section type id \""
          <> int.to_string(section_type_id)
          <> "\"",
        )
        |> parsing_error.to_error()
    },
  )
  Ok(#(reader, decoded_dection))
}

pub fn parse_binary_module(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Binary), parsing_error.ParsingError) {
  use <- bool.guard(
    when: byte_reader.is_empty(reader),
    return: parsing_error.new()
      |> parsing_error.add_message(
        "gwr/parser/parser.parse_binary_module: empty data",
      )
      |> parsing_error.to_error(),
  )

  // https://webassembly.github.io/spec/core/binary/module.html#binary-module
  // 
  // The encoding of a module starts with a preamble containing a 4-byte magic number (the string '\0asm')
  // and a version field. The current version of the WebAssembly binary format is 1.

  let #(reader, found_magic_number) = case
    byte_reader.read(from: reader, take: 4)
  {
    Ok(#(reader, <<0x00, 0x61, 0x73, 0x6d>>)) -> #(reader, True)
    Ok(#(reader, _)) -> #(reader, False)
    Error(_) -> #(reader, False)
  }

  use <- bool.guard(
    when: !found_magic_number,
    return: parsing_error.new()
      |> parsing_error.add_message(
        "gwr/parser/parser.parse_binary_module: couldn't find module's magic number",
      )
      |> parsing_error.to_error(),
  )

  // @TODO: I couldn't figure out the version number binary encoding from the spec (LE32 or LEB128 ?),
  // therefore the code below may be fixed.
  use #(reader, module_wasm_version) <- result.try(
    case byte_reader.read(from: reader, take: 4) {
      Ok(#(reader, <<version:unsigned-little-size(32)>>)) ->
        Ok(#(reader, version))
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parser.parse_binary_module: couldn't find module version",
        )
        |> parsing_error.to_error()
    },
  )

  let empty_module =
    spec.Module(
      types: [],
      functions: [],
      tables: [],
      memories: [],
      globals: [],
      elements: [],
      datas: [],
      start: option.None,
      imports: [],
      exports: [],
    )

  use #(reader, filled_module, _) <- result.try(
    yielder.fold(
      from: Ok(#(reader, empty_module, [])),
      over: yielder.range(from: 0x00, to: 0x0c),
      with: fn(state, _) {
        use #(reader, module, function_section_type_indices) <- result.try(
          state,
        )

        use <- bool.guard(when: !byte_reader.can_read(reader), return: state)
        use #(reader, section) <- result.try(parse_section(from: reader))

        use #(module, function_section_type_indices) <- result.try(
          case section.content {
            option.None -> Ok(#(module, function_section_type_indices))
            option.Some(content) -> {
              case content {
                spec.CustomSection(name: _, data: _) ->
                  Ok(#(module, function_section_type_indices))
                spec.TypeSection(function_types: function_types) -> {
                  Ok(#(
                    spec.Module(..module, types: function_types),
                    function_section_type_indices,
                  ))
                }
                spec.ImportSection ->
                  Ok(#(module, function_section_type_indices))
                spec.FunctionSection(type_indices: type_indices_list) -> {
                  // Here we set function_section_type_indices
                  Ok(#(module, type_indices_list))
                }
                spec.TableSection ->
                  Ok(#(module, function_section_type_indices))
                spec.MemorySection(memories: memories_list) -> {
                  Ok(#(
                    spec.Module(..module, memories: memories_list),
                    function_section_type_indices,
                  ))
                }
                spec.GlobalSection(globals: globals_list) -> {
                  Ok(#(
                    spec.Module(..module, globals: globals_list),
                    function_section_type_indices,
                  ))
                }
                spec.ExportSection(exports: exports_list) -> {
                  Ok(#(
                    spec.Module(..module, exports: exports_list),
                    function_section_type_indices,
                  ))
                }
                spec.StartSection(start_function: start_function) -> {
                  Ok(#(
                    spec.Module(..module, start: option.Some(start_function)),
                    function_section_type_indices,
                  ))
                }
                spec.ElementSection ->
                  Ok(#(module, function_section_type_indices))
                spec.CodeSection(entries: code_entries) -> {
                  use function_list <- result.try(
                    list.index_fold(
                      over: code_entries,
                      from: Ok([]),
                      with: fn(function_list, entry, index) {
                        use function_list <- result.try(function_list)
                        case
                          function_section_type_indices
                          |> list.take(up_to: index + 1)
                          |> list.last
                        {
                          Ok(function_type_index) -> {
                            let function =
                              spec.Function(
                                type_: function_type_index,
                                locals: list.map(
                                  entry.function_code.locals,
                                  fn(locals_declaration) {
                                    list.repeat(
                                      locals_declaration.type_,
                                      locals_declaration.count,
                                    )
                                  },
                                )
                                  |> list.flatten,
                                body: entry.function_code.body,
                              )
                            Ok(list.append(function_list, [function]))
                          }
                          Error(_) ->
                            parsing_error.new()
                            |> parsing_error.add_message(
                              "gwr/parser/parser.parse_binary_module: couldn't find type index "
                              <> int.to_string(index),
                            )
                            |> parsing_error.to_error()
                        }
                      },
                    ),
                  )
                  Ok(#(
                    spec.Module(..module, functions: function_list),
                    function_section_type_indices,
                  ))
                }
                spec.DataSection -> Ok(#(module, function_section_type_indices))
                spec.DataCountSection ->
                  Ok(#(module, function_section_type_indices))
              }
            }
          },
        )

        Ok(#(reader, module, function_section_type_indices))
      },
    ),
  )

  Ok(#(
    reader,
    spec.Binary(
      version: module_wasm_version,
      length: byte_reader.bytes_read(from: reader),
      module: filled_module,
    ),
  ))
}

/// ***************************************************************************
/// parser/convention_parser
/// ***************************************************************************
pub fn parse_vector(
  from reader: byte_reader.ByteReader,
  with parse_element: fn(byte_reader.ByteReader) ->
    Result(#(byte_reader.ByteReader, a), parsing_error.ParsingError),
) -> Result(
  #(byte_reader.ByteReader, spec.Vector(a)),
  parsing_error.ParsingError,
) {
  use #(reader, vector_length) <- result.try(parse_unsigned_leb128_integer(
    from: reader,
  ))

  // If we got a empty vector, then no parsing should be done at all
  use <- bool.guard(when: vector_length == 0, return: Ok(#(reader, [])))

  use #(reader, objects_list) <- result.try(
    yielder.try_fold(
      over: yielder.range(from: 0, to: vector_length - 1),
      from: #(reader, []),
      with: fn(state, _index) {
        let #(reader, objects_list) = state
        use <- bool.guard(
          when: !byte_reader.can_read(reader),
          return: Ok(state),
        )
        use #(reader, object) <- result.try(parse_element(reader))
        Ok(#(reader, list.append(objects_list, [object])))
      },
    ),
  )

  Ok(#(reader, objects_list))
}

/// ***************************************************************************
/// parser/instruction_parser
/// ***************************************************************************
pub fn parse_instruction(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.Instruction),
  parsing_error.ParsingError,
) {
  use #(reader, opcode) <- result.try(
    case byte_reader.read(from: reader, take: 1) {
      Ok(#(reader, <<opcode>>)) -> Ok(#(reader, opcode))
      Error(reason) -> Error(reason)
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_instruction: unknown error reading opcode",
        )
        |> parsing_error.to_error()
    },
  )

  use #(reader, instruction) <- result.try(case opcode {
    // Control Instructions
    // https://webassembly.github.io/spec/core/binary/instructions.html#control-instructions
    0x00 -> Ok(#(reader, spec.Unreachable))
    0x01 -> Ok(#(reader, spec.NoOp))
    0x02 -> {
      use #(reader, block_type) <- result.try(parse_block_type(from: reader))
      use #(reader, expression) <- result.try(parse_expression(from: reader))
      Ok(#(reader, spec.Block(block_type: block_type, instructions: expression)))
    }
    0x03 -> {
      use #(reader, block_type) <- result.try(parse_block_type(from: reader))
      use #(reader, expression) <- result.try(parse_expression(from: reader))
      Ok(#(reader, spec.Loop(block_type: block_type, instructions: expression)))
    }
    0x04 -> {
      use #(reader, block_type) <- result.try(parse_block_type(from: reader))
      use #(reader, body) <- result.try(
        parse_instructions_until(from: reader, with: fn(inst) {
          case inst {
            spec.End -> True
            spec.Else(_) -> True
            _ -> False
          }
        }),
      )
      case list.last(body) {
        Ok(spec.End) ->
          Ok(#(
            reader,
            spec.If(
              block_type: block_type,
              instructions: body,
              else_: option.None,
            ),
          ))
        Ok(spec.Else(_) as els) ->
          Ok(#(
            reader,
            spec.If(
              block_type: block_type,
              instructions: list.take(from: body, up_to: list.length(body) - 1),
              else_: option.Some(els),
            ),
          ))
        _ ->
          parsing_error.new()
          |> parsing_error.add_message(
            "gwr/parser/parse_instruction: expected the If instruction's block to end either with an End instruction or an Else instruction",
          )
          |> parsing_error.to_error()
      }
    }
    0x05 -> {
      use #(reader, expression) <- result.try(parse_expression(from: reader))
      Ok(#(reader, spec.Else(instructions: expression)))
    }
    0xc -> {
      use #(reader, label_index) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.Br(index: label_index)))
    }
    0xd -> {
      use #(reader, label_index) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.BrIf(index: label_index)))
    }
    0xf -> Ok(#(reader, spec.Return))
    0x10 -> {
      use #(reader, function_index) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.Call(index: function_index)))
    }
    // Variable Instructions
    // https://webassembly.github.io/spec/core/binary/instructions.html#variable-instructions
    0x20 -> {
      use #(reader, local_index) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.LocalGet(index: local_index)))
    }
    0x21 -> {
      use #(reader, local_index) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.LocalSet(index: local_index)))
    }
    0x22 -> {
      use #(reader, local_index) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.LocalTee(index: local_index)))
    }
    // Numeric Instructions
    // https://webassembly.github.io/spec/core/binary/instructions.html#numeric-instructions
    0x41 -> {
      use #(reader, value) <- result.try(parse_uninterpreted_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.I32Const(value: value)))
    }
    0x42 -> {
      use #(reader, value) <- result.try(parse_uninterpreted_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, spec.I64Const(value: value)))
    }
    0x43 -> {
      use #(reader, value) <- result.try(parse_le32_float(from: reader))
      Ok(#(reader, spec.F32Const(value: value)))
    }
    0x44 -> {
      use #(reader, value) <- result.try(parse_le64_float(from: reader))
      Ok(#(reader, spec.F64Const(value: value)))
    }
    0x45 -> Ok(#(reader, spec.I32Eqz))
    0x46 -> Ok(#(reader, spec.I32Eq))
    0x47 -> Ok(#(reader, spec.I32Ne))
    0x48 -> Ok(#(reader, spec.I32LtS))
    0x49 -> Ok(#(reader, spec.I32LtU))
    0x4a -> Ok(#(reader, spec.I32GtS))
    0x4b -> Ok(#(reader, spec.I32GtU))
    0x4c -> Ok(#(reader, spec.I32LeS))
    0x4d -> Ok(#(reader, spec.I32LeU))
    0x4e -> Ok(#(reader, spec.I32GeS))
    0x4f -> Ok(#(reader, spec.I32GeU))
    0x50 -> Ok(#(reader, spec.I64Eqz))
    0x51 -> Ok(#(reader, spec.I64Eq))
    0x52 -> Ok(#(reader, spec.I64Ne))
    0x53 -> Ok(#(reader, spec.I64LtS))
    0x54 -> Ok(#(reader, spec.I64LtU))
    0x55 -> Ok(#(reader, spec.I64GtS))
    0x56 -> Ok(#(reader, spec.I64GtU))
    0x57 -> Ok(#(reader, spec.I64LeS))
    0x58 -> Ok(#(reader, spec.I64LeU))
    0x59 -> Ok(#(reader, spec.I64GeS))
    0x5a -> Ok(#(reader, spec.I64GeU))
    0x5b -> Ok(#(reader, spec.F32Eq))
    0x5c -> Ok(#(reader, spec.F32Ne))
    0x5d -> Ok(#(reader, spec.F32Lt))
    0x5e -> Ok(#(reader, spec.F32Gt))
    0x5f -> Ok(#(reader, spec.F32Le))
    0x60 -> Ok(#(reader, spec.F32Ge))
    0x61 -> Ok(#(reader, spec.F64Eq))
    0x62 -> Ok(#(reader, spec.F64Ne))
    0x63 -> Ok(#(reader, spec.F64Lt))
    0x64 -> Ok(#(reader, spec.F64Gt))
    0x65 -> Ok(#(reader, spec.F64Le))
    0x66 -> Ok(#(reader, spec.F64Ge))
    0x67 -> Ok(#(reader, spec.I32Clz))
    0x68 -> Ok(#(reader, spec.I32Ctz))
    0x69 -> Ok(#(reader, spec.I32Popcnt))
    0x6a -> Ok(#(reader, spec.I32Add))
    0x6b -> Ok(#(reader, spec.I32Sub))
    0x6c -> Ok(#(reader, spec.I32Mul))
    0x6d -> Ok(#(reader, spec.I32DivS))
    0x6e -> Ok(#(reader, spec.I32DivU))
    0x6f -> Ok(#(reader, spec.I32RemS))
    0x70 -> Ok(#(reader, spec.I32RemU))
    0x71 -> Ok(#(reader, spec.I32And))
    0x72 -> Ok(#(reader, spec.I32Or))
    0x73 -> Ok(#(reader, spec.I32Xor))
    0x74 -> Ok(#(reader, spec.I32Shl))
    0x75 -> Ok(#(reader, spec.I32ShrS))
    0x76 -> Ok(#(reader, spec.I32ShrU))
    0x77 -> Ok(#(reader, spec.I32Rotl))
    0x78 -> Ok(#(reader, spec.I32Rotr))
    0x79 -> Ok(#(reader, spec.I64Clz))
    0x7a -> Ok(#(reader, spec.I64Ctz))
    0x7b -> Ok(#(reader, spec.I64Popcnt))
    0x7c -> Ok(#(reader, spec.I64Add))
    0x7d -> Ok(#(reader, spec.I64Sub))
    0x7e -> Ok(#(reader, spec.I64Mul))
    0x7f -> Ok(#(reader, spec.I64DivS))
    0x80 -> Ok(#(reader, spec.I64DivU))
    0x81 -> Ok(#(reader, spec.I64RemS))
    0x82 -> Ok(#(reader, spec.I64RemU))
    0x83 -> Ok(#(reader, spec.I64And))
    0x84 -> Ok(#(reader, spec.I64Or))
    0x85 -> Ok(#(reader, spec.I64Xor))
    0x86 -> Ok(#(reader, spec.I64Shl))
    0x87 -> Ok(#(reader, spec.I64ShrS))
    0x88 -> Ok(#(reader, spec.I64ShrU))
    0x89 -> Ok(#(reader, spec.I64Rotl))
    0x8a -> Ok(#(reader, spec.I64Rotr))
    0x8b -> Ok(#(reader, spec.F32Abs))
    0x8c -> Ok(#(reader, spec.F32Neg))
    0x8d -> Ok(#(reader, spec.F32Ceil))
    0x8e -> Ok(#(reader, spec.F32Floor))
    0x8f -> Ok(#(reader, spec.F32Trunc))
    0x90 -> Ok(#(reader, spec.F32Nearest))
    0x91 -> Ok(#(reader, spec.F32Sqrt))
    0x92 -> Ok(#(reader, spec.F32Add))
    0x93 -> Ok(#(reader, spec.F32Sub))
    0x94 -> Ok(#(reader, spec.F32Mul))
    0x95 -> Ok(#(reader, spec.F32Div))
    0x96 -> Ok(#(reader, spec.F32Min))
    0x97 -> Ok(#(reader, spec.F32Max))
    0x98 -> Ok(#(reader, spec.F32Copysign))
    0x99 -> Ok(#(reader, spec.F64Abs))
    0x9a -> Ok(#(reader, spec.F64Neg))
    0x9b -> Ok(#(reader, spec.F64Ceil))
    0x9c -> Ok(#(reader, spec.F64Floor))
    0x9d -> Ok(#(reader, spec.F64Trunc))
    0x9e -> Ok(#(reader, spec.F64Nearest))
    0x9f -> Ok(#(reader, spec.F64Sqrt))
    0xa0 -> Ok(#(reader, spec.F64Add))
    0xa1 -> Ok(#(reader, spec.F64Sub))
    0xa2 -> Ok(#(reader, spec.F64Mul))
    0xa3 -> Ok(#(reader, spec.F64Div))
    0xa4 -> Ok(#(reader, spec.F64Min))
    0xa5 -> Ok(#(reader, spec.F64Max))
    0xa6 -> Ok(#(reader, spec.F64Copysign))
    0xa7 -> Ok(#(reader, spec.I32WrapI64))
    0xa8 -> Ok(#(reader, spec.I32TruncF32S))
    0xa9 -> Ok(#(reader, spec.I32TruncF32U))
    0xaa -> Ok(#(reader, spec.I32TruncF64S))
    0xab -> Ok(#(reader, spec.I32TruncF64U))
    0xac -> Ok(#(reader, spec.I64ExtendI32S))
    0xad -> Ok(#(reader, spec.I64ExtendI32U))
    0xae -> Ok(#(reader, spec.I64TruncF32S))
    0xaf -> Ok(#(reader, spec.I64TruncF32U))
    0xb0 -> Ok(#(reader, spec.I64TruncF64S))
    0xb1 -> Ok(#(reader, spec.I64TruncF64U))
    0xb2 -> Ok(#(reader, spec.F32ConvertI32S))
    0xb3 -> Ok(#(reader, spec.F32ConvertI32U))
    0xb4 -> Ok(#(reader, spec.F32ConvertI64S))
    0xb5 -> Ok(#(reader, spec.F32ConvertI64U))
    0xb6 -> Ok(#(reader, spec.F32DemoteF64))
    0xb7 -> Ok(#(reader, spec.F64ConvertI32S))
    0xb8 -> Ok(#(reader, spec.F64ConvertI32U))
    0xb9 -> Ok(#(reader, spec.F64ConvertI64S))
    0xba -> Ok(#(reader, spec.F64ConvertI64U))
    0xbb -> Ok(#(reader, spec.F64PromoteF32))
    0xbc -> Ok(#(reader, spec.I32ReinterpretF32))
    0xbd -> Ok(#(reader, spec.I64ReinterpretF64))
    0xbe -> Ok(#(reader, spec.F32ReinterpretI32))
    0xbf -> Ok(#(reader, spec.F64ReinterpretI64))
    0xc0 -> Ok(#(reader, spec.I32Extend8S))
    0xc1 -> Ok(#(reader, spec.I32Extend16S))
    0xc2 -> Ok(#(reader, spec.I64Extend8S))
    0xc3 -> Ok(#(reader, spec.I64Extend16S))
    0xc4 -> Ok(#(reader, spec.I64Extend32S))
    0xfc -> {
      use #(reader, actual_opcode) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      case actual_opcode {
        0x00 -> Ok(#(reader, spec.I32TruncSatF32S))
        0x01 -> Ok(#(reader, spec.I32TruncSatF32U))
        0x02 -> Ok(#(reader, spec.I32TruncSatF64S))
        0x03 -> Ok(#(reader, spec.I32TruncSatF64U))
        0x04 -> Ok(#(reader, spec.I64TruncSatF32S))
        0x05 -> Ok(#(reader, spec.I64TruncSatF32U))
        0x06 -> Ok(#(reader, spec.I64TruncSatF64S))
        0x07 -> Ok(#(reader, spec.I64TruncSatF64U))
        unknown ->
          parsing_error.new()
          |> parsing_error.add_message(
            "gwr/parser/parse_instruction: unknown saturating truncation instruction opcode \"0x"
            <> int.to_base16(unknown)
            <> "\"",
          )
          |> parsing_error.to_error()
      }
    }
    // End
    // https://webassembly.github.io/spec/core/binary/instructions.html#expressions
    0x0b -> Ok(#(reader, spec.End))
    unknown ->
      parsing_error.new()
      |> parsing_error.add_message(
        "gwr/parser/parse_instruction: unknown opcode \"0x"
        <> int.to_base16(unknown)
        <> "\"",
      )
      |> parsing_error.to_error()
  })

  Ok(#(reader, instruction))
}

pub fn parse_expression(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.Expression),
  parsing_error.ParsingError,
) {
  use data <- result.try(byte_reader.get_remaining(from: reader))
  let data_length = bit_array.byte_size(data)

  use #(reader, expression) <- result.try(
    yielder.fold(
      from: Ok(#(reader, [])),
      over: yielder.range(1, data_length),
      with: fn(state, _) {
        use #(reader, current_expression) <- result.try(state)

        // If the last instruction was an End instruction then no further processing should be done at all
        use <- bool.guard(
          when: list.last(current_expression) == Ok(spec.End),
          return: state,
        )

        // If we reached the end of the data then the last instruction there must be an End instruction; otherwise we got an error 
        use <- bool.guard(
          when: !byte_reader.can_read(reader)
            && list.last(current_expression) != Ok(spec.End),
          return: parsing_error.new()
            |> parsing_error.add_message(
              "gwr/parser/parse_expression: an expression must terminate with a End instruction",
            )
            |> parsing_error.to_error(),
        )

        use #(reader, instruction) <- result.try(parse_instruction(from: reader))

        Ok(#(reader, list.append(current_expression, [instruction])))
      },
    ),
  )

  Ok(#(reader, expression))
}

pub fn do_parse_instructions_until(
  reader: byte_reader.ByteReader,
  predicate: fn(spec.Instruction) -> Bool,
  accumulator: List(spec.Instruction),
) -> Result(
  #(byte_reader.ByteReader, List(spec.Instruction)),
  parsing_error.ParsingError,
) {
  case byte_reader.can_read(reader) {
    True -> {
      use #(reader, instruction) <- result.try(parse_instruction(from: reader))
      case predicate(instruction) {
        True -> Ok(#(reader, list.append(accumulator, [instruction])))
        False ->
          do_parse_instructions_until(
            reader,
            predicate,
            list.append(accumulator, [instruction]),
          )
      }
    }
    False ->
      parsing_error.new()
      |> parsing_error.add_message(
        "gwr/parser/do_parse_instructions_until: reached the end of the data yet couldn't find the instruction matching the given predicate",
      )
      |> parsing_error.to_error()
  }
}

pub fn parse_instructions_until(
  from reader: byte_reader.ByteReader,
  with predicate: fn(spec.Instruction) -> Bool,
) -> Result(
  #(byte_reader.ByteReader, List(spec.Instruction)),
  parsing_error.ParsingError,
) {
  do_parse_instructions_until(reader, predicate, [])
}

pub fn parse_block_type(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.BlockType),
  parsing_error.ParsingError,
) {
  // A structured instruction can consume input and produce output on the operand stack
  // according to its annotated block type. It is given either as a type index that refers
  // to a suitable function type, or as an optional value type inline, which is a shorthand
  // for the function type [] -> [valtype?]
  use #(_, first_byte) <- result.try(byte_reader.read(from: reader, take: 1))
  case is_value_type(first_byte) {
    True -> {
      use #(reader, value_type) <- result.try(parse_value_type(from: reader))
      Ok(#(reader, spec.ValueTypeBlock(type_: option.Some(value_type))))
    }
    False -> {
      case first_byte {
        <<0x40>> ->
          Ok(#(
            byte_reader.advance(from: reader, up_to: 1),
            spec.ValueTypeBlock(type_: option.None),
          ))
        _ -> {
          use #(reader, index) <- result.try(parse_signed_leb128_integer(
            from: reader,
          ))
          Ok(#(reader, spec.TypeIndexBlock(index: index)))
        }
      }
    }
  }
}

/// ***************************************************************************
/// parser/module_parser
/// ***************************************************************************
pub const function_index_id = 0x00

pub const table_index_id = 0x01

pub const memory_index_id = 0x02

pub const global_index_id = 0x03

pub fn parse_export(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Export), parsing_error.ParsingError) {
  use #(reader, export_name) <- result.try(parse_name(from: reader))

  use #(reader, export) <- result.try(
    case byte_reader.read(from: reader, take: 1) {
      Ok(#(reader, <<id>>)) if id == function_index_id -> {
        use #(reader, index) <- result.try(parse_unsigned_leb128_integer(
          from: reader,
        ))
        Ok(#(
          reader,
          spec.Export(name: export_name, descriptor: spec.FunctionExport(index)),
        ))
      }
      Ok(#(reader, <<id>>)) if id == table_index_id -> {
        use #(reader, index) <- result.try(parse_unsigned_leb128_integer(
          from: reader,
        ))
        Ok(#(
          reader,
          spec.Export(name: export_name, descriptor: spec.TableExport(index)),
        ))
      }
      Ok(#(reader, <<id>>)) if id == memory_index_id -> {
        use #(reader, index) <- result.try(parse_unsigned_leb128_integer(
          from: reader,
        ))
        Ok(#(
          reader,
          spec.Export(name: export_name, descriptor: spec.MemoryExport(index)),
        ))
      }
      Ok(#(reader, <<id>>)) if id == global_index_id -> {
        use #(reader, index) <- result.try(parse_unsigned_leb128_integer(
          from: reader,
        ))
        Ok(#(
          reader,
          spec.Export(name: export_name, descriptor: spec.GlobalExport(index)),
        ))
      }
      Ok(#(_, <<unknown>>)) ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_export: unexpected export id \""
          <> int.to_string(unknown)
          <> "\"",
        )
        |> parsing_error.to_error()
      Error(reason) -> Error(reason)
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_export: unknown error reading export id",
        )
        |> parsing_error.to_error()
    },
  )

  Ok(#(reader, export))
}

pub fn parse_global(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Global), parsing_error.ParsingError) {
  use #(reader, global_type) <- result.try(parse_global_type(from: reader))
  use #(reader, expression) <- result.try(parse_expression(from: reader))
  Ok(#(reader, spec.Global(type_: global_type, init: expression)))
}

pub fn parse_memory(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Memory), parsing_error.ParsingError) {
  use #(reader, limits) <- result.try(parse_limits(from: reader))
  Ok(#(reader, spec.Memory(type_: limits)))
}

/// ***************************************************************************
/// parser/types_parser
/// ***************************************************************************
pub fn parse_value_type(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.ValueType),
  parsing_error.ParsingError,
) {
  use #(reader, value_type_id) <- result.try(
    case byte_reader.read(from: reader, take: 1) {
      Ok(#(reader, <<value_type_id>>)) -> Ok(#(reader, value_type_id))
      Error(reason) -> Error(reason)
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_value_type: unknown error reading value type id",
        )
        |> parsing_error.to_error()
    },
  )

  use value_type <- result.try(case value_type_id {
    0x7f -> Ok(spec.Number(spec.Integer32))
    0x7e -> Ok(spec.Number(spec.Integer64))
    0x7d -> Ok(spec.Number(spec.Float32))
    0x7c -> Ok(spec.Number(spec.Float64))
    0x7b -> Ok(spec.Vector(spec.Vector128))
    0x70 -> Ok(spec.Reference(spec.FunctionReference))
    0x6f -> Ok(spec.Reference(spec.ExternReference))
    unknown ->
      parsing_error.new()
      |> parsing_error.add_message(
        "gwr/parser/parse_value_type: unknown value type \""
        <> int.to_string(unknown)
        <> "\"",
      )
      |> parsing_error.to_error()
  })

  Ok(#(reader, value_type))
}

pub fn is_value_type(data: BitArray) -> Bool {
  case data {
    <<0x7f>> | <<0x7e>> | <<0x7d>> | <<0x7c>> | <<0x7b>> | <<0x70>> | <<0x6f>> ->
      True
    _ -> False
  }
}

pub fn parse_limits(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Limits), parsing_error.ParsingError) {
  // From the spec: "limits are encoded with a preceding flag indicating whether a maximum is present."
  use #(reader, has_max) <- result.try(
    case byte_reader.read(from: reader, take: 1) {
      Ok(#(reader, <<0x00>>)) -> Ok(#(reader, False))
      Ok(#(reader, <<0x01>>)) -> Ok(#(reader, True))
      Ok(#(_, <<unknown>>)) ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_limits: unexpected flag value \""
          <> int.to_string(unknown)
          <> "\"",
        )
        |> parsing_error.to_error()
      Error(reason) -> Error(reason)
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_limits: unknown error reading flag value",
        )
        |> parsing_error.to_error()
    },
  )

  use #(reader, min) <- result.try(parse_unsigned_leb128_integer(from: reader))
  use #(reader, max) <- result.try(case has_max {
    True -> {
      use #(reader, max) <- result.try(parse_unsigned_leb128_integer(
        from: reader,
      ))
      Ok(#(reader, option.Some(max)))
    }
    False -> Ok(#(reader, option.None))
  })

  Ok(#(reader, spec.Limits(min: min, max: max)))
}

/// Decodes a bit array into a FunctionType. The FunctionType bit array begins with 0x60 byte id
/// and follows with 2 vectors, each containing an arbitrary amount of 1-byte ValueType(s).
/// The first vector represents the list of parameter types of the function, while the second vector represents
/// the list of result types returned by the function.
pub fn parse_function_type(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.FunctionType),
  parsing_error.ParsingError,
) {
  use #(reader, function_type) <- result.try(
    case byte_reader.read(from: reader, take: 1) {
      Ok(#(reader, <<0x60>>)) -> {
        use #(reader, parameters_vec) <- result.try(parse_vector(
          from: reader,
          with: parse_value_type,
        ))
        use #(reader, results_vec) <- result.try(parse_vector(
          from: reader,
          with: parse_value_type,
        ))
        Ok(#(
          reader,
          spec.FunctionType(parameters: parameters_vec, results: results_vec),
        ))
      }
      Ok(#(_, <<unkown>>)) ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_function_type: unexpected function type id \""
          <> int.to_string(unkown)
          <> "\"",
        )
        |> parsing_error.to_error()
      Error(reason) -> Error(reason)
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_function_type: unknown error reading function type id",
        )
        |> parsing_error.to_error()
    },
  )

  Ok(#(reader, function_type))
}

pub fn parse_global_type(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, spec.GlobalType),
  parsing_error.ParsingError,
) {
  use #(reader, value_type) <- result.try(parse_value_type(from: reader))
  use #(reader, mutability) <- result.try(
    case byte_reader.read(from: reader, take: 1) {
      Ok(#(reader, <<0x00>>)) -> Ok(#(reader, spec.Constant))
      Ok(#(reader, <<0x01>>)) -> Ok(#(reader, spec.Variable))
      Ok(#(_, <<unkown>>)) ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_global_type: unexpected mutability flag value \""
          <> int.to_string(unkown)
          <> "\"",
        )
        |> parsing_error.to_error()
      Error(reason) -> Error(reason)
      _ ->
        parsing_error.new()
        |> parsing_error.add_message(
          "gwr/parser/parse_global_type: unknown error reading mutability flag value",
        )
        |> parsing_error.to_error()
    },
  )
  Ok(#(reader, spec.GlobalType(value_type: value_type, mutability: mutability)))
}

/// ***************************************************************************
/// parser/value_parser
/// ***************************************************************************
pub fn parse_unsigned_leb128_integer(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, Int), parsing_error.ParsingError) {
  use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
  use #(result, bytes_read) <- result.try(
    gleb128.decode_unsigned(remaining_data)
    |> result.replace_error(
      parsing_error.new()
      |> parsing_error.add_message("Couldn't decode LEB128 data"),
    ),
  )
  let reader = byte_reader.advance(reader, bytes_read)
  Ok(#(reader, result))
}

pub fn parse_signed_leb128_integer(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, Int), parsing_error.ParsingError) {
  use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
  use #(result, bytes_read) <- result.try(
    gleb128.decode_signed(remaining_data)
    |> result.replace_error(
      parsing_error.new()
      |> parsing_error.add_message("Couldn't decode LEB128 data"),
    ),
  )
  let reader = byte_reader.advance(reader, bytes_read)
  Ok(#(reader, result))
}

pub fn parse_uninterpreted_leb128_integer(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, Int), parsing_error.ParsingError) {
  parse_signed_leb128_integer(from: reader)
}

pub fn parse_le32_float(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, ieee_float.IEEEFloat),
  parsing_error.ParsingError,
) {
  use #(reader, data) <- result.try(byte_reader.read(from: reader, take: 4))
  Ok(#(reader, ieee_float.from_bytes_32_le(data)))
}

pub fn parse_le64_float(
  from reader: byte_reader.ByteReader,
) -> Result(
  #(byte_reader.ByteReader, ieee_float.IEEEFloat),
  parsing_error.ParsingError,
) {
  use #(reader, data) <- result.try(byte_reader.read(from: reader, take: 8))
  Ok(#(reader, ieee_float.from_bytes_64_le(data)))
}

pub fn parse_name(
  from reader: byte_reader.ByteReader,
) -> Result(#(byte_reader.ByteReader, spec.Name), parsing_error.ParsingError) {
  use #(reader, name_length) <- result.try(parse_unsigned_leb128_integer(
    from: reader,
  ))

  use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
  let remaining_data_length = bit_array.byte_size(remaining_data)

  use <- bool.guard(
    when: name_length > remaining_data_length,
    return: parsing_error.new()
      |> parsing_error.add_message(
        "Unexpected end of the name's data. Expected = "
        <> int.to_string(name_length)
        <> " bytes but got = "
        <> int.to_string(remaining_data_length)
        <> " bytes",
      )
      |> parsing_error.to_error(),
  )

  use #(reader, name_data) <- result.try(byte_reader.read(
    from: reader,
    take: name_length,
  ))
  use result <- result.try(
    bit_array.to_string(name_data)
    |> result.replace_error(
      parsing_error.new()
      |> parsing_error.add_message("Invalid UTF-8 name data"),
    ),
  )
  Ok(#(reader, result))
}
