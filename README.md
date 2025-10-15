# GWR - Gleam WebAssembly Runtime

[![Package Version](https://img.shields.io/hexpm/v/gwr)](https://hex.pm/packages/gwr)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gwr/)
[![Package License](https://img.shields.io/hexpm/l/gwr)](/LICENSE)
[![Package Total Downloads Count](https://img.shields.io/hexpm/dt/gwr)](https://hex.pm/packages/gwr)
[![Test Status](https://github.com/BrendoCosta/gwr/actions/workflows/test.yml/badge.svg)](https://github.com/BrendoCosta/gwr/actions)
![Available for the Erlang runtime](https://img.shields.io/badge/target-Erlang-a2003e)
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
> Currently the project is in an extremely early stage of development; it is only possible to run very simple functions (consisting of basic integer arithmetic, function calls, and control flows). Keep in mind that code and APIs may change dramatically.

### Step 1 - Build code targeting Wasm

#### Example - Fibonacci sequence from Rust

```rust
// fib.rs

#![no_std]

#[panic_handler]
pub fn panic(_info: &core::panic::PanicInfo) -> !
{
    loop {}
}

#[unsafe(no_mangle)]
pub extern fn fib(value: i32) -> i32
{
    match value
    {
        v if v <= 0 => 0,
        v if v <= 2 => 1,
        _ => fib(value - 1) + fib(value - 2)
    }
}
```
```sh
rustc --crate-type cdylib --target wasm32-unknown-unknown -C debuginfo=none -C panic=abort -C strip=symbols -C opt-level=3 ./fib.rs -o ./fib.wasm
```

#### Example - Fibonacci sequence from WAT

Using the wat2wasm tool from [wabt](https://github.com/WebAssembly/wabt).

```wasm
;; fib.wat

(module
    (func $fib (export "fib") (param $value i32) (result i32)
        local.get $value
        i32.const 0
        i32.le_s
        if
            i32.const 0
            return
        end
        local.get $value
        i32.const 2
        i32.le_s
        if
            i32.const 1
            return
        end
        local.get $value
        i32.const 1
        i32.sub
        call $fib
        local.get $value
        i32.const 2
        i32.sub
        call $fib
        i32.add
        return
    )
)
```
```sh
wat2wasm -o ./fib.wasm ./fib.wat
```

### Step 2 - Run it from Gleam with GWR

Using the [simplifile](https://hex.pm/packages/simplifile) package to read the module file.

```sh
gleam add simplifile
```

```gleam
import gwr/gwr
import gwr/spec
import simplifile

pub fn main()
{
    let assert Ok(data) = simplifile.read_bits(from: "fib.wasm")
    let assert Ok(binary) = gwr.load(from: data)
    let assert Ok(instance) = gwr.create(from: binary)
    let assert Ok(#(_instance, result)) = gwr.call(instance, "fib", [spec.Integer32Value(18)])
    let assert [spec.Integer32Value(2584)] = result
}
```

## Building

### Testing

To test the project, you must have [Devbox](https://www.jetify.com/docs/devbox/installing-devbox) installed in your environment. The project has a test suite written in Rust and WebAssembly text format intended to be built for the wasm target; Devbox setups a isolated build and testing environment with all the required tools so there is no need to install additional toolchains in your main environment.

```sh
devbox shell
devbox run test
```

The above command is equivalent to ```devbox run build_test_suite``` followed by ```gleam test```. Of course, once you have built the test suite, you can simply invoke ```gleam test```.

## Contributing

Contributions are welcome! Feel free to submit either issues or PRs, but keep in mind that your code needs to be covered by tests.

## License

GWR source code is avaliable under the [MIT license](/LICENSE).
