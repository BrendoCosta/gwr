import gleam/list
import gleam/dict

import gwr/execution/evaluator
import gwr/execution/numerics
import gwr/execution/runtime
import gwr/execution/stack
import gwr/execution/trap
import gwr/syntax/types

import gleeunit
import gleeunit/should
import ieee_float

pub fn main()
{
    gleeunit.main()
}

fn create_empty_module_instance() -> runtime.ModuleInstance
{
    runtime.ModuleInstance
    (
        types: [],
        function_addresses: dict.new(),
        table_addresses: [],
        memory_addresses: [],
        global_addresses: [],
        element_addresses: [],
        data_addresses: [],
        exports: [],
    )
}

pub fn evaluate_const___i32___test()
{
    evaluator.evaluate_const(stack.create(), types.Integer32, evaluator.IntegerConstValue(65536))
    |> should.be_ok
    |> should.equal(stack.push(stack.create(), [stack.ValueEntry(runtime.Integer32(65536))]))
}

pub fn evaluate_const___i64___test()
{
    evaluator.evaluate_const(stack.create(), types.Integer64, evaluator.IntegerConstValue(65536))
    |> should.be_ok
    |> should.equal(stack.push(stack.create(), [stack.ValueEntry(runtime.Integer64(65536))]))
}

pub fn evaluate_const___f32___test()
{
    evaluator.evaluate_const(stack.create(), types.Float32, evaluator.FloatConstValue(ieee_float.finite(65536.0)))
    |> should.be_ok
    |> should.equal(stack.push(stack.create(), [stack.ValueEntry(runtime.Float32(runtime.Finite(65536.0)))]))
}

pub fn evaluate_const___f64___test()
{
    evaluator.evaluate_const(stack.create(), types.Float64, evaluator.FloatConstValue(ieee_float.finite(65536.0)))
    |> should.be_ok
    |> should.equal(stack.push(stack.create(), [stack.ValueEntry(runtime.Float64(runtime.Finite(65536.0)))]))
}

pub fn evaluate_const___bad_argument_1___test()
{
    evaluator.evaluate_const(stack.create(), types.Integer32, evaluator.FloatConstValue(ieee_float.finite(65536.0)))
    |> should.be_error
}

pub fn evaluate_const___bad_argument_2___test()
{
    evaluator.evaluate_const(stack.create(), types.Float64, evaluator.IntegerConstValue(65536))
    |> should.be_error
}

pub fn evaluate_local_get_test()
{
    let test_stack = stack.create()
    |> stack.push([
        stack.ActivationEntry(
            runtime.Frame(
                arity: 0,
                framestate: runtime.FrameState(
                    module_instance: create_empty_module_instance(),
                    locals: dict.from_list([
                        #(0, runtime.Integer32(0)),
                        #(1, runtime.Integer32(2)),
                        #(2, runtime.Integer32(4)),
                        #(3, runtime.Integer32(8)),
                        #(4, runtime.Integer32(16)),
                        #(5, runtime.Integer32(32)),
                        #(6, runtime.Integer32(64)),
                    ])
                )
            )
        )
    ])

    test_stack
    |> evaluator.evaluate_local_get(4)
    |> should.be_ok
    |> should.equal(stack.push(test_stack, [stack.ValueEntry(runtime.Integer32(16))]))
}

pub fn evaluate_local_set_test()
{
    stack.create()
    |> stack.push([
        stack.ActivationEntry(
            runtime.Frame(
                arity: 0,
                framestate: runtime.FrameState(
                    module_instance: create_empty_module_instance(),
                    locals: dict.from_list([
                        #(0, runtime.Integer32(0)),
                        #(1, runtime.Integer32(2)),
                        #(2, runtime.Integer32(4)),
                        #(3, runtime.Integer32(8)),
                        #(4, runtime.Integer32(16)),
                        #(5, runtime.Integer32(32)),
                        #(6, runtime.Integer32(64)),
                    ])
                )
            )
        ),
        stack.ValueEntry(runtime.Integer32(128))
    ])
    |> evaluator.evaluate_local_set(5)
    |> should.be_ok
    |> should.equal(
        stack.create()
        |> stack.push([
            stack.ActivationEntry(
                runtime.Frame(
                    arity: 0,
                    framestate: runtime.FrameState(
                        module_instance: create_empty_module_instance(),
                        locals: dict.from_list([
                            #(0, runtime.Integer32(0)),
                            #(1, runtime.Integer32(2)),
                            #(2, runtime.Integer32(4)),
                            #(3, runtime.Integer32(8)),
                            #(4, runtime.Integer32(16)),
                            #(5, runtime.Integer32(128)),
                            #(6, runtime.Integer32(64)),
                        ])
                    )
                )
            )
        ])
    )
}

pub fn evaluate_iadd_test()
{
    stack.create()
    |> stack.push([
        stack.ValueEntry(runtime.Integer32(5)),
        stack.ValueEntry(runtime.Integer32(2))
    ])
    |> evaluator.evaluate_iadd(types.Integer32)
    |> should.be_ok
    |> should.equal(
        stack.create()
        |> stack.push([stack.ValueEntry(runtime.Integer32(7))])
    )
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L37
pub fn evaluate_iadd___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_iadd(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(expected))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L46
pub fn evaluate_isub___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_isub(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(expected))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L54
pub fn evaluate_imul___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_imul(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(expected))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L85
pub fn evaluate_idiv_u___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_idiv_u(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(expected))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L85
pub fn evaluate_idiv_u___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
        #(0x80000000, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_idiv_u(types.Integer32)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L64
pub fn evaluate_idiv_s___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_idiv_s(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(numerics.unsigned(32, expected)))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L64
pub fn evaluate_idiv_s___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
        #(0x80000000, -1, trap.Overflow),
        #(0x80000000, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_idiv_s(types.Integer32)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L125
pub fn evaluate_irem_u___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_irem_u(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(numerics.unsigned(32, expected)))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L123
pub fn evaluate_irem_u___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_irem_u(types.Integer32)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L104
pub fn evaluate_irem_s___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_irem_s(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(numerics.unsigned(32, expected)))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L102
pub fn evaluate_irem_s___i32_trap__test()
{
    [
        #(1, 0, trap.DivisionByZero),
        #(0, 0, trap.DivisionByZero),
    ]
    |> list.each(fn (test_case) {
        let #(a, b, expected) = test_case
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_irem_s(types.Integer32)
        |> should.be_error
        |> trap.kind
        |> should.equal(expected)
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L140
pub fn evaluate_iand___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_iand(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(numerics.unsigned(32, expected)))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L149C1-L156C99
pub fn evaluate_ior___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_ior(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(numerics.unsigned(32, expected)))])
        )
    })
}

/// https://github.com/WebAssembly/testsuite/blob/5504e41c6facedcbba1ff52a35b4c9ea99e6877d/i32.wast#L158
pub fn evaluate_ixor___i32___test()
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
        stack.create()
        |> stack.push([
            stack.ValueEntry(runtime.Integer32(a)),
            stack.ValueEntry(runtime.Integer32(b))
        ])
        |> evaluator.evaluate_ixor(types.Integer32)
        |> should.be_ok
        |> should.equal(
            stack.create()
            |> stack.push([stack.ValueEntry(runtime.Integer32(numerics.unsigned(32, expected)))])
        )
    })
}