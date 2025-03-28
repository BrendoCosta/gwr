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

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L169C1-L179C91
pub fn ishl___i32___test()
{
    [
        #(1, 1, 2),
        #(1, 0, 1),
        #(0x7fffffff, 1, 0xfffffffe),
        #(0xffffffff, 1, 0xfffffffe),
        #(0x80000000, 1, 0),
        #(0x40000000, 1, 0x80000000),
        #(1, 31, 0x80000000),
        #(1, 32, 1),
        #(1, 33, 2),
        #(1, -1, 0x80000000),
        #(1, 0x7fffffff, 0x80000000),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ishl(32, a, b)
        |> should.be_ok
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L199C1-L215C86
pub fn ishr_u___i32___test()
{
    [
        #(1, 1, 0),
        #(1, 0, 1),
        #(-1, 1, 0x7fffffff),
        #(0x7fffffff, 1, 0x3fffffff),
        #(0x80000000, 1, 0x40000000),
        #(0x40000000, 1, 0x20000000),
        #(1, 32, 1),
        #(1, 33, 0),
        #(1, -1, 0),
        #(1, 0x7fffffff, 0),
        #(1, 0x80000000, 1),
        #(0x80000000, 31, 1),
        #(-1, 32, -1),
        #(-1, 33, 0x7fffffff),
        #(-1, -1, 1),
        #(-1, 0x7fffffff, 1),
        #(-1, 0x80000000, -1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ishr_u(32, a, b)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L181
pub fn ishr_s___i32___test()
{
    [
        #(1, 1, 0),
        #(1, 0, 1),
        #(-1, 1, -1),
        #(0x7fffffff, 1, 0x3fffffff),
        #(0x80000000, 1, 0xc0000000),
        #(0x40000000, 1, 0x20000000),
        #(1, 32, 1),
        #(1, 33, 0),
        #(1, -1, 0),
        #(1, 0x7fffffff, 0),
        #(1, 0x80000000, 1),
        #(0x80000000, 31, -1),
        #(-1, 32, -1),
        #(-1, 33, -1),
        #(-1, -1, -1),
        #(-1, 0x7fffffff, -1),
        #(-1, 0x80000000, -1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ishr_s(32, a, b)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L217
pub fn irotl___i32___test()
{
    [
        #(1, 1, 2),
        #(1, 0, 1),
        #(-1, 1, -1),
        #(1, 32, 1),
        #(0xabcd9876, 1, 0x579b30ed),
        #(0xfe00dc00, 4, 0xe00dc00f),
        #(0xb0c1d2e3, 5, 0x183a5c76),
        #(0x00008000, 37, 0x00100000),
        #(0xb0c1d2e3, 0xff05, 0x183a5c76),
        #(0x769abcdf, 0xffffffed, 0x579beed3),
        #(0x769abcdf, 0x8000000d, 0x579beed3),
        #(1, 31, 0x80000000),
        #(0x80000000, 1, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.irotl(32, a, b)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L231C1-L243C84
pub fn irotr___i32___test()
{
    [
        #(1, 1, 0x80000000),
        #(1, 0, 1),
        #(-1, 1, -1),
        #(1, 32, 1),
        #(0xff00cc00, 1, 0x7f806600),
        #(0x00080000, 4, 0x00008000),
        #(0xb0c1d2e3, 5, 0x1d860e97),
        #(0x00008000, 37, 0x00000400),
        #(0xb0c1d2e3, 0xff05, 0x1d860e97),
        #(0x769abcdf, 0xffffffed, 0xe6fbb4d5),
        #(0x769abcdf, 0x8000000d, 0xe6fbb4d5),
        #(1, 31, 2),
        #(0x80000000, 31, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.irotr(32, a, b)
        |> should.be_ok
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

/// https://github.com/WebAssembly/testsuite/blob/d76759e746f3564a03f6106ae19679742f2a1831/i32.wast#L322
pub fn ilt_s___i32___test()
{
    [
        #(0, 0, 0),
        #(1, 1, 0),
        #(-1, 1, 1),
        #(0x80000000, 0x80000000, 0),
        #(0x7fffffff, 0x7fffffff, 0),
        #(-1, -1, 0),
        #(1, 0, 0),
        #(0, 1, 1),
        #(0x80000000, 0, 1),
        #(0, 0x80000000, 0),
        #(0x80000000, -1, 1),
        #(-1, 0x80000000, 0),
        #(0x80000000, 0x7fffffff, 1),
        #(0x7fffffff, 0x80000000, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ilt_s(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/d76759e746f3564a03f6106ae19679742f2a1831/i32.wast#L397
pub fn igt_u___i32___test()
{
    [
        #(0, 0, 0),
        #(1, 1, 0),
        #(-1, 1, 1),
        #(0x80000000, 0x80000000, 0),
        #(0x7fffffff, 0x7fffffff, 0),
        #(-1, -1, 0),
        #(1, 0, 1),
        #(0, 1, 0),
        #(0x80000000, 0, 1),
        #(0, 0x80000000, 0),
        #(0x80000000, -1, 0),
        #(-1, 0x80000000, 1),
        #(0x80000000, 0x7fffffff, 1),
        #(0x7fffffff, 0x80000000, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.igt_u(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/d76759e746f3564a03f6106ae19679742f2a1831/i32.wast#L382C1-L395C92
pub fn igt_s___i32___test()
{
    [
        #(0, 0, 0),
        #(1, 1, 0),
        #(-1, 1, 0),
        #(0x80000000, 0x80000000, 0),
        #(0x7fffffff, 0x7fffffff, 0),
        #(-1, -1, 0),
        #(1, 0, 1),
        #(0, 1, 0),
        #(0x80000000, 0, 0),
        #(0, 0x80000000, 1),
        #(0x80000000, -1, 0),
        #(-1, 0x80000000, 1),
        #(0x80000000, 0x7fffffff, 0),
        #(0x7fffffff, 0x80000000, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.igt_s(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/d76759e746f3564a03f6106ae19679742f2a1831/i32.wast#L367C1-L380C92
pub fn ile_u___i32___test()
{
    [
        #(0, 0, 1),
        #(1, 1, 1),
        #(-1, 1, 0),
        #(0x80000000, 0x80000000, 1),
        #(0x7fffffff, 0x7fffffff, 1),
        #(-1, -1, 1),
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
        numerics.ile_u(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/d76759e746f3564a03f6106ae19679742f2a1831/i32.wast#L352C1-L365C92
pub fn ile_s___i32___test()
{
    [
        #(0, 0, 1),
        #(1, 1, 1),
        #(-1, 1, 1),
        #(0x80000000, 0x80000000, 1),
        #(0x7fffffff, 0x7fffffff, 1),
        #(-1, -1, 1),
        #(1, 0, 0),
        #(0, 1, 1),
        #(0x80000000, 0, 1),
        #(0, 0x80000000, 0),
        #(0x80000000, -1, 1),
        #(-1, 0x80000000, 0),
        #(0x80000000, 0x7fffffff, 1),
        #(0x7fffffff, 0x80000000, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ile_s(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/d76759e746f3564a03f6106ae19679742f2a1831/i32.wast#L427C1-L440C92
pub fn ige_u___i32___test()
{
    [
        #(0, 0, 1),
        #(1, 1, 1),
        #(-1, 1, 1),
        #(0x80000000, 0x80000000, 1),
        #(0x7fffffff, 0x7fffffff, 1),
        #(-1, -1, 1),
        #(1, 0, 1),
        #(0, 1, 0),
        #(0x80000000, 0, 1),
        #(0, 0x80000000, 0),
        #(0x80000000, -1, 0),
        #(-1, 0x80000000, 1),
        #(0x80000000, 0x7fffffff, 1),
        #(0x7fffffff, 0x80000000, 0),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ige_u(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/d76759e746f3564a03f6106ae19679742f2a1831/i32.wast#L412
pub fn ige_s___i32___test()
{
    [
        #(0, 0, 1),
        #(1, 1, 1),
        #(-1, 1, 0),
        #(0x80000000, 0x80000000, 1),
        #(0x7fffffff, 0x7fffffff, 1),
        #(-1, -1, 1),
        #(1, 0, 1),
        #(0, 1, 0),
        #(0x80000000, 0, 0),
        #(0, 0x80000000, 1),
        #(0x80000000, -1, 0),
        #(-1, 0x80000000, 1),
        #(0x80000000, 0x7fffffff, 0),
        #(0x7fffffff, 0x80000000, 1),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        numerics.ige_s(32, a, b)
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L270
pub fn iextend8_s___i32___test()
{
    [
        #(0, 0),
        #(0x7f, 127),
        #(0x80, -128),
        #(0xff, -1),
        #(0x012345_00, 0),
        #(0xfedcba_80, -{0x80}),
        #(-1, -1),
    ]
    |> list.each(fn (test_case) {
        let #(a, expected) = test_case
        numerics.iextend8_s(32, a)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L278
pub fn iextend16_s___i32___test()
{
    [
        #(0, 0),
        #(0x7fff, 32767),
        #(0x8000, -32768),
        #(0xffff, -1),
        #(0x0123_0000, 0),
        #(0xfedc_8000, -{0x8000}),
        #(-1, -1),
    ]
    |> list.each(fn (test_case) {
        let #(a, expected) = test_case
        numerics.iextend16_s(32, a)
        |> should.be_ok
        |> should.equal(numerics.unsigned(32, expected))
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i64.wast#L287C1-L296C68
pub fn iextend32_s___i64___test()
{
    [
        #(0, 0),
        #(0x7fff, 32767),
        #(0x8000, 32768),
        #(0xffff, 65535),
        #(0x7fffffff, 0x7fffffff),
        #(0x80000000, -{0x80000000}),
        #(0xffffffff, -1),
        #(0x01234567_00000000, 0),
        #(0xfedcba98_80000000, -{0x80000000}),
        #(-1, -1),
    ]
    |> list.each(fn (test_case) {
        let #(a, expected) = test_case
        numerics.iextend32_s(64, a)
        |> should.be_ok
        |> should.equal(numerics.unsigned(64, expected))
    })
}