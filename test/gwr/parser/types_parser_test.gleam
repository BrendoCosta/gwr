import gleam/option.{None, Some}

import gwr/parser/byte_reader
import gwr/parser/types_parser
import gwr/syntax/types

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn parse_function_type_test()
{
    let reader = byte_reader.create(from: <<
        0x60,                               // Flag
        0x02, 0x7f, 0x7e,                   // Parameters -> A vector with U32 LEB128 length = 2 and content = [I32, I64]
        0x05, 0x7d, 0x7c, 0x7b, 0x70, 0x6f  // Results -> A vector with U32 LEB128 length = 5 and content = [F32, F64, V128, FuncRef, ExternRef]
    >>)
    types_parser.parse_function_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 10),
            types.FunctionType(
                parameters: [
                    types.Number(types.Integer32),
                    types.Number(types.Integer64)
                ],
                results: [
                    types.Number(types.Float32),
                    types.Number(types.Float64),
                    types.Vector(types.Vector128),
                    types.Reference(types.FunctionReference),
                    types.Reference(types.ExternReference)
                ]
            )
        )
    )
}

pub fn parse_function_type___empty_vectors___test()
{
    let reader = byte_reader.create(from: <<0x60, 0x00, 0x00>>)
    types_parser.parse_function_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 3),
            types.FunctionType(parameters: [], results: [])
        )
    )
}

pub fn parse_global_type___constant___test()
{
    let reader = byte_reader.create(from: <<0x7f, 0x00>>)
    types_parser.parse_global_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 2),
            types.GlobalType(value_type: types.Number(types.Integer32), mutability: types.Constant)
        )
    )
}

pub fn parse_global_type___variable___test()
{
    let reader = byte_reader.create(from: <<0x7e, 0x01>>)
    types_parser.parse_global_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 2),
            types.GlobalType(value_type: types.Number(types.Integer64), mutability: types.Variable)
        )
    )
}

pub fn parse_limits___no_max___test()
{
    let reader = byte_reader.create(from: <<0x00, 0x03>>)
    types_parser.parse_limits(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 2),
            types.Limits(min: 3, max: None)
        )
    )
}

pub fn parse_limits___with_max___test()
{
    let reader = byte_reader.create(from: <<0x01, 0x20, 0x80, 0x02>>)
    types_parser.parse_limits(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 4),
            types.Limits(min: 32, max: Some(256)),
        )
    )
}

pub fn parse_value_type___integer_32___test()
{
    let reader = byte_reader.create(from: <<0x7f>>)
    types_parser.parse_value_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            types.Number(types.Integer32)
        )
    )
}

pub fn parse_value_type___integer_64___test()
{
    let reader = byte_reader.create(from: <<0x7e>>)
    types_parser.parse_value_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            types.Number(types.Integer64)
        )
    )
}

pub fn parse_value_type___float_32___test()
{
    let reader = byte_reader.create(from: <<0x7d>>)
    types_parser.parse_value_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            types.Number(types.Float32)
        )
    )
}

pub fn parse_value_type___float_64___test()
{
    let reader = byte_reader.create(from: <<0x7c>>)
    types_parser.parse_value_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            types.Number(types.Float64)
        )
    )
}

pub fn parse_value_type___vector_128___test()
{
    let reader = byte_reader.create(from: <<0x7b>>)
    types_parser.parse_value_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            types.Vector(types.Vector128)
        )
    )
}

pub fn parse_value_type___function_reference___test()
{
    let reader = byte_reader.create(from: <<0x70>>)
    types_parser.parse_value_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            types.Reference(types.FunctionReference)
        )
    )
}

pub fn parse_value_type___extern_reference___test()
{
    let reader = byte_reader.create(from: <<0x6f>>)
    types_parser.parse_value_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            types.Reference(types.ExternReference)
        )
    )
}