import gwr/execution/instance
import gwr/execution/runtime

import gleeunit
import gleeunit/should
import simplifile

pub fn main()
{
    gleeunit.main()
}

pub fn sum_test()
{
    let module_data = simplifile.read_bits(from: "./test/assets/sum.wasm") |> should.be_ok
    let instance = instance.create(from: module_data) |> should.be_ok
    let #(_, result) = instance.call(instance, "sum", [runtime.Number(4), runtime.Number(2)]) |> should.be_ok
    result |> should.equal([runtime.Number(6)])
}