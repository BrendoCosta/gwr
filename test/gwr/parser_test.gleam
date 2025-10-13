import gleam/bit_array
import gleam/list
import gleam/option
import gleam/pair

import gwr/parser
import gwr/parser/byte_reader
import gwr/parser/parsing_error
import gwr/spec

import gleeunit
import gleeunit/should
import ieee_float

pub fn main() {
  gleeunit.main()
}

/// ***************************************************************************
/// parser/binary_parser_test
/// ***************************************************************************
pub fn parse_binary_module___empty_module___test() {
  let reader =
    byte_reader.create(from: <<0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00>>)
  parser.parse_binary_module(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Binary(
    version: 1,
    length: 8,
    module: spec.Module(
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
    ),
  ))
}

pub fn parse_binary_module___basic_add___test() {
  let reader =
    byte_reader.create(from: <<
      0x00,
      0x61,
      0x73,
      0x6d,
      // Magic number
      0x01,
      0x00,
      0x00,
      0x00,
      // Version = 1
      0x01,
      0x07,
      // Type Section with length = 7 bytes
      0x01,
      //     Vector(FunctionType) with 1 items
      0x60,
      0x02,
      0x7f,
      0x7f,
      0x01,
      0x7f,
      //         [0] = FunctionType(parameters: [I32, I32], results: [I32])
      0x03,
      0x02,
      // Function Section with length = 2 bytes
      0x01,
      //     Vector(TypeIndex) with 1 items
      0x00,
      //         [0] = 0
      0x07,
      0x0a,
      // Export Section with length = 10 bytes
      0x01,
      //     Vector(Export) with 1 items
      0x06,
      0x61,
      0x64,
      0x64,
      0x54,
      0x77,
      0x6f,
      0x00,
      0x00,
      //         [0] = Export(name: "addTwo", descriptor: FunctionExport(index: 0))
      0x0a,
      0x09,
      // Code Section with length = 9 bytes
      0x01,
      //     Vector(Code) with 1 items
      0x07,
      //         [0] = Code with size = 7 bytes
      0x00,
      //                   Vector(LocalsDeclaration) with 0 items
      0x20,
      0x00,
      //                   LocalGet(index: 0)
      0x20,
      0x01,
      //                   LocalGet(index: 1)
      0x6a,
      //                   I32Add
      0x0b,
      //                   End
    >>)
  parser.parse_binary_module(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Binary(
    version: 1,
    length: 44,
    module: spec.Module(
      types: [
        spec.FunctionType(
          [spec.Number(spec.Integer32), spec.Number(spec.Integer32)],
          [spec.Number(spec.Integer32)],
        ),
      ],
      functions: [
        spec.Function(0, [], [
          spec.LocalGet(0),
          spec.LocalGet(1),
          spec.I32Add,
          spec.End,
        ]),
      ],
      tables: [],
      memories: [],
      globals: [],
      elements: [],
      datas: [],
      start: option.None,
      imports: [],
      exports: [spec.Export("addTwo", spec.FunctionExport(0))],
    ),
  ))
}

pub fn parse_binary_module___empty_data___test() {
  parser.parse_binary_module(byte_reader.create(from: <<>>))
  |> should.be_error
  |> parsing_error.get_message
  |> should.be_some
  |> should.equal("empty data")
}

pub fn parse_binary_module___could_not_find_module_magic_number_1___test() {
  parser.parse_binary_module(
    byte_reader.create(from: <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>),
  )
  |> should.be_error
  |> parsing_error.get_message
  |> should.be_some
  |> should.equal("couldn't find module's magic number")
}

pub fn parse_binary_module___could_not_find_module_magic_number_2___test() {
  parser.parse_binary_module(
    byte_reader.create(from: <<0x00, 0x63, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00>>),
  )
  |> should.be_error
  |> parsing_error.get_message
  |> should.be_some
  |> should.equal("couldn't find module's magic number")
}

pub fn parse_binary_module___could_not_find_module_version_1___test() {
  parser.parse_binary_module(
    byte_reader.create(from: <<0x00, 0x61, 0x73, 0x6d>>),
  )
  |> should.be_error
  |> parsing_error.get_message
  |> should.be_some
  |> should.equal("couldn't find module version")
}

pub fn parse_binary_module___could_not_find_module_version_2___test() {
  parser.parse_binary_module(
    byte_reader.create(from: <<0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00>>),
  )
  |> should.be_error
  |> parsing_error.get_message
  |> should.be_some
  |> should.equal("couldn't find module version")
}

pub fn parse_section___no_content___test() {
  let reader =
    byte_reader.create(from: <<
      0x01,
      // Type section
      0x00,
      // U32 LEB128 section length = 0
    >>)
  parser.parse_section(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Section(
    id: spec.type_section_id,
    length: 0,
    content: option.None,
  ))
}

pub fn parse_section___unexpected_end___test() {
  let reader =
    byte_reader.create(from: <<
      0x00,
      // Section type = "Custom" (0x00)
      0x09,
      // U32 LEB128 section length = 9
      0x04,
      0x74,
      0x65,
      0x73,
      0x74,
      // A name with length = 4 and content = "test"
      0x0a,
      0x0b,
      0x0c,
      // 3 bytes (1 missing)
    >>)
  parser.parse_section(reader)
  |> should.be_error
  |> parsing_error.get_message
  |> should.be_some
  |> should.equal(
    "unexpected end of the section's content segment. Expected 9 bytes but got 8 bytes",
  )
}

pub fn parse_memory_section_test() {
  let reader =
    byte_reader.create(from: <<
      0x05,
      // Section type = "Memory" (0x05)
      0x07,
      // U32 LEB128 section length = 7
      0x02,
      // A vector with U32 LEB128 length = 2 and content =
      0x00,
      0x03,
      //     [0] = Memory(type_: Limits(min: 3, max: None))
      0x01,
      0x20,
      0x80,
      0x02,
      //     [1] = Memory(type_: Limits(min: 32, max: Some(256))
    >>)
  parser.parse_section(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Section(
    id: spec.memory_section_id,
    length: 7,
    content: option.Some(
      spec.MemorySection(memories: [
        spec.Memory(type_: spec.Limits(min: 3, max: option.None)),
        spec.Memory(type_: spec.Limits(min: 32, max: option.Some(256))),
      ]),
    ),
  ))
}

pub fn parse_type_section_test() {
  let reader =
    byte_reader.create(from: <<
      0x01,
      // Section type = "Type" (0x01)
      0x17,
      // U32 LEB128 section length = 22
      0x04,
      // A vector with U32 LEB128 length = 4
      0x60,
      0x02,
      0x7f,
      0x7e,
      0x00,
      // FunctionType(parameters: [I32, I64], results: [])
      0x60,
      0x02,
      0x7d,
      0x7c,
      0x01,
      0x7b,
      // FunctionType(parameters: [F32, F64], results: [V128])
      0x60,
      0x03,
      0x70,
      0x6f,
      0x7f,
      0x02,
      0x6f,
      0x7e,
      // FunctionType(parameters: [FuncRef, ExternRef, I32], results: [ExternRef, I64])
      0x60,
      0x00,
      0x00,
      // FunctionType(parameters: [], results: [])
    >>)
  parser.parse_section(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Section(
    id: spec.type_section_id,
    length: 23,
    content: option.Some(
      spec.TypeSection(function_types: [
        spec.FunctionType(
          parameters: [spec.Number(spec.Integer32), spec.Number(spec.Integer64)],
          results: [],
        ),
        spec.FunctionType(
          parameters: [spec.Number(spec.Float32), spec.Number(spec.Float64)],
          results: [spec.Vector(spec.Vector128)],
        ),
        spec.FunctionType(
          parameters: [
            spec.Reference(spec.FunctionReference),
            spec.Reference(spec.ExternReference),
            spec.Number(spec.Integer32),
          ],
          results: [
            spec.Reference(spec.ExternReference),
            spec.Number(spec.Integer64),
          ],
        ),
        spec.FunctionType(parameters: [], results: []),
      ]),
    ),
  ))
}

pub fn parse_export_section_test() {
  let reader =
    byte_reader.create(from: <<
      0x07,
      // Section type = "Export" (0x07)
      0x32,
      // U32 LEB128 section length = 50
      0x04,
      // A vector with U32 LEB128 length = 4
      0x0b, "my_function":utf8,
      // A name with U32 LEB128 length = 11 and value = "my_function"
      0x00, 0x00,
      // FunctionExport(index: 0)
      0x08, "my_table":utf8,
      // A name with U32 LEB128 length = 8 and value = "my_table"
      0x01, 0x01,
      // TableExport(index: 1)
      0x09, "my_memory":utf8,
      // A name with U32 LEB128 length = 9 and value = "my_memory"
      0x02, 0x02,
      // MemoryExport(index: 2)
      0x09, "my_global":utf8,
      // A name with U32 LEB128 length = 9 and value = "my_global"
      0x03, 0x03,
      // GlobalExport(index: 3)
    >>)
  parser.parse_section(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Section(
    id: spec.export_section_id,
    length: 50,
    content: option.Some(
      spec.ExportSection(exports: [
        spec.Export(
          name: "my_function",
          descriptor: spec.FunctionExport(index: 0),
        ),
        spec.Export(name: "my_table", descriptor: spec.TableExport(index: 1)),
        spec.Export(name: "my_memory", descriptor: spec.MemoryExport(index: 2)),
        spec.Export(name: "my_global", descriptor: spec.GlobalExport(index: 3)),
      ]),
    ),
  ))
}

pub fn parse_function_section_test() {
  let reader =
    byte_reader.create(from: <<
      0x03,
      // Section type = "Function" (0x03)
      0x0d,
      // U32 LEB128 section length = 13
      0x06,
      // A vector with U32 LEB128 length = 6
      0x01,
      // vector[0] = 1
      0x01,
      // vector[1] = 1
      0x02,
      // vector[2] = 2
      0x03,
      // vector[3] = 3
      0xff,
      0xff,
      0xff,
      0xff,
      0x07,
      // vector[4] = 2147483647
      0xe5,
      0x8e,
      0x26,
      // vector[5] = 624485
    >>)
  parser.parse_section(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Section(
    id: spec.function_section_id,
    length: 13,
    content: option.Some(
      spec.FunctionSection(type_indices: [1, 1, 2, 3, 2_147_483_647, 624_485]),
    ),
  ))
}

pub fn parse_code_section_test() {
  let reader =
    byte_reader.create(from: <<
      0x0a,
      // Section type = "Code" (0x0a)
      0x0c,
      // Length = 12
      0x01,
      // Vector(Code) with length = 1
      0x0a,
      //     [0] = Code with size = 10
      0x01,
      //               Vector(LocalsDeclaration) with length = 1
      0x02,
      0x7f,
      //                   [0] = LocalsDeclaration(count: 2, type_: Number(Integer32))
      0x20,
      0x01,
      //               LocalGet(index: 1)
      0x20,
      0x02,
      //               LocalGet(index: 2)
      0x6a,
      //               I32Add
      0x01,
      //               NoOp
      0x0b,
      //               End
    >>)
  parser.parse_section(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Section(
    id: spec.code_section_id,
    length: 12,
    content: option.Some(
      spec.CodeSection(entries: [
        spec.Code(
          size: 10,
          function_code: spec.FunctionCode(
            locals: [
              spec.LocalsDeclaration(
                count: 2,
                type_: spec.Number(spec.Integer32),
              ),
            ],
            body: [
              spec.LocalGet(index: 1),
              spec.LocalGet(index: 2),
              spec.I32Add,
              spec.NoOp,
              spec.End,
            ],
          ),
        ),
      ]),
    ),
  ))
}

pub fn parse_code_test() {
  let reader =
    byte_reader.create(from: <<
      0x0a,
      // Code with size = 10
      0x01,
      //     Vector(LocalsDeclaration) with length = 1
      0x02,
      0x7f,
      //         [0] = LocalsDeclaration(count: 2, type_: Number(Integer32))
      0x20,
      0x01,
      //     LocalGet(index: 1)
      0x20,
      0x02,
      //     LocalGet(index: 2)
      0x6a,
      //     I32Add
      0x01,
      //     NoOp
      0x0b,
      //     End
    >>)
  parser.parse_code(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Code(
    size: 10,
    function_code: spec.FunctionCode(
      locals: [
        spec.LocalsDeclaration(count: 2, type_: spec.Number(spec.Integer32)),
      ],
      body: [
        spec.LocalGet(index: 1),
        spec.LocalGet(index: 2),
        spec.I32Add,
        spec.NoOp,
        spec.End,
      ],
    ),
  ))
}

pub fn parse_locals_declaration___3_integer32___test() {
  let reader = byte_reader.create(from: <<0x03, 0x7f>>)
  parser.parse_locals_declaration(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalsDeclaration(
    count: 3,
    type_: spec.Number(spec.Integer32),
  ))
}

pub fn parse_locals_declaration___2_integer64___test() {
  let reader = byte_reader.create(from: <<0x02, 0x7e>>)
  parser.parse_locals_declaration(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalsDeclaration(
    count: 2,
    type_: spec.Number(spec.Integer64),
  ))
}

pub fn parse_locals_declaration___128_float32___test() {
  let reader = byte_reader.create(from: <<0x80, 0x01, 0x7d>>)
  parser.parse_locals_declaration(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalsDeclaration(
    count: 128,
    type_: spec.Number(spec.Float32),
  ))
}

pub fn parse_locals_declaration___123456_float64___test() {
  let reader = byte_reader.create(from: <<0xc0, 0xc4, 0x07, 0x7c>>)
  parser.parse_locals_declaration(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalsDeclaration(
    count: 123_456,
    type_: spec.Number(spec.Float64),
  ))
}

pub fn parse_locals_declaration___255_vector128___test() {
  let reader = byte_reader.create(from: <<0xff, 0x01, 0x7b>>)
  parser.parse_locals_declaration(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalsDeclaration(
    count: 255,
    type_: spec.Vector(spec.Vector128),
  ))
}

pub fn parse_locals_declaration___2_function_reference___test() {
  let reader = byte_reader.create(from: <<0x02, 0x70>>)
  parser.parse_locals_declaration(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalsDeclaration(
    count: 2,
    type_: spec.Reference(spec.FunctionReference),
  ))
}

pub fn parse_locals_declaration___1_extern_reference___test() {
  let reader = byte_reader.create(from: <<0x01, 0x6f>>)
  parser.parse_locals_declaration(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalsDeclaration(
    count: 1,
    type_: spec.Reference(spec.ExternReference),
  ))
}

pub fn parse_function_code_test() {
  let reader =
    byte_reader.create(from: <<
      0x07,
      // A vector with 7 LocalsDeclaration
      0x03, 0x7f,
      // LocalsDeclaration(count: 3, type_: spec.Number(spec.Integer32))
      0x02, 0x7e,
      // LocalsDeclaration(count: 2, type_: spec.Number(spec.Integer64))
      0x80, 0x01, 0x7d,
      // LocalsDeclaration(count: 128, type_: spec.Number(spec.Float32))
      0xc0, 0xc4, 0x07, 0x7c,
      // LocalsDeclaration(count: 123456, type_: spec.Number(spec.Float64))
      0xff, 0x01, 0x7b,
      // LocalsDeclaration(count: 255, type_: spec.Vector(spec.Vector128))
      0x02, 0x70,
      // LocalsDeclaration(count: 2, type_: spec.Reference(spec.FunctionReference))
      0x01, 0x6f,
      // LocalsDeclaration(count: 1, type_: spec.Reference(spec.ExternReference))
      0x01,
      // NoOp <-- the function's body should begin here
      0x01,
      // NoOp
      0x0b,
      // End  <-- the function's body should terminate here
      0x01,
      // NoOp
      0x01,
      // NoOp
    >>)
  parser.parse_function_code(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(
    spec.FunctionCode(
      locals: [
        spec.LocalsDeclaration(count: 3, type_: spec.Number(spec.Integer32)),
        spec.LocalsDeclaration(count: 2, type_: spec.Number(spec.Integer64)),
        spec.LocalsDeclaration(count: 128, type_: spec.Number(spec.Float32)),
        spec.LocalsDeclaration(count: 123_456, type_: spec.Number(spec.Float64)),
        spec.LocalsDeclaration(count: 255, type_: spec.Vector(spec.Vector128)),
        spec.LocalsDeclaration(
          count: 2,
          type_: spec.Reference(spec.FunctionReference),
        ),
        spec.LocalsDeclaration(
          count: 1,
          type_: spec.Reference(spec.ExternReference),
        ),
      ],
      body: [spec.NoOp, spec.NoOp, spec.End],
    ),
  )
}

/// ***************************************************************************
/// parser/convention_parser_test
/// ***************************************************************************
pub fn parse_vector___bytes___test() {
  let reader = byte_reader.create(from: <<0x01, "Hello World!":utf8>>)
  parser.parse_vector(from: reader, with: fn(reader) {
    let assert Ok(#(reader, string_data)) =
      byte_reader.read_remaining(from: reader)
    Ok(#(reader, bit_array.to_string(string_data)))
  })
  |> should.be_ok
  |> pair.second
  |> should.equal([Ok("Hello World!")])
}

/// ***************************************************************************
/// parser/instruction_parser_test
/// ***************************************************************************
pub fn parse_block_type___empty_block___test() {
  let reader = byte_reader.create(from: <<0x40>>)
  parser.parse_block_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.ValueTypeBlock(type_: option.None))
}

pub fn parse_block_type___value_type_block___test() {
  let reader = byte_reader.create(from: <<0x7f>>)
  parser.parse_block_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(
    spec.ValueTypeBlock(type_: option.Some(spec.Number(spec.Integer32))),
  )
}

pub fn parse_block_type___type_index_block___test() {
  let reader = byte_reader.create(from: <<0x80, 0x80, 0x04>>)
  parser.parse_block_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.TypeIndexBlock(index: 65_536))
}

pub fn parse_instruction___block___test() {
  let reader =
    byte_reader.create(from: <<
      0x02,
      0x01,
      0x41,
      0x80,
      0x80,
      0xc0,
      0x00,
      0x41,
      0x2,
      0x0b,
    >>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(
    spec.Block(block_type: spec.TypeIndexBlock(index: 1), instructions: [
      spec.I32Const(value: 1_048_576),
      spec.I32Const(value: 2),
      spec.End,
    ]),
  )
}

pub fn parse_instruction___loop___test() {
  let reader =
    byte_reader.create(from: <<
      0x03,
      0x7f,
      0x41,
      0x08,
      0x41,
      0x80,
      0x80,
      0x04,
      0x0b,
    >>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(
    spec.Loop(
      block_type: spec.ValueTypeBlock(
        type_: option.Some(spec.Number(spec.Integer32)),
      ),
      instructions: [
        spec.I32Const(value: 8),
        spec.I32Const(value: 65_536),
        spec.End,
      ],
    ),
  )
}

pub fn parse_instruction___if___test() {
  let reader =
    byte_reader.create(from: <<0x04, 0x7f, 0x41, 0x80, 0x80, 0x04, 0x0b>>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.If(
    block_type: spec.ValueTypeBlock(
      type_: option.Some(spec.Number(spec.Integer32)),
    ),
    instructions: [spec.I32Const(value: 65_536), spec.End],
    else_: option.None,
  ))
}

pub fn parse_instruction___if_else___test() {
  let reader =
    byte_reader.create(from: <<
      0x04,
      0x7f,
      0x41,
      0x80,
      0x80,
      0x04,
      0x05,
      0x41,
      0x02,
      0x0b,
    >>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.If(
    block_type: spec.ValueTypeBlock(
      type_: option.Some(spec.Number(spec.Integer32)),
    ),
    instructions: [
      spec.I32Const(value: 65_536),
    ],
    else_: option.Some(
      spec.Else(instructions: [spec.I32Const(value: 2), spec.End]),
    ),
  ))
}

pub fn parse_instruction___i32_const___test() {
  let reader = byte_reader.create(from: <<0x41, 0x80, 0x80, 0xc0, 0x00>>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.I32Const(value: 1_048_576))
}

pub fn parse_instruction___local_get___test() {
  let reader = byte_reader.create(from: <<0x20, 0xff, 0x01>>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalGet(index: 255))
}

pub fn parse_instruction___local_tee___test() {
  let reader = byte_reader.create(from: <<0x20, 0x80, 0x80, 0x04>>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.LocalGet(index: 65_536))
}

pub fn parse_instruction___br___test() {
  let reader = byte_reader.create(from: <<0x0c, 0xff, 0x01>>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Br(index: 255))
}

pub fn parse_instruction___br_if___test() {
  let reader = byte_reader.create(from: <<0x0d, 0x80, 0x80, 0x04>>)
  parser.parse_instruction(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.BrIf(index: 65_536))
}

/// ***************************************************************************
/// parser/module_parser_test
/// ***************************************************************************
pub fn parse_export___function_export___test() {
  let reader =
    byte_reader.create(from: <<0x0b, "my_function":utf8, 0x00, 0x00>>)
  parser.parse_export(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Export(
    name: "my_function",
    descriptor: spec.FunctionExport(index: 0),
  ))
}

pub fn parse_export___table_export___test() {
  let reader =
    byte_reader.create(from: <<0x08, "my_table":utf8, 0x01, 0xc0, 0xc4, 0x07>>)
  parser.parse_export(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Export(
    name: "my_table",
    descriptor: spec.TableExport(index: 123_456),
  ))
}

pub fn parse_export___memory_export___test() {
  let reader =
    byte_reader.create(from: <<0x09, "my_memory":utf8, 0x02, 0xff, 0x01>>)
  parser.parse_export(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Export(
    name: "my_memory",
    descriptor: spec.MemoryExport(index: 255),
  ))
}

pub fn parse_export___global_export___test() {
  let reader =
    byte_reader.create(from: <<
      0x09,
      "my_global":utf8,
      0x03,
      0xff,
      0xff,
      0xff,
      0xff,
      0x0f,
    >>)
  parser.parse_export(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Export(
    name: "my_global",
    descriptor: spec.GlobalExport(index: 4_294_967_295),
  ))
}

pub fn parse_memory___with_max___test() {
  let reader = byte_reader.create(from: <<0x00, 0xff, 0xff, 0x03>>)
  parser.parse_memory(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(
    spec.Memory(type_: spec.Limits(min: 65_535, max: option.None)),
  )
}

pub fn parse_memory___without_max___test() {
  let reader = byte_reader.create(from: <<0x01, 0x80, 0x08, 0x80, 0x40>>)
  parser.parse_memory(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(
    spec.Memory(type_: spec.Limits(min: 1024, max: option.Some(8192))),
  )
}

/// ***************************************************************************
/// parser/types_parser_test
/// ***************************************************************************
pub fn parse_function_type_test() {
  let reader =
    byte_reader.create(from: <<
      0x60,
      // Flag
      0x02,
      0x7f,
      0x7e,
      // Parameters -> A vector with U32 LEB128 length = 2 and content = [I32, I64]
      0x05,
      0x7d,
      0x7c,
      0x7b,
      0x70,
      0x6f,
      // Results -> A vector with U32 LEB128 length = 5 and content = [F32, F64, V128, FuncRef, ExternRef]
    >>)
  parser.parse_function_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(
    spec.FunctionType(
      parameters: [spec.Number(spec.Integer32), spec.Number(spec.Integer64)],
      results: [
        spec.Number(spec.Float32),
        spec.Number(spec.Float64),
        spec.Vector(spec.Vector128),
        spec.Reference(spec.FunctionReference),
        spec.Reference(spec.ExternReference),
      ],
    ),
  )
}

pub fn parse_function_type___empty_vectors___test() {
  let reader = byte_reader.create(from: <<0x60, 0x00, 0x00>>)
  parser.parse_function_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.FunctionType(parameters: [], results: []))
}

pub fn parse_global_type___constant___test() {
  let reader = byte_reader.create(from: <<0x7f, 0x00>>)
  parser.parse_global_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.GlobalType(
    value_type: spec.Number(spec.Integer32),
    mutability: spec.Constant,
  ))
}

pub fn parse_global_type___variable___test() {
  let reader = byte_reader.create(from: <<0x7e, 0x01>>)
  parser.parse_global_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.GlobalType(
    value_type: spec.Number(spec.Integer64),
    mutability: spec.Variable,
  ))
}

pub fn parse_limits___no_max___test() {
  let reader = byte_reader.create(from: <<0x00, 0x03>>)
  parser.parse_limits(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Limits(min: 3, max: option.None))
}

pub fn parse_limits___with_max___test() {
  let reader = byte_reader.create(from: <<0x01, 0x20, 0x80, 0x02>>)
  parser.parse_limits(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Limits(min: 32, max: option.Some(256)))
}

pub fn parse_value_type___integer_32___test() {
  let reader = byte_reader.create(from: <<0x7f>>)
  parser.parse_value_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Number(spec.Integer32))
}

pub fn parse_value_type___integer_64___test() {
  let reader = byte_reader.create(from: <<0x7e>>)
  parser.parse_value_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Number(spec.Integer64))
}

pub fn parse_value_type___float_32___test() {
  let reader = byte_reader.create(from: <<0x7d>>)
  parser.parse_value_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Number(spec.Float32))
}

pub fn parse_value_type___float_64___test() {
  let reader = byte_reader.create(from: <<0x7c>>)
  parser.parse_value_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Number(spec.Float64))
}

pub fn parse_value_type___vector_128___test() {
  let reader = byte_reader.create(from: <<0x7b>>)
  parser.parse_value_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Vector(spec.Vector128))
}

pub fn parse_value_type___function_reference___test() {
  let reader = byte_reader.create(from: <<0x70>>)
  parser.parse_value_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Reference(spec.FunctionReference))
}

pub fn parse_value_type___extern_reference___test() {
  let reader = byte_reader.create(from: <<0x6f>>)
  parser.parse_value_type(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal(spec.Reference(spec.ExternReference))
}

/// ***************************************************************************
/// parser/value_parser_test
/// ***************************************************************************
pub fn parse_le32_float_test() {
  [
    #(<<0x00, 0x00, 0x00, 0x00>>, ieee_float.finite(0.0)),
    #(<<0x00, 0x00, 0x80, 0x3f>>, ieee_float.finite(1.0)),
    #(<<0x00, 0x00, 0x80, 0xbf>>, ieee_float.finite(-1.0)),
    #(<<0x00, 0x00, 0x80, 0x7f>>, ieee_float.positive_infinity()),
    #(<<0x00, 0x00, 0x80, 0xff>>, ieee_float.negative_infinity()),
    #(<<0x00, 0x00, 0xc0, 0x7f>>, ieee_float.nan()),
  ]
  |> list.each(fn(test_case) {
    let reader = byte_reader.create(from: test_case.0)
    parser.parse_le32_float(reader)
    |> should.be_ok
    |> pair.second
    |> should.equal(test_case.1)
  })
}

pub fn parse_le64_float_test() {
  [
    #(
      <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>,
      ieee_float.finite(0.0),
    ),
    #(
      <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x3f>>,
      ieee_float.finite(1.0),
    ),
    #(
      <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0xbf>>,
      ieee_float.finite(-1.0),
    ),
    #(
      <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x7f>>,
      ieee_float.positive_infinity(),
    ),
    #(
      <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0xff>>,
      ieee_float.negative_infinity(),
    ),
    #(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0x7f>>, ieee_float.nan()),
  ]
  |> list.each(fn(test_case) {
    let reader = byte_reader.create(from: test_case.0)
    parser.parse_le64_float(reader)
    |> should.be_ok
    |> pair.second
    |> should.equal(test_case.1)
  })
}

pub fn parse_name_test() {
  let reader = byte_reader.create(from: <<0x09, "some_name":utf8>>)
  parser.parse_name(reader)
  |> should.be_ok
  |> pair.second
  |> should.equal("some_name")
}
