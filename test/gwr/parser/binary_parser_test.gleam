import gleam/option.{None, Some}

import gwr/binary
import gwr/parser/binary_parser
import gwr/parser/binary_reader
import gwr/syntax/instruction
import gwr/syntax/module
import gwr/syntax/types

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn parse_binary_module___empty_module___test()
{
    let reader = binary_reader.create(from: <<0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00>>)
    binary_parser.parse_binary_module(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 8),
            binary.Binary
            (
                version: 1,
                length: 8,
                module: module.Module
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
            )
        )
    )
}

pub fn parse_binary_module___basic_add___test()
{
    let reader = binary_reader.create(from: <<
        0x00, 0x61, 0x73, 0x6d,                                         // Magic number
        0x01, 0x00, 0x00, 0x00,                                         // Version = 1
        0x01, 0x07,                                                     // Type Section with length = 7 bytes
            0x01,                                                       //     Vector(FunctionType) with 1 items
                0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f,                     //         [0] = FunctionType(parameters: [I32, I32], results: [I32])
        0x03, 0x02,                                                     // Function Section with length = 2 bytes
            0x01,                                                       //     Vector(TypeIndex) with 1 items
                0x00,                                                   //         [0] = 0
        0x07, 0x0a,                                                     // Export Section with length = 10 bytes
            0x01,                                                       //     Vector(Export) with 1 items
                0x06, 0x61, 0x64, 0x64, 0x54, 0x77, 0x6f, 0x00, 0x00,   //         [0] = Export(name: "addTwo", descriptor: FunctionExport(index: 0))
        0x0a, 0x09,                                                     // Code Section with length = 9 bytes
            0x01,                                                       //     Vector(Code) with 1 items
                0x07,                                                   //         [0] = Code with size = 7 bytes
                    0x00,                                               //                   Vector(LocalsDeclaration) with 0 items
                    0x20, 0x00,                                         //                   LocalGet(index: 0)
                    0x20, 0x01,                                         //                   LocalGet(index: 1)
                    0x6a,                                               //                   I32Add
                    0x0b                                                //                   End
    >>)
    binary_parser.parse_binary_module(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 44),
            binary.Binary
            (
                version: 1,
                length: 44,
                module: module.Module
                (
                    types: [types.FunctionType([types.Number(types.Integer32), types.Number(types.Integer32)], [types.Number(types.Integer32)])],
                    functions: [module.Function(0, [], [instruction.LocalGet(0), instruction.LocalGet(1), instruction.I32Add, instruction.End])],
                    tables: [],
                    memories: [],
                    globals: [],
                    elements: [],
                    datas: [],
                    start: None,
                    imports: [],
                    exports: [module.Export("addTwo", module.FunctionExport(0))]
                )
            )
        )
    )
}

pub fn parse_binary_module___empty_data___test()
{
    binary_parser.parse_binary_module(binary_reader.create(from: <<>>))
    |> should.be_error
    |> should.equal("gwr/parser/binary_parser.parse_binary_module: empty data")
}

pub fn parse_binary_module___could_not_find_module_magic_number_1___test()
{
    binary_parser.parse_binary_module(binary_reader.create(from: <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>))
    |> should.be_error
    |> should.equal("gwr/parser/binary_parser.parse_binary_module: couldn't find module's magic number")
}

pub fn parse_binary_module___could_not_find_module_magic_number_2___test()
{
    binary_parser.parse_binary_module(binary_reader.create(from: <<0x00, 0x63, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00>>))
    |> should.be_error
    |> should.equal("gwr/parser/binary_parser.parse_binary_module: couldn't find module's magic number")
}

pub fn parse_binary_module___could_not_find_module_version_1___test()
{
    binary_parser.parse_binary_module(binary_reader.create(from: <<0x00, 0x61, 0x73, 0x6d>>))
    |> should.be_error
    |> should.equal("gwr/parser/binary_parser.parse_binary_module: couldn't find module version")
}

pub fn parse_binary_module___could_not_find_module_version_2___test()
{
    binary_parser.parse_binary_module(binary_reader.create(from: <<0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00>>))
    |> should.be_error
    |> should.equal("gwr/parser/binary_parser.parse_binary_module: couldn't find module version")
}

pub fn parse_section___no_content___test()
{
    let reader = binary_reader.create(from: <<
            0x01,                   // Type section
            0x00,                   // U32 LEB128 section length = 0
    >>)
    binary_parser.parse_section(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 2),
            binary.Section
            (
                id: binary.type_section_id,
                length: 0,
                content: None
            )
        )
    )
}

pub fn parse_section___unexpected_end___test()
{
    let reader = binary_reader.create(from: <<
            0x00,                           // Section type = "Custom" (0x00)
            0x09,                           // U32 LEB128 section length = 9
            0x04, 0x74, 0x65, 0x73, 0x74,   // A name with length = 4 and content = "test"
            0x0a, 0x0b, 0x0c                // 3 bytes (1 missing)
    >>)
    binary_parser.parse_section(reader)
    |> should.be_error
    |> should.equal("gwr/parser/binary_parser.parse_section: unexpected end of the section's content segment. Expected 9 bytes but got 8 bytes")
}

pub fn parse_memory_section_test()
{
    let reader = binary_reader.create(from: <<
            0x05,                       // Section type = "Memory" (0x05)
            0x07,                       // U32 LEB128 section length = 7
            0x02,                       // A vector with U32 LEB128 length = 2 and content =
                0x00, 0x03,             //     [0] = Memory(type_: Limits(min: 3, max: None))
                0x01, 0x20, 0x80, 0x02  //     [1] = Memory(type_: Limits(min: 32, max: Some(256))
    >>)
    binary_parser.parse_section(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 9),
            binary.Section
            (
                id: binary.memory_section_id,
                length: 7,
                content: Some(binary.MemorySection(
                    memories: [
                        module.Memory(type_: types.Limits(min: 3, max: None)),
                        module.Memory(type_: types.Limits(min: 32, max: Some(256)))
                    ]
                ))
            )
        )
    )
}

pub fn parse_type_section_test()
{
    let reader = binary_reader.create(from: <<
        0x01,                                               // Section type = "Type" (0x01)
        0x17,                                               // U32 LEB128 section length = 22
        0x04,                                               // A vector with U32 LEB128 length = 4
            0x60, 0x02, 0x7f, 0x7e, 0x00,                   // FunctionType(parameters: [I32, I64], results: [])
            0x60, 0x02, 0x7d, 0x7c, 0x01, 0x7b,             // FunctionType(parameters: [F32, F64], results: [V128])
            0x60, 0x03, 0x70, 0x6f, 0x7f, 0x02, 0x6f, 0x7e, // FunctionType(parameters: [FuncRef, ExternRef, I32], results: [ExternRef, I64])
            0x60, 0x00, 0x00                                // FunctionType(parameters: [], results: [])
    >>)
    binary_parser.parse_section(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 25),
            binary.Section
            (
                id: binary.type_section_id,
                length: 23,
                content: Some(binary.TypeSection(
                    function_types: [
                        types.FunctionType(parameters: [types.Number(types.Integer32), types.Number(types.Integer64)], results: []),
                        types.FunctionType(parameters: [types.Number(types.Float32), types.Number(types.Float64)], results: [types.Vector(types.Vector128)]),
                        types.FunctionType(parameters: [types.Reference(types.FunctionReference), types.Reference(types.ExternReference), types.Number(types.Integer32)], results: [types.Reference(types.ExternReference), types.Number(types.Integer64)]),
                        types.FunctionType(parameters: [], results: [])
                    ]
                ))
            )
        )
    )
}

pub fn parse_export_section_test()
{
    let reader = binary_reader.create(from: <<
        0x07,                                               // Section type = "Export" (0x07)
        0x32,                                               // U32 LEB128 section length = 50
        0x04,                                               // A vector with U32 LEB128 length = 4
            0x0b, "my_function":utf8,                       // A name with U32 LEB128 length = 11 and value = "my_function"
            0x00, 0x00,                                     // FunctionExport(index: 0)
            0x08, "my_table":utf8,                          // A name with U32 LEB128 length = 8 and value = "my_table"
            0x01, 0x01,                                     // TableExport(index: 1)
            0x09, "my_memory":utf8,                         // A name with U32 LEB128 length = 9 and value = "my_memory"
            0x02, 0x02,                                     // MemoryExport(index: 2)
            0x09, "my_global":utf8,                         // A name with U32 LEB128 length = 9 and value = "my_global"
            0x03, 0x03,                                     // GlobalExport(index: 3)
    >>)
    binary_parser.parse_section(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 52),
            binary.Section
            (
                id: binary.export_section_id,
                length: 50,
                content: Some(binary.ExportSection(
                    exports: [
                        module.Export(name: "my_function", descriptor: module.FunctionExport(index: 0)),
                        module.Export(name: "my_table", descriptor: module.TableExport(index: 1)),
                        module.Export(name: "my_memory", descriptor: module.MemoryExport(index: 2)),
                        module.Export(name: "my_global", descriptor: module.GlobalExport(index: 3)),
                    ]
                ))
            )
        )
    )
}

pub fn parse_function_section_test()
{
    let reader = binary_reader.create(from: <<
        0x03,                                               // Section type = "Function" (0x03)
        0x0d,                                               // U32 LEB128 section length = 13
        0x06,                                               // A vector with U32 LEB128 length = 6
            0x01,                                           // vector[0] = 1
            0x01,                                           // vector[1] = 1
            0x02,                                           // vector[2] = 2
            0x03,                                           // vector[3] = 3
            0xff, 0xff, 0xff, 0xff, 0x07,                   // vector[4] = 2147483647
            0xe5, 0x8e, 0x26                                // vector[5] = 624485
    >>)
    binary_parser.parse_section(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 15),
            binary.Section
            (
                id: binary.function_section_id,
                length: 13,
                content: Some(binary.FunctionSection(
                    type_indices: [1, 1, 2, 3, 2147483647, 624485]
                ))
            )
        )
    )
}

pub fn parse_code_section_test()
{
    let reader = binary_reader.create(from: <<
        0x0a,                                               // Section type = "Code" (0x0a)
        0x0c,                                               // Length = 12
        0x01,                                               // Vector(Code) with length = 1
            0x0a,                                           //     [0] = Code with size = 10
            0x01,                                           //               Vector(LocalsDeclaration) with length = 1
                0x02, 0x7f,                                 //                   [0] = LocalsDeclaration(count: 2, type_: Number(Integer32))
            0x20, 0x01,                                     //               LocalGet(index: 1)
            0x20, 0x02,                                     //               LocalGet(index: 2)
            0x6a,                                           //               I32Add
            0x01,                                           //               NoOp
            0x0b                                            //               End
    >>)
    binary_parser.parse_section(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 14),
            binary.Section
            (
                id: binary.code_section_id,
                length: 12,
                content: Some(binary.CodeSection(
                    entries: [
                        binary.Code(
                            size: 10,
                            function_code: binary.FunctionCode(
                                locals: [binary.LocalsDeclaration(count: 2, type_: types.Number(types.Integer32))],
                                body: [
                                    instruction.LocalGet(index: 1),
                                    instruction.LocalGet(index: 2),
                                    instruction.I32Add,
                                    instruction.NoOp,
                                    instruction.End
                                ]
                            )
                        )
                    ]
                ))
            )
        )
    )
}

pub fn parse_code_test()
{
    let reader = binary_reader.create(from: <<
        0x0a,                                               // Code with size = 10
            0x01,                                           //     Vector(LocalsDeclaration) with length = 1
                0x02, 0x7f,                                 //         [0] = LocalsDeclaration(count: 2, type_: Number(Integer32))
            0x20, 0x01,                                     //     LocalGet(index: 1)
            0x20, 0x02,                                     //     LocalGet(index: 2)
            0x6a,                                           //     I32Add
            0x01,                                           //     NoOp
            0x0b                                            //     End
    >>)
    binary_parser.parse_code(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 11),
            binary.Code(
                size: 10,
                function_code: binary.FunctionCode(
                    locals: [binary.LocalsDeclaration(count: 2, type_: types.Number(types.Integer32))],
                    body: [
                        instruction.LocalGet(index: 1),
                        instruction.LocalGet(index: 2),
                        instruction.I32Add,
                        instruction.NoOp,
                        instruction.End
                    ]
                )
            )
        )
    )
}

pub fn parse_locals_declaration___3_integer32___test()
{
    let reader = binary_reader.create(from: <<0x03, 0x7f>>)
    binary_parser.parse_locals_declaration(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 2),
            binary.LocalsDeclaration(count: 3, type_: types.Number(types.Integer32))
        )
    )
}

pub fn parse_locals_declaration___2_integer64___test()
{
    let reader = binary_reader.create(from: <<0x02, 0x7e>>)
    binary_parser.parse_locals_declaration(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 2),
            binary.LocalsDeclaration(count: 2, type_: types.Number(types.Integer64))
        )
    )
}

pub fn parse_locals_declaration___128_float32___test()
{
    let reader = binary_reader.create(from: <<0x80, 0x01, 0x7d>>)
    binary_parser.parse_locals_declaration(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 3),
            binary.LocalsDeclaration(count: 128, type_: types.Number(types.Float32))
        )
    )
}

pub fn parse_locals_declaration___123456_float64___test()
{
    let reader = binary_reader.create(from: <<0xc0, 0xc4, 0x07, 0x7c>>)
    binary_parser.parse_locals_declaration(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 4),
            binary.LocalsDeclaration(count: 123456, type_: types.Number(types.Float64))
        )
    )
}

pub fn parse_locals_declaration___255_vector128___test()
{
    let reader = binary_reader.create(from: <<0xff, 0x01, 0x7b>>)
    binary_parser.parse_locals_declaration(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 3),
            binary.LocalsDeclaration(count: 255, type_: types.Vector(types.Vector128))
        )
    )
}

pub fn parse_locals_declaration___2_function_reference___test()
{
    let reader = binary_reader.create(from: <<0x02, 0x70>>)
    binary_parser.parse_locals_declaration(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 2),
            binary.LocalsDeclaration(count: 2, type_: types.Reference(types.FunctionReference))
        )
    )
}

pub fn parse_locals_declaration___1_extern_reference___test()
{
    let reader = binary_reader.create(from: <<0x01, 0x6f>>)
    binary_parser.parse_locals_declaration(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 2),
            binary.LocalsDeclaration(count: 1, type_: types.Reference(types.ExternReference))
        )
    )
}

pub fn parse_function_code_test()
{
    let reader = binary_reader.create(from: <<
        0x07,                           // A vector with 7 LocalsDeclaration
            0x03,               0x7f,   // LocalsDeclaration(count: 3, type_: types.Number(types.Integer32))
            0x02,               0x7e,   // LocalsDeclaration(count: 2, type_: types.Number(types.Integer64))
            0x80, 0x01,         0x7d,   // LocalsDeclaration(count: 128, type_: types.Number(types.Float32))
            0xc0, 0xc4, 0x07,   0x7c,   // LocalsDeclaration(count: 123456, type_: types.Number(types.Float64))
            0xff, 0x01,         0x7b,   // LocalsDeclaration(count: 255, type_: types.Vector(types.Vector128))
            0x02,               0x70,   // LocalsDeclaration(count: 2, type_: types.Reference(types.FunctionReference))
            0x01,               0x6f,   // LocalsDeclaration(count: 1, type_: types.Reference(types.ExternReference))
        0x01,                           // NoOp <-- the function's body should begin here
        0x01,                           // NoOp
        0x0b,                           // End  <-- the function's body should terminate here
        0x01,                           // NoOp
        0x01,                           // NoOp
    >>)
    binary_parser.parse_function_code(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 22),
            binary.FunctionCode(
                locals: [
                    binary.LocalsDeclaration(count: 3, type_: types.Number(types.Integer32)),
                    binary.LocalsDeclaration(count: 2, type_: types.Number(types.Integer64)),
                    binary.LocalsDeclaration(count: 128, type_: types.Number(types.Float32)),
                    binary.LocalsDeclaration(count: 123456, type_: types.Number(types.Float64)),
                    binary.LocalsDeclaration(count: 255, type_: types.Vector(types.Vector128)),
                    binary.LocalsDeclaration(count: 2, type_: types.Reference(types.FunctionReference)),
                    binary.LocalsDeclaration(count: 1, type_: types.Reference(types.ExternReference)),
                ],
                body: [
                    instruction.NoOp,
                    instruction.NoOp,
                    instruction.End
                ]
            )
        )
    )
}