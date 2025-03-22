import gleam/pair

import gwr/gwr
import gwr/execution/runtime

import gleeunit
import gleeunit/should
import simplifile

const build_path = "./test_suite/rust/target/wasm32-unknown-unknown/release/"

pub fn main()
{
    gleeunit.main()
}

pub fn rust_fib_test()
{
    simplifile.read_bits(from: build_path <> "fib.wasm")
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("fib", [runtime.Integer32(12)])
    |> should.be_ok
    |> pair.second
    |> should.equal([runtime.Integer32(144)])
}