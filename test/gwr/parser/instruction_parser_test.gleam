import gleam/option
import gwr/syntax/types
import gwr/parser/instruction_parser
import gwr/parser/byte_reader
import gwr/syntax/instruction

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn parse_block_type___empty_block___test()
{
    let reader = byte_reader.create(from: <<0x40>>)
    instruction_parser.parse_block_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            instruction.ValueTypeBlock(type_: option.None)
        )
    )
}

pub fn parse_block_type___value_type_block___test()
{
    let reader = byte_reader.create(from: <<0x7f>>)
    instruction_parser.parse_block_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 1),
            instruction.ValueTypeBlock(type_: option.Some(types.Number(types.Integer32)))
        )
    )
}

pub fn parse_block_type___type_index_block___test()
{
    let reader = byte_reader.create(from: <<0x80, 0x80, 0x04>>)
    instruction_parser.parse_block_type(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 3),
            instruction.TypeIndexBlock(index: 65536)
        )
    )
}

pub fn parse_instruction___block___test()
{
    let reader = byte_reader.create(from: <<0x02, 0x01, 0x41, 0x80, 0x80, 0xc0, 0x00, 0x41, 0x2, 0x0b>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 10),
            instruction.Block(
                block_type: instruction.TypeIndexBlock(index: 1),
                instructions: [
                    instruction.I32Const(value: 1048576),
                    instruction.I32Const(value: 2),
                    instruction.End
                ]
            )
        )
    )
}

pub fn parse_instruction___loop___test()
{
    let reader = byte_reader.create(from: <<0x03, 0x7f, 0x41, 0x08, 0x41, 0x80, 0x80, 0x04, 0x0b>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 9),
            instruction.Loop(
                block_type: instruction.ValueTypeBlock(type_: option.Some(types.Number(types.Integer32))),
                instructions: [
                    instruction.I32Const(value: 8),
                    instruction.I32Const(value: 65536),
                    instruction.End
                ]
            )
        )
    )
}

pub fn parse_instruction___if___test()
{
    let reader = byte_reader.create(from: <<0x04, 0x7f, 0x41, 0x80, 0x80, 0x04, 0x0b>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 7),
            instruction.If(
                block_type: instruction.ValueTypeBlock(type_: option.Some(types.Number(types.Integer32))),
                instructions: [
                    instruction.I32Const(value: 65536),
                    instruction.End
                ],
                else_: option.None
            )
        )
    )
}

pub fn parse_instruction___if_else___test()
{
    let reader = byte_reader.create(from: <<0x04, 0x7f, 0x41, 0x80, 0x80, 0x04, 0x05, 0x41, 0x02, 0x0b>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 10),
            instruction.If(
                block_type: instruction.ValueTypeBlock(type_: option.Some(types.Number(types.Integer32))),
                instructions: [
                    instruction.I32Const(value: 65536),
                ],
                else_: option.Some(
                    instruction.Else(
                        instructions: [
                            instruction.I32Const(value: 2),
                            instruction.End
                        ]
                    )
                )
            )
        )
    )
}

pub fn parse_instruction___i32_const___test()
{
    let reader = byte_reader.create(from: <<0x41, 0x80, 0x80, 0xc0, 0x00>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 5),
            instruction.I32Const(value: 1048576)
        )
    )
}

pub fn parse_instruction___local_get___test()
{
    let reader = byte_reader.create(from: <<0x20, 0xff, 0x01>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 3),
            instruction.LocalGet(index: 255)
        )
    )
}

pub fn parse_instruction___local_tee___test()
{
    let reader = byte_reader.create(from: <<0x20, 0x80, 0x80, 0x04>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 4),
            instruction.LocalGet(index: 65536)
        )
    )
}

pub fn parse_instruction___br___test()
{
    let reader = byte_reader.create(from: <<0x0c, 0xff, 0x01>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 3),
            instruction.Br(index: 255)
        )
    )
}

pub fn parse_instruction___br_if___test()
{
    let reader = byte_reader.create(from: <<0x0d, 0x80, 0x80, 0x04>>)
    instruction_parser.parse_instruction(reader)
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 4),
            instruction.BrIf(index: 65536)
        )
    )
}