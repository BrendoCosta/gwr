import gleam/bit_array

import gwr/parser/convention_parser
import gwr/parser/byte_reader

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn parse_vector___bytes___test()
{
    let reader = byte_reader.create(from: <<0x01, "Hello World!":utf8>>)
    convention_parser.parse_vector(from: reader, with: fn (reader) {
        let assert Ok(#(reader, string_data)) = byte_reader.read_remaining(from: reader)
        Ok(#(reader, bit_array.to_string(string_data)))
    })
    |> should.be_ok
    |> should.equal(
        #(
            byte_reader.ByteReader(..reader, current_position: 13),
            [Ok("Hello World!")]
        )
    )
}