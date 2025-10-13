import gleam/pair

import gwr/gwr
import gwr/spec

import gleeunit
import gleeunit/should
import simplifile

const build_path = "./test_suite/wat/"

pub fn main() {
  gleeunit.main()
}

pub fn wat_block_test() {
  simplifile.read_bits(from: build_path <> "block.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("block_test", [spec.Integer32Value(2), spec.Integer32Value(3)])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(7)])
}

pub fn wat_call_test() {
  simplifile.read_bits(from: build_path <> "call.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("call_test", [spec.Integer32Value(5), spec.Integer32Value(2)])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(7)])
}

pub fn wat_if_else___if_scope___test() {
  simplifile.read_bits(from: build_path <> "if_else.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("if_else_test", [spec.Integer32Value(0)])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(110)])
}

pub fn wat_if_else___else_scope___test() {
  simplifile.read_bits(from: build_path <> "if_else.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("if_else_test", [spec.Integer32Value(1)])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(120)])
}

pub fn wat_loop_test() {
  simplifile.read_bits(from: build_path <> "loop.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("loop_test", [])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(10)])
}

pub fn wat_recursion_test() {
  simplifile.read_bits(from: build_path <> "recursion.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("recursion_test", [spec.Integer32Value(3), spec.Integer32Value(0)])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(6)])
}

pub fn wat_fib_test() {
  simplifile.read_bits(from: build_path <> "fib.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("fib", [spec.Integer32Value(18)])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(2584)])
}

pub fn wat_sum_test() {
  simplifile.read_bits(from: build_path <> "sum.wasm")
  |> should.be_ok
  |> gwr.load()
  |> should.be_ok
  |> gwr.create()
  |> should.be_ok
  |> gwr.call("sum", [spec.Integer32Value(4), spec.Integer32Value(2)])
  |> should.be_ok
  |> pair.second
  |> should.equal([spec.Integer32Value(6)])
}
