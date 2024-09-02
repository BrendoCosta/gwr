# GWR - Gleam WebAssembly Runtime

[![Package Version](https://img.shields.io/hexpm/v/gwr)](https://hex.pm/packages/gwr)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gwr/)
[![Package License](https://img.shields.io/hexpm/l/gwr)](https://hex.pm/packages/gwr)
[![Package Total Downloads Count](https://img.shields.io/hexpm/dt/gwr)](https://hex.pm/packages/gwr)
[![Build Status](https://img.shields.io/github/actions/workflow/status/BrendoCosta/gwr/test.yml)](https://hex.pm/packages/gwr)
[![Total Stars Count](https://img.shields.io/github/stars/BrendoCosta/gwr)](https://hex.pm/packages/gwr)

## Description

An experimental work-in-progress (WIP) WebAssembly runtime written in Gleam.

## Purpose

Nowadays, many languages ​​support Wasm as a target, from mainstream ones like C++ and Rust, as well as newer ones like Odin and Grain. The purpose of this project is to use WebAssembly to create an alternative interoperability layer to Erlang's virtual machine NIFs.

## Installation

```sh
gleam add gwr
```

## Usage

> [!IMPORTANT]
> Currently the project is in an extremely early stage of development, it is only possible to run a simple sum function. Keep in mind that code and APIs may change dramatically.

### Step 1 - Build code targeting Wasm

#### Example - from Rust

```rust
// sum.rs

#![no_std]

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> !
{
    loop {}
}

#[no_mangle]
pub extern fn sum(x: i32, y: i32) -> i32
{
    x + y
}
```
```sh
rustc --crate-type cdylib --target wasm32-unknown-unknown -C debuginfo=none -C panic=abort -C strip=symbols -C opt-level=3 ./sum.rs -o ./sum.wasm
```

#### Example - from Wat

Using the wat2wasm tool from [wabt](https://github.com/WebAssembly/wabt).

```wasm
;; sum.wat

(module
    (type $t0 (func (param i32 i32) (result i32)))
    (func $sum (export "sum") (type $t0) (param $p0 i32) (param $p1 i32) (result i32)
        (i32.add (local.get $p0) (local.get $p1))
    )
)
```
```sh
wat2wasm -o ./sum.wasm ./sum.wat
```

### Step 2 - Run it from Gleam with GWR

Using the [simplifile](https://hex.pm/packages/simplifile) package to read the module file.

```sh
gleam add simplifile
```

```gleam
import gwr/execution/instance
import gwr/execution/runtime
import simplifile

pub fn main()
{
    let assert Ok(module_data) = simplifile.read_bits(from: "sum.wasm")
    let assert Ok(instance) = instance.create(from: module_data)
    let assert Ok(#(instance, result)) = instance.call(instance, "sum", [runtime.Number(4), runtime.Number(2)])
    let assert [runtime.Number(6)] = result
}
```

## Contributing

Contributions are welcome! Feel free to submit either issues or PRs, but keep in mind that your code needs to be covered by tests.

## License

GWR source code is avaliable under the [MIT license](/LICENSE).