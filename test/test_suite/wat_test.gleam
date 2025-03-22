import gleam/pair

import gwr/gwr
import gwr/execution/runtime

import gleeunit
import gleeunit/should
import simplifile

const build_path = "./test_suite/wat/"

pub fn main()
{
    gleeunit.main()
}

pub fn wat_block_test()
{
    simplifile.read_bits(from: build_path <> "block.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("block_test", [runtime.Integer32(2), runtime.Integer32(3)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(7)])
}

pub fn wat_call_test()
{
    simplifile.read_bits(from: build_path <> "call.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("call_test", [runtime.Integer32(5), runtime.Integer32(2)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(7)])
}

pub fn wat_if_else___if_scope___test()
{
    simplifile.read_bits(from: build_path <> "if_else.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("if_else_test", [runtime.Integer32(0)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(110)])
}

pub fn wat_if_else___else_scope___test()
{
    simplifile.read_bits(from: build_path <> "if_else.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("if_else_test", [runtime.Integer32(1)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(120)])
}

pub fn wat_loop_test()
{
    simplifile.read_bits(from: build_path <> "loop.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("loop_test", [])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(10)])
}

pub fn wat_recursion_test()
{
    simplifile.read_bits(from: build_path <> "recursion.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("recursion_test", [runtime.Integer32(3), runtime.Integer32(0)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(6)])
}

pub fn wat_fib_test()
{
    simplifile.read_bits(from: build_path <> "fib.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("fib", [runtime.Integer32(18)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(2584)])
}

pub fn wat_sum_test()
{
    simplifile.read_bits(from: build_path <> "sum.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("sum", [runtime.Integer32(4), runtime.Integer32(2)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(6)])
}