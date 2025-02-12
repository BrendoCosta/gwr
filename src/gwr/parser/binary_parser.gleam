import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{Some, None}
import gleam/result
import gleam/yielder

import gwr/binary
import gwr/parser/convention_parser
import gwr/parser/instruction_parser
import gwr/parser/module_parser
import gwr/parser/types_parser
import gwr/parser/value_parser
import gwr/parser/byte_reader
import gwr/syntax/module

pub fn parse_locals_declaration(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, binary.LocalsDeclaration), String)
{
    use #(reader, count) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
    use #(reader, value_type) <- result.try(types_parser.parse_value_type(from: reader))
    Ok(#(reader, binary.LocalsDeclaration(count: count, type_: value_type)))
}

pub fn parse_function_code(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, binary.FunctionCode), String)
{
    use #(reader, locals_declaration) <- result.try(convention_parser.parse_vector(from: reader, with: parse_locals_declaration))
    use #(reader, expression) <- result.try(instruction_parser.parse_expression(from: reader))
    Ok(#(reader, binary.FunctionCode(locals: locals_declaration, body: expression)))
}

pub fn parse_code(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, binary.Code), String)
{
    use #(reader, size) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
    use #(reader, function_code) <- result.try(parse_function_code(from: reader))
    Ok(#(reader, binary.Code(size: size, function_code: function_code)))
}

pub fn parse_section(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, binary.Section), String)
{
    use #(reader, section_type_id)  <- result.try(
        case byte_reader.read(from: reader, take: 1)
        {
            Ok(#(reader, <<section_type_id>>)) -> Ok(#(reader, section_type_id))
            _ -> Error("gwr/parser/binary_parser.parse_section: can't get section type id raw data")
        }
    )

    use #(reader, section_length) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))

    use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
    let remaining_data_length = bit_array.byte_size(remaining_data)

    use <- bool.guard(
        when: section_length > remaining_data_length,
        return: Error("gwr/parser/binary_parser.parse_section: unexpected end of the section's content segment. Expected " <> int.to_string(section_length) <> " bytes but got " <> int.to_string(remaining_data_length) <> " bytes")
    )

    use #(reader, decoded_dection) <- result.try(
        case byte_reader.can_read(reader), section_type_id // the reverse order throws a syntax error xD
        {
            True, id if id == binary.custom_section_id ->
            {
                use #(reader, custom_section_name) <- result.try(value_parser.parse_name(from: reader))
                use #(reader, custom_section_data) <- result.try(byte_reader.read_remaining(from: reader))
                Ok(#(reader, binary.Section(id: binary.custom_section_id, length: section_length, content: Some(binary.CustomSection(name: custom_section_name, data: Some(custom_section_data))))))
            }
            True, id if id == binary.type_section_id ->
            {
                use #(reader, function_types_vec) <- result.try(convention_parser.parse_vector(from: reader, with: types_parser.parse_function_type))
                Ok(#(reader, binary.Section(id: binary.type_section_id, length: section_length, content: Some(binary.TypeSection(function_types: function_types_vec)))))
            }
            // @TODO True, id if id == import_section_id -> {}
            True, id if id == binary.function_section_id ->
            {
                use #(reader, indices_vec) <- result.try(convention_parser.parse_vector(from: reader, with: fn (reader) {
                    use #(reader, index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                    Ok(#(reader, index))
                }))

                Ok(#(reader, binary.Section(id: binary.function_section_id, length: section_length, content: Some(binary.FunctionSection(type_indices: indices_vec)))))
            }
            // @TODO True, id if id == table_section_id -> {}
            True, id if id == binary.memory_section_id ->
            {
                use #(reader, mem_vec) <- result.try(convention_parser.parse_vector(from: reader, with: module_parser.parse_memory))
                Ok(#(reader, binary.Section(id: binary.memory_section_id, length: section_length, content: Some(binary.MemorySection(memories: mem_vec)))))
            }
            True, id if id == binary.global_section_id ->
            {
                use #(reader, globals_vec) <- result.try(convention_parser.parse_vector(from: reader, with: module_parser.parse_global))
                Ok(#(reader, binary.Section(id: binary.global_section_id, length: section_length, content: Some(binary.GlobalSection(globals: globals_vec)))))
            }
            True, id if id == binary.export_section_id ->
            {
                use #(reader, exports_vec) <- result.try(convention_parser.parse_vector(from: reader, with: module_parser.parse_export))
                Ok(#(reader, binary.Section(id: binary.export_section_id, length: section_length, content: Some(binary.ExportSection(exports: exports_vec)))))
            }
            // @TODO True, id if id == start_section_id -> {}
            // @TODO True, id if id == element_section_id -> {}
            True, id if id == binary.code_section_id ->
            {
                use #(reader, codes_vec) <- result.try(convention_parser.parse_vector(from: reader, with: parse_code))
                Ok(#(reader, binary.Section(id: binary.code_section_id, length: section_length, content: Some(binary.CodeSection(entries: codes_vec)))))
            }
            // @TODO True, id if id == data_section_id -> {}
            // @TODO True, id if id == data_count_section_id -> {}
            
            // Empty sections are allowed
            False, id if id == binary.custom_section_id -> Ok(#(reader, binary.Section(id: binary.custom_section_id, length: section_length, content: None)))
            False, id if id == binary.type_section_id -> Ok(#(reader, binary.Section(id: binary.type_section_id, length: section_length, content: None)))
            // @TODO False, id if id == import_section_id -> {}
            False, id if id == binary.function_section_id -> Ok(#(reader, binary.Section(id: binary.function_section_id, length: section_length, content: None)))
            // @TODO False, id if id == table_section_id -> {}
            False, id if id == binary.memory_section_id -> Ok(#(reader, binary.Section(id: binary.memory_section_id, length: section_length, content: None)))
            // @TODO False, id if id == global_section_id -> {}
            False, id if id == binary.export_section_id -> Ok(#(reader, binary.Section(id: binary.export_section_id, length: section_length, content: None)))
            // @TODO False, id if id == start_section_id -> {}
            // @TODO False, id if id == element_section_id -> {}
            False, id if id == binary.code_section_id -> Ok(#(reader, binary.Section(id: binary.code_section_id, length: section_length, content: None)))
            _, _ -> Error("gwr/parser/binary_parser.parse_section: unknown section type id \"" <> int.to_string(section_type_id) <> "\"")
        }
    )
    Ok(#(reader, decoded_dection))
}

pub fn parse_binary_module(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, binary.Binary), String)
{
    use <- bool.guard(when: byte_reader.is_empty(reader), return: Error("gwr/parser/binary_parser.parse_binary_module: empty data"))
    
    // https://webassembly.github.io/spec/core/binary/module.html#binary-module
    // 
    // The encoding of a module starts with a preamble containing a 4-byte magic number (the string '\0asm')
    // and a version field. The current version of the WebAssembly binary format is 1.

    let #(reader, found_magic_number) = case byte_reader.read(from: reader, take: 4)
    {
        Ok(#(reader, <<0x00, 0x61, 0x73, 0x6d>>)) -> #(reader, True)
        Ok(#(reader, _)) -> #(reader, False)
        Error(_) -> #(reader, False)
    }

    use <- bool.guard(when: !found_magic_number, return: Error("gwr/parser/binary_parser.parse_binary_module: couldn't find module's magic number"))

    // @TODO: I couldn't figure out the version number binary encoding from the spec (LE32 or LEB128 ?),
    // therefore the code below may be fixed.
    use #(reader, module_wasm_version) <- result.try(
        case byte_reader.read(from: reader, take: 4)
        {
            Ok(#(reader, <<version:unsigned-little-size(32)>>)) -> Ok(#(reader, version))
            _ -> Error("gwr/parser/binary_parser.parse_binary_module: couldn't find module version")
        }
    )

    let empty_module = module.Module
    (
        types: [],
        functions: [],
        tables: [],
        memories: [],
        globals: [],
        elements: [],
        datas: [],
        start: None,
        imports: [],
        exports: []
    )

    use #(reader, filled_module, _) <- result.try(
        yielder.fold(
            from: Ok(#(reader, empty_module, [])),
            over: yielder.range(from: 0x00, to: 0x0c),
            with: fn (state, _)
            {
                use #(reader, module, function_section_type_indices) <- result.try(state)
                
                use <- bool.guard(when: !byte_reader.can_read(reader), return: state)
                use #(reader, section) <- result.try(parse_section(from: reader))
                
                use #(module, function_section_type_indices) <- result.try(
                    case section.content
                    {
                        None -> Ok(#(module, function_section_type_indices))
                        Some(content) ->
                        {
                            case content
                            {
                                binary.CustomSection(name: _, data: _) -> Ok(#(module, function_section_type_indices))
                                binary.TypeSection(function_types: function_types) ->
                                {
                                    Ok(#(module.Module(..module, types: function_types), function_section_type_indices))
                                }
                                binary.ImportSection -> Ok(#(module, function_section_type_indices))
                                binary.FunctionSection(type_indices: type_indices_list) ->
                                {
                                    // Here we set function_section_type_indices
                                    Ok(#(module, type_indices_list))
                                }
                                binary.TableSection -> Ok(#(module, function_section_type_indices))
                                binary.MemorySection(memories: memories_list) ->
                                {
                                    Ok(#(module.Module(..module, memories: memories_list), function_section_type_indices))
                                }
                                binary.GlobalSection(globals: globals_list) ->
                                {
                                    Ok(#(module.Module(..module, globals: globals_list), function_section_type_indices))
                                }
                                binary.ExportSection(exports: exports_list) ->
                                {
                                    Ok(#(module.Module(..module, exports: exports_list), function_section_type_indices))
                                }
                                binary.StartSection(start_function: start_function) ->
                                {
                                    Ok(#(module.Module(..module, start: Some(start_function)), function_section_type_indices))
                                }
                                binary.ElementSection -> Ok(#(module, function_section_type_indices))
                                binary.CodeSection(entries: code_entries) ->
                                {
                                    use function_list <- result.try(
                                        list.index_fold(
                                            over: code_entries,
                                            from: Ok([]),
                                            with: fn(function_list, entry, index)
                                            {
                                                use function_list <- result.try(function_list)
                                                case function_section_type_indices |> list.take(up_to: index + 1) |> list.last
                                                {
                                                    Ok(function_type_index) ->
                                                    {
                                                        let function = module.Function(
                                                            type_: function_type_index,
                                                            locals: list.map(
                                                                entry.function_code.locals,
                                                                fn (locals_declaration)
                                                                {
                                                                    list.repeat(locals_declaration.type_, locals_declaration.count)
                                                                }
                                                            ) |> list.flatten,
                                                            body: entry.function_code.body
                                                        )
                                                        Ok(list.append(function_list, [function]))
                                                    }
                                                    Error(_) -> Error("gwr/parser/binary_parser.parse_binary_module: couldn't find type index " <> int.to_string(index))
                                                }
                                            }
                                        )
                                    )
                                    Ok(#(module.Module(..module, functions: function_list), function_section_type_indices))
                                }
                                binary.DataSection -> Ok(#(module, function_section_type_indices))
                                binary.DataCountSection -> Ok(#(module, function_section_type_indices))
                            }
                        }
                    }
                )

                Ok(#(reader, module, function_section_type_indices))
            }
        )
    )

    Ok(#(reader, binary.Binary(version: module_wasm_version, length: byte_reader.bytes_read(from: reader), module: filled_module)))
}