import gwr/parser/binary_reader
import gwr/parser/value_parser

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn parse_name_test()
{
    let reader = binary_reader.create(from: <<0x09, "some_name":utf8>>)
    value_parser.parse_name(reader)
    |> should.be_ok
    |> should.equal(
        #(
            binary_reader.BinaryReader(..reader, current_position: 10),
            "some_name"
        )
    )
}