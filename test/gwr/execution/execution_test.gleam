import gwr/gwr
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
    let instance = gwr.create(from: module_data) |> should.be_ok
    let #(_, result) = gwr.call(instance, "sum", [runtime.Integer32(4), runtime.Integer32(2)]) |> should.be_ok
    result |> should.equal([runtime.Integer32(6)])
}

pub fn block_test()
{
    let module_data = simplifile.read_bits(from: "./test/assets/control/block.wasm") |> should.be_ok
    let instance = gwr.create(from: module_data) |> should.be_ok
    let #(_, result) = gwr.call(instance, "block_test", [runtime.Integer32(2), runtime.Integer32(3)]) |> should.be_ok
    result |> should.equal([runtime.Integer32(7)])
}

pub fn if_else___if_scope___test()
{
    let module_data = simplifile.read_bits(from: "./test/assets/control/if_else.wasm") |> should.be_ok
    let instance = gwr.create(from: module_data) |> should.be_ok
    let #(_, result) = gwr.call(instance, "if_else_test", [runtime.Integer32(0)]) |> should.be_ok
    result |> should.equal([runtime.Integer32(110)])
}

pub fn if_else___else_scope___test()
{
    let module_data = simplifile.read_bits(from: "./test/assets/control/if_else.wasm") |> should.be_ok
    let instance = gwr.create(from: module_data) |> should.be_ok
    let #(_, result) = gwr.call(instance, "if_else_test", [runtime.Integer32(1)]) |> should.be_ok
    result |> should.equal([runtime.Integer32(120)])
}
