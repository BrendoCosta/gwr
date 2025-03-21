import gleam/list

import gwr/execution/numerics
import gwr/execution/trap

import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L37
pub fn iadd___i32___test()
{
    [
        #(1, 1, 2),
        #(1, 0, 1),
        #(-1, -1, 0xfffffffe),
        #(-1, 1, 0),
        #(0x7fffffff, 1, 0x80000000),
        #(0x80000000, -1, 0x7fffffff),
        #(0x80000000, 0x80000000, 0),
        #(0x3fffffff, 1, 0x40000000),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.iadd(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L46
pub fn isub___i32___test()
{
    [
        #(1, 1, 0),
        #(1, 0, 1),
        #(-1, -1, 0),
        #(0x7fffffff, -1, 0x80000000),
        #(0x80000000, 1, 0x7fffffff),
        #(0x80000000, 0x80000000, 0),
        #(0x3fffffff, -1, 0x40000000)
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.isub(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L54
pub fn imul___i32___test()
{
    [
        #(1, 1, 1),
        #(1, 0, 0),
        #(-1, -1, 1),
        #(0x10000000, 4096, 0),
        #(0x80000000, 0, 0),
        #(0x80000000, -1, 0x80000000),
        #(0x7fffffff, -1, 0x80000001),
        #(0x01234567, 0x76543210, 0x358e7470),
        #(0x7fffffff, 0x7fffffff, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.imul(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L85
pub fn idiv_u___i32___test()
{
    [
        #(1, 1, 1),
        #(0, 1, 0),
        #(-1, -1, 1),
        #(0x80000000, -1, 0),
        #(0x80000000, 2, 0x40000000),
        #(0x8ff00ff0, 0x10001, 0x8fef),
        #(0x80000001, 1000, 0x20c49b),
        #(5, 2, 2),
        #(-5, 2, 0x7ffffffd),
        #(5, -2, 0),
        #(-5, -2, 0),
        #(7, 3, 2),
        #(11, 5, 2),
        #(17, 7, 2),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.idiv_u(32, a, b)
        |> should.be_ok
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L85
pub fn idiv_u___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
        #(0x80000000, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.idiv_u(32, a, b)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L64
pub fn idiv_s___i32___test()
{
    [
        #(1, 1, 1),
        #(0, 1, 0),
        #(0, -1, 0),
        #(-1, -1, 1),
        #(0x80000000, 2, 0xc0000000),
        #(0x80000001, 1000, 0xffdf3b65),
        #(5, 2, 2),
        #(-5, 2, -2),
        #(5, -2, -2),
        #(-5, -2, 2),
        #(7, 3, 2),
        #(-7, 3, -2),
        #(7, -3, -2),
        #(-7, -3, 2),
        #(11, 5, 2),
        #(17, 7, 2),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.idiv_s(32, a, b)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L64
pub fn idiv_s___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
        #(0x80000000, -1, trap.Overflow),
        #(0x80000000, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.idiv_s(32, a, b)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L125
pub fn irem_u___i32___test()
{
    [
        #(1, 1, 0),
        #(0, 1, 0),
        #(-1, -1, 0),
        #(0x80000000, -1, 0x80000000),
        #(0x80000000, 2, 0),
        #(0x8ff00ff0, 0x10001, 0x8001),
        #(0x80000001, 1000, 649),
        #(5, 2, 1),
        #(-5, 2, 1),
        #(5, -2, 5),
        #(-5, -2, -5),
        #(7, 3, 1),
        #(11, 5, 1),
        #(17, 7, 3),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.irem_u(32, a, b)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L123
pub fn irem_u___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.irem_u(32, a, b)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L104
pub fn irem_s___i32___test()
{
    [
        #(0x7fffffff, -1, 0),
        #(1, 1, 0),
        #(0, 1, 0),
        #(0, -1, 0),
        #(-1, -1, 0),
        #(0x80000000, -1, 0),
        #(0x80000000, 2, 0),
        #(0x80000001, 1000, -647),
        #(5, 2, 1),
        #(-5, 2, -1),
        #(5, -2, 1),
        #(-5, -2, -1),
        #(7, 3, 1),
        #(-7, 3, -1),
        #(7, -3, 1),
        #(-7, -3, -1),
        #(11, 5, 1),
        #(17, 7, 3),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.irem_s(32, a, b)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L102
pub fn irem_s___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.irem_s(32, a, b)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L140
pub fn iand___i32___test()
{
    [
        #(1, 0, 0),
        #(0, 1, 0),
        #(1, 1, 1),
        #(0, 0, 0),
        #(0x7fffffff, 0x80000000, 0),
        #(0x7fffffff, -1, 0x7fffffff),
        #(0xf0f0ffff, 0xfffff0f0, 0xf0f0f0f0),
        #(0xffffffff, 0xffffffff, 0xffffffff),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.iand(32, a, b)
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L149C1-L156C99
pub fn ior___i32___test()
{
    [
        #(1, 0, 1),
        #(0, 1, 1),
        #(1, 1, 1),
        #(0, 0, 0),
        #(0x7fffffff, 0x80000000, -1),
        #(0x80000000, 0, 0x80000000),
        #(0xf0f0ffff, 0xfffff0f0, 0xffffffff),
        #(0xffffffff, 0xffffffff, 0xffffffff),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ior(32, a, b)
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L158
pub fn ixor___i32___test()
{
    [
        #(1, 0, 1),
        #(0, 1, 1),
        #(1, 1, 0),
        #(0, 0, 0),
        #(0x7fffffff, 0x80000000, -1),
        #(0x80000000, 0, 0x80000000),
        #(-1, 0x80000000, 0x7fffffff),
        #(-1, 0x7fffffff, 0x80000000),
        #(0xf0f0ffff, 0xfffff0f0, 0x0f0f0f0f),
        #(0xffffffff, 0xffffffff, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ixor(32, a, b)
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L245C1-L252C68
pub fn iclz___i32___test()
{
    [
        #(0xffffffff, 0),
        #(0, 32),
        #(0x00008000, 16),
        #(0xff, 24),
        #(0x80000000, 0),
        #(1, 31),
        #(2, 30),
        #(0x7fffffff, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, expected) = test_case
        numerics.iclz(32, a)
        |> should.be_ok
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L254C1-L259C68
pub fn ictz___i32___test()
{
    [
        #(-1, 0),
        #(0, 32),
        #(0x00008000, 15),
        #(0x00010000, 16),
        #(0x80000000, 31),
        #(0x7fffffff, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, expected) = test_case
        numerics.ictz(32, a)
        |> should.be_ok
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L261
pub fn ipopcnt___i32___test()
{
    [
        #(-1, 32),
        #(0, 0),
        #(0x00008000, 1),
        #(0x80008000, 2),
        #(0x7fffffff, 31),
        #(0xaaaaaaaa, 16),
        #(0x55555555, 16),
        #(0xdeadbeef, 24),
    ]
    |> list.each(fn (test_case) {
        let #(a, expected) = test_case
        numerics.ipopcnt(32, a)
        |> should.be_ok
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L286
pub fn ieqz___i32___test()
{
    [
        #(0, 1),
        #(1, 0),
        #(0x80000000, 0),
        #(0x7fffffff, 0),
        #(0xffffffff, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, expected) = test_case
        numerics.ieqz(a)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L292C1-L305C90
pub fn ieq___i32___test()
{
    [
        #(0, 0, 1),
        #(1, 1, 1),
        #(-1, 1, 0),
        #(0x80000000, 0x80000000, 1),
        #(0x7fffffff, 0x7fffffff, 1),
        #(-1, -1, 1),
        #(1, 0, 0),
        #(0, 1, 0),
        #(0x80000000, 0, 0),
        #(0, 0x80000000, 0),
        #(0x80000000, -1, 0),
        #(-1, 0x80000000, 0),
        #(0x80000000, 0x7fffffff, 0),
        #(0x7fffffff, 0x80000000, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ieq(a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L307
pub fn ine___i32___test()
{
    [
        #(0, 0, 0),
        #(1, 1, 0),
        #(-1, 1, 1),
        #(0x80000000, 0x80000000, 0),
        #(0x7fffffff, 0x7fffffff, 0),
        #(-1, -1, 0),
        #(1, 0, 1),
        #(0, 1, 1),
        #(0x80000000, 0, 1),
        #(0, 0x80000000, 1),
        #(0x80000000, -1, 1),
        #(-1, 0x80000000, 1),
        #(0x80000000, 0x7fffffff, 1),
        #(0x7fffffff, 0x80000000, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ine(a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L337C1-L350C92
pub fn ilt_u___i32___test()
{
    [
        #(0, 0, 0),
        #(1, 1, 0),
        #(-1, 1, 0),
        #(0x80000000, 0x80000000, 0),
        #(0x7fffffff, 0x7fffffff, 0),
        #(-1, -1, 0),
        #(1, 0, 0),
        #(0, 1, 1),
        #(0x80000000, 0, 0),
        #(0, 0x80000000, 1),
        #(0x80000000, -1, 1),
        #(-1, 0x80000000, 0),
        #(0x80000000, 0x7fffffff, 0),
        #(0x7fffffff, 0x80000000, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ilt_u(32, a, b)
        |> should.equal(expected)
    })
}