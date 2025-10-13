import gleam/pair

import gwr/gwr
import gwr/spec

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
    |> gwr.load()
    |> should.be_ok
    |> gwr.create()
    |> should.be_ok
    |> gwr.call("fib", [spec.Integer32Value(12)])
    |> should.be_ok
    |> pair.second
    |> should.equal([spec.Integer32Value(144)])
}
