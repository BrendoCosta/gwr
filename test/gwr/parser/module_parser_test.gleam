import gleam/option.{None, Some}

import gwr/parser/binary_reader
import gwr/parser/module_parser
import gwr/syntax/module
import gwr/syntax/types

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn parse_export___function_export___test()
{
    let reader = binary_reader.create(from: <<0x0b, "my_function":utf8, 0x00, 0x00>>)
    module_parser.parse_export(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 14),
            module.Export(name: "my_function", descriptor: module.FunctionExport(index: 0))
        )
    )
}

pub fn parse_export___table_export___test()
{
    let reader = binary_reader.create(from: <<0x08, "my_table":utf8, 0x01, 0xc0, 0xc4, 0x07>>)
    module_parser.parse_export(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 13),
            module.Export(name: "my_table", descriptor: module.TableExport(index: 123456))
        )
    )
}

pub fn parse_export___memory_export___test()
{
    let reader = binary_reader.create(from: <<0x09, "my_memory":utf8, 0x02, 0xff, 0x01>>)
    module_parser.parse_export(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 13),
            module.Export(name: "my_memory", descriptor: module.MemoryExport(index: 255))
        )
    )
}

pub fn parse_export___global_export___test()
{
    let reader = binary_reader.create(from: <<0x09, "my_global":utf8, 0x03, 0xff, 0xff, 0xff, 0xff, 0x0f>>)
    module_parser.parse_export(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 16),
            module.Export(name: "my_global", descriptor: module.GlobalExport(index: 4294967295))
        )
    )
}

pub fn parse_memory___with_max___test()
{
    let reader = binary_reader.create(from: <<0x00, 0xff, 0xff, 0x03>>)
    module_parser.parse_memory(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 4),
            module.Memory(type_: types.Limits(min: 65535, max: None))
        )
    )
}

pub fn parse_memory___without_max___test()
{
    let reader = binary_reader.create(from: <<0x01, 0x80, 0x08, 0x80, 0x40>>)
    module_parser.parse_memory(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 5),
            module.Memory(type_: types.Limits(min: 1024, max: Some(8192)))
        )
    )
}

