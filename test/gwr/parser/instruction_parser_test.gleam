import gwr/parser/instruction_parser
import gwr/parser/byte_reader
import gwr/syntax/instruction

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn i32_const_test()
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

pub fn local_get_test()
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