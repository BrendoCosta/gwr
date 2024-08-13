import gleeunit
import gleeunit/should
import gleam/option.{Some, None}

import gwr/types/limits.{Limits}
import gwr/types/vector

pub fn main()
{
    gleeunit.main()
}

pub fn from_raw_data___no_max___test()
{
    limits.from_raw_data(at: 0, from: <<0x00, 0x03>>)
    |> should.be_ok
    |> should.equal(#(Limits(min: 3, max: None), 2))
}

pub fn from_raw_data___with_max___test()
{
    limits.from_raw_data(at: 0, from: <<0x01, 0x20, 0x80, 0x02>>)
    |> should.be_ok
    |> should.equal(#(Limits(min: 32, max: Some(256)), 4))
}

pub fn from_vec_test()
{
    vector.from_raw_data(at: 0, from: <<0x06, 0x00, 0x03, 0x01, 0x20, 0x80, 0x02>>)
    |> should.be_ok
    |> limits.from_vector
    |> should.be_ok
    |> should.equal(#([Limits(min: 3, max: None), Limits(min: 32, max: Some(256))], 6))

}