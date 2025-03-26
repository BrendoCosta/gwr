import gleam/list
import gleam/pair

import gwr/parser/byte_reader
import gwr/parser/value_parser

import gleeunit
import gleeunit/should

import ieee_float

pub fn main()
{
    gleeunit.main()
}

pub fn parse_le32_float_test()
{
    [
        #(<<0x00, 0x00, 0x00, 0x00>>, ieee_float.finite(0.0)),
        #(<<0x00, 0x00, 0x80, 0x3f>>, ieee_float.finite(1.0)),
        #(<<0x00, 0x00, 0x80, 0xbf>>, ieee_float.finite(-1.0)),
        #(<<0x00, 0x00, 0x80, 0x7f>>, ieee_float.positive_infinity()),
        #(<<0x00, 0x00, 0x80, 0xff>>, ieee_float.negative_infinity()),
        #(<<0x00, 0x00, 0xc0, 0x7f>>, ieee_float.nan()),
    ]
    |> list.each(fn (test_case) {
        let reader = byte_reader.create(from: test_case.0)
        value_parser.parse_le32_float(reader)
        |> should.be_ok
        |> pair.second
        |> should.equal(test_case.1)
    })
}

pub fn parse_le64_float_test()
{
    [
        #(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>, ieee_float.finite(0.0)),
        #(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x3f>>, ieee_float.finite(1.0)),
        #(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0xbf>>, ieee_float.finite(-1.0)),
        #(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x7f>>, ieee_float.positive_infinity()),
        #(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0xff>>, ieee_float.negative_infinity()),
        #(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0x7f>>, ieee_float.nan()),
    ]
    |> list.each(fn (test_case) {
        let reader = byte_reader.create(from: test_case.0)
        value_parser.parse_le64_float(reader)
        |> should.be_ok
        |> pair.second
        |> should.equal(test_case.1)
    })
}

pub fn parse_name_test()
{
    let reader = byte_reader.create(from: <<0x09, "some_name":utf8>>)
    value_parser.parse_name(reader)
    |> should.be_ok
    |> pair.second
    |> should.equal("some_name")
}