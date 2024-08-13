import gleeunit
import gleeunit/should

import gwr/types/vector as vector

pub fn main()
{
    gleeunit.main()
}

pub fn from_raw_data_test()
{
    vector.from_raw_data(at: 0, from: <<0x0c, "Hello World!":utf8>>)
    |> should.be_ok
    |> should.equal(vector.Vector(length: 0x0c, data: <<"Hello World!":utf8>>))
}

pub fn from_raw_data___truncated___test()
{
    vector.from_raw_data(at: 0, from: <<0x80, 0x02, 0x00:size(256 * 8)>>)
    |> should.be_ok
    |> should.equal(vector.Vector(length: 256, data: <<0x00:size(256 * 8)>>))
}

pub fn from_raw_data___unexpected_end___test()
{
    vector.from_raw_data(at: 0, from: <<0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
    |> should.be_error
    |> should.equal("vector::from_raw_data: unexpected end of the vector's data. Expected = 7 bytes but got = 6 bytes")
}



