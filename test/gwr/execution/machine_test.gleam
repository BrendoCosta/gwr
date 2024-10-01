import gleam/io
import gleam/list
import gleam/string

import gwr/execution/machine
import gwr/execution/runtime
import gwr/execution/stack
import gwr/execution/store
import gwr/syntax/types

import gleeunit
import gleeunit/should
import ieee_float

pub fn main()
{
    gleeunit.main()
}

fn create_empty_state() -> machine.MachineState
{
    machine.MachineState
    (
        configuration: machine.Configuration
        (
            store: store.Store
            (
                datas: [],
                elements: [],
                functions: [],
                globals: [],
                memories: [],
                tables: []
            ),
            thread: machine.Thread
            (
                framestate: stack.FrameState
                (
                    locals: [],
                    module_instance: runtime.ModuleInstance
                    (
                        data_addresses: [],
                        element_addresses: [],
                        exports: [],
                        function_addresses: [],
                        global_addresses: [],
                        memory_addresses: [],
                        table_addresses: [],
                        types : []
                    )
                ),
                instructions: []
            )
        ),
        stack: stack.create()
    )
}

pub fn integer_const_test()
{
    [
        #(
            types.Integer32,
            0xffffffff,
            runtime.Integer32(0xffffffff)
        ),
        #(
            types.Integer64,
            0xffffffffffffffff,
            runtime.Integer64(0xffffffffffffffff)
        ),
    ]
    |> list.each(
        fn (test_case)
        {
            let state = machine.integer_const(create_empty_state(), test_case.0, test_case.1) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.2))
        }
    )
}

pub fn float_const_test()
{
    [
        #(
            types.Float32,
            ieee_float.finite(65536.0),
            runtime.Float32(runtime.Finite(65536.0))
        ),
        #(
            types.Float64,
            ieee_float.finite(65536.0),
            runtime.Float64(runtime.Finite(65536.0))
        ),
    ]
    |> list.each(
        fn (test_case)
        {
            let state = machine.float_const(create_empty_state(), test_case.0, test_case.1) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.2))
        }
    )
}

pub fn integer_eqz_test()
{
    [
        #(
            types.Integer32,
            [
                #(runtime.Integer32(0), runtime.true_),
                #(runtime.Integer32(1), runtime.false_),
                #(runtime.Integer32(-1), runtime.false_),
                #(runtime.Integer32(65536), runtime.false_)
            ]
        ),
        #(
            types.Integer64,
            [
                #(runtime.Integer64(0), runtime.true_),
                #(runtime.Integer64(1), runtime.false_),
                #(runtime.Integer64(-1), runtime.false_),
                #(runtime.Integer64(65536), runtime.false_)
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: [stack.ValueEntry(test_case.0)])
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_eqz(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_eq_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.true_),
                #([runtime.Integer32(65536), runtime.Integer32(65536)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(1)], runtime.false_),
                #([runtime.Integer32(0), runtime.Integer32(-1)], runtime.false_),
                #([runtime.Integer32(-65536), runtime.Integer32(-65536)], runtime.true_)
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.true_),
                #([runtime.Integer64(65536), runtime.Integer64(65536)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(1)], runtime.false_),
                #([runtime.Integer64(0), runtime.Integer64(-1)], runtime.false_),
                #([runtime.Integer64(-65536), runtime.Integer64(-65536)], runtime.true_)
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_eq(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_ne_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
                #([runtime.Integer32(65536), runtime.Integer32(65536)], runtime.false_),
                #([runtime.Integer32(0), runtime.Integer32(1)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(-1)], runtime.true_),
                #([runtime.Integer32(-65536), runtime.Integer32(-65536)], runtime.false_)
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.false_),
                #([runtime.Integer64(65536), runtime.Integer64(65536)], runtime.false_),
                #([runtime.Integer64(0), runtime.Integer64(1)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(-1)], runtime.true_),
                #([runtime.Integer64(-65536), runtime.Integer64(-65536)], runtime.false_)
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_ne(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_lt_s_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
                #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(1)], runtime.true_),
                #([runtime.Integer32(-1), runtime.Integer32(0)], runtime.true_),
                #([runtime.Integer32(-65536), runtime.Integer32(-1024)], runtime.true_)
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.false_),
                #([runtime.Integer64(1024), runtime.Integer64(65536)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(1)], runtime.true_),
                #([runtime.Integer64(-1), runtime.Integer64(0)], runtime.true_),
                #([runtime.Integer64(-65536), runtime.Integer64(-1024)], runtime.true_)
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_lt_s(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_lt_u_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
                #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.true_),
                #([runtime.Integer32(65536), runtime.Integer32(1024)], runtime.false_),
                #([runtime.Integer32(0), runtime.Integer32(1)], runtime.true_)
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.false_),
                #([runtime.Integer64(1024), runtime.Integer64(65536)], runtime.true_),
                #([runtime.Integer64(65536), runtime.Integer64(1024)], runtime.false_),
                #([runtime.Integer64(0), runtime.Integer64(1)], runtime.true_)
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_lt_u(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_gt_s_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0x7fffffff), runtime.Integer32(65536)], runtime.true_),
                #([runtime.Integer32(65536), runtime.Integer32(1024)], runtime.true_),
                #([runtime.Integer32(-2), runtime.Integer32(-1024)], runtime.true_),
                #([runtime.Integer32(0x7fffffff * -1), runtime.Integer32(0)], runtime.false_),
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
                #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.false_),
                #([runtime.Integer32(0), runtime.Integer32(1)], runtime.false_)
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0x7fffffff), runtime.Integer64(65536)], runtime.true_),
                #([runtime.Integer64(65536), runtime.Integer64(1024)], runtime.true_),
                #([runtime.Integer64(-2), runtime.Integer64(-1024)], runtime.true_),
                #([runtime.Integer64(0x7fffffff * -1), runtime.Integer64(0)], runtime.false_),
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.false_),
                #([runtime.Integer64(1024), runtime.Integer64(65536)], runtime.false_),
                #([runtime.Integer64(0), runtime.Integer64(1)], runtime.false_)
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_gt_s(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_gt_u_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0xffffffff), runtime.Integer32(0x7fffffff)], runtime.true_),
                #([runtime.Integer32(65536), runtime.Integer32(1024)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
                #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.false_),
                #([runtime.Integer32(0), runtime.Integer32(1)], runtime.false_)
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0xffffffff), runtime.Integer64(0x7fffffff)], runtime.true_),
                #([runtime.Integer64(65536), runtime.Integer64(1024)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.false_),
                #([runtime.Integer64(1024), runtime.Integer64(65536)], runtime.false_),
                #([runtime.Integer64(0), runtime.Integer64(1)], runtime.false_)
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_gt_u(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_le_s_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0x7fffffff), runtime.Integer32(0x7fffffff)], runtime.true_),
                #([runtime.Integer32(65535), runtime.Integer32(65536)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.true_),
                #([runtime.Integer32(-65536), runtime.Integer32(-65536)], runtime.true_),
                #([runtime.Integer32(-65536), runtime.Integer32(-65535)], runtime.true_),
                #([runtime.Integer32(-65535), runtime.Integer32(-65536)], runtime.false_),
                #([runtime.Integer32(65536), runtime.Integer32(65535)], runtime.false_),
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0x7fffffff), runtime.Integer64(0x7fffffff)], runtime.true_),
                #([runtime.Integer64(65535), runtime.Integer64(65536)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.true_),
                #([runtime.Integer64(-65536), runtime.Integer64(-65536)], runtime.true_),
                #([runtime.Integer64(-65536), runtime.Integer64(-65535)], runtime.true_),
                #([runtime.Integer64(-65535), runtime.Integer64(-65536)], runtime.false_),
                #([runtime.Integer64(65536), runtime.Integer64(65535)], runtime.false_),
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_le_s(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_le_u_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0xffffffff), runtime.Integer32(0xffffffff)], runtime.true_),
                #([runtime.Integer32(0xfffffffe), runtime.Integer32(0xffffffff)], runtime.true_),
                #([runtime.Integer32(65535), runtime.Integer32(65536)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.true_)
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0xffffffff), runtime.Integer64(0xffffffff)], runtime.true_),
                #([runtime.Integer64(0xfffffffe), runtime.Integer64(0xffffffff)], runtime.true_),
                #([runtime.Integer64(65535), runtime.Integer64(65536)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.true_)
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_le_u(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_ge_s_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0x7fffffff), runtime.Integer32(0x7fffffff)], runtime.true_),
                #([runtime.Integer32(65536), runtime.Integer32(65535)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.true_),
                #([runtime.Integer32(-65535), runtime.Integer32(-65536)], runtime.true_),
                #([runtime.Integer32(-65536), runtime.Integer32(-65536)], runtime.true_),
                #([runtime.Integer32(65535), runtime.Integer32(65536)], runtime.false_),
                #([runtime.Integer32(-65536), runtime.Integer32(-65535)], runtime.false_),
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0x7fffffff), runtime.Integer64(0x7fffffff)], runtime.true_),
                #([runtime.Integer64(65536), runtime.Integer64(65535)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.true_),
                #([runtime.Integer64(-65535), runtime.Integer64(-65536)], runtime.true_),
                #([runtime.Integer64(-65536), runtime.Integer64(-65536)], runtime.true_),
                #([runtime.Integer64(65535), runtime.Integer64(65536)], runtime.false_),
                #([runtime.Integer64(-65536), runtime.Integer64(-65535)], runtime.false_),
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_ge_s(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_ge_u_test()
{
    [
        #(
            types.Integer32,
            [
                #([runtime.Integer32(0xffffffff), runtime.Integer32(0xffffffff)], runtime.true_),
                #([runtime.Integer32(0xffffffff), runtime.Integer32(0xfffffffe)], runtime.true_),
                #([runtime.Integer32(65536), runtime.Integer32(65536)], runtime.true_),
                #([runtime.Integer32(65536), runtime.Integer32(65535)], runtime.true_),
                #([runtime.Integer32(0), runtime.Integer32(0)], runtime.true_),
                #([runtime.Integer32(65535), runtime.Integer32(65536)], runtime.false_),
                #([runtime.Integer32(0xfffffffe), runtime.Integer32(0xffffffff)], runtime.false_),
            ]
        ),
        #(
            types.Integer64,
            [
                #([runtime.Integer64(0xffffffff), runtime.Integer64(0xffffffff)], runtime.true_),
                #([runtime.Integer64(0xffffffff), runtime.Integer64(0xfffffffe)], runtime.true_),
                #([runtime.Integer64(65536), runtime.Integer64(65536)], runtime.true_),
                #([runtime.Integer64(65536), runtime.Integer64(65535)], runtime.true_),
                #([runtime.Integer64(0), runtime.Integer64(0)], runtime.true_),
                #([runtime.Integer64(65535), runtime.Integer64(65536)], runtime.false_),
                #([runtime.Integer64(0xfffffffe), runtime.Integer64(0xffffffff)], runtime.false_),
            ]
        ),
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.integer_ge_u(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn integer_comparison___signed_overflow_error___test()
{
    let test_functions =
    [
        #("machine.integer_lt_s", machine.integer_lt_s),
        #("machine.integer_gt_s", machine.integer_gt_s),
        #("machine.integer_le_s", machine.integer_le_s),
        #("machine.integer_ge_s", machine.integer_ge_s)
    ]
    
    let test_values =
    [
        #(
            types.Integer32,
            [
                #(runtime.Integer32(0x80000000), runtime.Integer32(0x80000000)),
                #(runtime.Integer32(0), runtime.Integer32(0x80000000)),
                #(runtime.Integer32(0x80000000), runtime.Integer32(0)),
                #(runtime.Integer32(0x80000001 * -1), runtime.Integer32(0)),
                #(runtime.Integer32(0), runtime.Integer32(0x80000001 * -1)),
            ]
        ),
        #(
            types.Integer64,
            [
                #(runtime.Integer64(0x8000000000000000), runtime.Integer64(0x8000000000000000)),
                #(runtime.Integer64(0), runtime.Integer64(0x8000000000000000)),
                #(runtime.Integer64(0x8000000000000000), runtime.Integer64(0)),
                #(runtime.Integer64(0x8000000000000001 * -1), runtime.Integer64(0)),
                #(runtime.Integer64(0), runtime.Integer64(0x8000000000000001 * -1)),
            ]
        )
    ]

    list.each(test_functions, fn (function) {
        list.each(test_values, fn (tst_val) {
            list.each(tst_val.1, fn (val) {
                io.println(string.inspect(function.0))
                io.println(string.inspect(tst_val.0))
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: [stack.ValueEntry(val.0), stack.ValueEntry(val.1)])
                let state = machine.MachineState(..state, stack: stack)

                function.1(state, tst_val.0)
                |> should.be_error
                |> should.equal("gwr/execution/machine.signed_integer_overflow_check: signed integer overflow")
            })
        })
    })
}

pub fn integer_comparison___unsigned_overflow_error___test()
{
    let test_functions =
    [
        #("machine.integer_lt_u", machine.integer_lt_u),
        #("machine.integer_gt_u", machine.integer_gt_u),
        #("machine.integer_le_u", machine.integer_le_u),
        #("machine.integer_ge_u", machine.integer_ge_u)
    ]
    
    let test_values =
    [
        #(
            types.Integer32,
            [
                #(runtime.Integer32(0x100000000), runtime.Integer32(0x100000000)),
                #(runtime.Integer32(-1), runtime.Integer32(0x100000000)),
                #(runtime.Integer32(0x100000000), runtime.Integer32(-1)),
                #(runtime.Integer32(0x100000000), runtime.Integer32(0)),
                #(runtime.Integer32(0), runtime.Integer32(0x100000000)),
                #(runtime.Integer32(0), runtime.Integer32(-1)),
                #(runtime.Integer32(-1), runtime.Integer32(0))
            ]
        ),
        #(
            types.Integer64,
            [
                #(runtime.Integer64(0x10000000000000000), runtime.Integer64(0x10000000000000000)),
                #(runtime.Integer64(-1), runtime.Integer64(0x10000000000000000)),
                #(runtime.Integer64(0x10000000000000000), runtime.Integer64(-1)),
                #(runtime.Integer64(0x10000000000000000), runtime.Integer64(0)),
                #(runtime.Integer64(0), runtime.Integer64(0x10000000000000000)),
                #(runtime.Integer64(0), runtime.Integer64(-1)),
                #(runtime.Integer64(-1), runtime.Integer64(0))
            ]
        )
    ]

    list.each(test_functions, fn (function) {
        list.each(test_values, fn (tst_val) {
            list.each(tst_val.1, fn (val) {
                io.println(string.inspect(function.0))
                io.println(string.inspect(tst_val.0))
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: [stack.ValueEntry(val.0), stack.ValueEntry(val.1)])
                let state = machine.MachineState(..state, stack: stack)

                function.1(state, tst_val.0)
                |> should.be_error
                |> should.equal("gwr/execution/machine.unsigned_integer_overflow_check: unsigned integer overflow")
            })
        })
    })
}

pub fn float_eq_test()
{
    [
        #(
            types.Float32,
            [
                #([runtime.Float32(runtime.Finite(0.0)),        runtime.Float32(runtime.Finite(0.0))],      runtime.true_),
                #([runtime.Float32(runtime.Finite(65536.0)),    runtime.Float32(runtime.Finite(65536.0))],  runtime.true_),
                #([runtime.Float32(runtime.Finite(-65536.0)),   runtime.Float32(runtime.Finite(-65536.0))], runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),        runtime.Float32(runtime.Finite(1.0))],      runtime.false_),
                #([runtime.Float32(runtime.Finite(0.0)),        runtime.Float32(runtime.Finite(-1.0))],     runtime.false_)
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.float_eq(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn float_ne_test()
{
    [
        #(
            types.Float32,
            [
                #([runtime.Float32(runtime.Infinite(runtime.Positive)), runtime.Float32(runtime.Infinite(runtime.Negative))], runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(1.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(-1.0))],               runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(0.0))],                runtime.false_),
                #([runtime.Float32(runtime.Finite(65536.0)),            runtime.Float32(runtime.Finite(65536.0))],            runtime.false_),
                #([runtime.Float32(runtime.Finite(-65536.0)),           runtime.Float32(runtime.Finite(-65536.0))],           runtime.false_)
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.float_ne(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn float_lt_test()
{
    [
        #(
            types.Float32,
            [
                #([runtime.Float32(runtime.Infinite(runtime.Negative)), runtime.Float32(runtime.Infinite(runtime.Positive))], runtime.true_),
                #([runtime.Float32(runtime.Finite(65536.0)),            runtime.Float32(runtime.Finite(65537.0))],            runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(1.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(-1.0)),               runtime.Float32(runtime.Finite(0.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(65537.0)),            runtime.Float32(runtime.Finite(65536.0))],            runtime.false_),
                #([runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.Finite(0.0))],                runtime.false_),
                #([runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.Finite(-1.0))],               runtime.false_),
                #([runtime.Float32(runtime.Infinite(runtime.Positive)), runtime.Float32(runtime.Infinite(runtime.Negative))], runtime.false_),
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.float_lt(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn float_gt_test()
{
    [
        #(
            types.Float32,
            [
                #([runtime.Float32(runtime.Infinite(runtime.Positive)), runtime.Float32(runtime.Infinite(runtime.Negative))], runtime.true_),
                #([runtime.Float32(runtime.Finite(65537.0)),            runtime.Float32(runtime.Finite(65536.0))],            runtime.true_),
                #([runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.Finite(0.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(-1.0))],               runtime.true_),
                #([runtime.Float32(runtime.Finite(65536.0)),            runtime.Float32(runtime.Finite(65537.0))],            runtime.false_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(1.0))],                runtime.false_),
                #([runtime.Float32(runtime.Finite(-1.0)),               runtime.Float32(runtime.Finite(1.0))],                runtime.false_),
                #([runtime.Float32(runtime.Infinite(runtime.Negative)), runtime.Float32(runtime.Infinite(runtime.Positive))], runtime.false_)
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.float_gt(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn float_le_test()
{
    [
        #(
            types.Float32,
            [
                #([runtime.Float32(runtime.Infinite(runtime.Negative)), runtime.Float32(runtime.Infinite(runtime.Negative))], runtime.true_),
                #([runtime.Float32(runtime.Infinite(runtime.Negative)), runtime.Float32(runtime.Infinite(runtime.Positive))], runtime.true_),
                #([runtime.Float32(runtime.Finite(65536.0)),            runtime.Float32(runtime.Finite(65537.0))],            runtime.true_),
                #([runtime.Float32(runtime.Finite(65536.0)),            runtime.Float32(runtime.Finite(65536.0))],            runtime.true_),
                #([runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.Finite(1.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(1.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(-1.0)),               runtime.Float32(runtime.Finite(0.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(-1.0)),               runtime.Float32(runtime.Finite(-1.0))],               runtime.true_),
                #([runtime.Float32(runtime.Finite(-65536.0)),           runtime.Float32(runtime.Finite(-65536.0))],           runtime.true_),
                #([runtime.Float32(runtime.Finite(-65537.0)),           runtime.Float32(runtime.Finite(-65536.0))],           runtime.true_),
                #([runtime.Float32(runtime.Infinite(runtime.Positive)), runtime.Float32(runtime.Infinite(runtime.Negative))], runtime.false_),
                #([runtime.Float32(runtime.Finite(65537.0)),            runtime.Float32(runtime.Finite(65536.0))],            runtime.false_),
                #([runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.Finite(0.0))],                runtime.false_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(-1.0))],               runtime.false_),
                #([runtime.Float32(runtime.Finite(-65536.0)),           runtime.Float32(runtime.Finite(-65537.0))],           runtime.false_),
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.float_le(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn float_ge_test()
{
    [
        #(
            types.Float32,
            [
                #([runtime.Float32(runtime.Infinite(runtime.Negative)), runtime.Float32(runtime.Infinite(runtime.Negative))], runtime.true_),
                #([runtime.Float32(runtime.Infinite(runtime.Positive)), runtime.Float32(runtime.Infinite(runtime.Negative))], runtime.true_),
                #([runtime.Float32(runtime.Finite(65537.0)),            runtime.Float32(runtime.Finite(65536.0))],            runtime.true_),
                #([runtime.Float32(runtime.Finite(65536.0)),            runtime.Float32(runtime.Finite(65536.0))],            runtime.true_),
                #([runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.Finite(1.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.Finite(0.0))],                runtime.true_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(-1.0))],               runtime.true_),
                #([runtime.Float32(runtime.Finite(-1.0)),               runtime.Float32(runtime.Finite(-1.0))],               runtime.true_),
                #([runtime.Float32(runtime.Finite(-65536.0)),           runtime.Float32(runtime.Finite(-65536.0))],           runtime.true_),
                #([runtime.Float32(runtime.Finite(-65536.0)),           runtime.Float32(runtime.Finite(-65537.0))],           runtime.true_),
                #([runtime.Float32(runtime.Infinite(runtime.Negative)), runtime.Float32(runtime.Infinite(runtime.Positive))], runtime.false_),
                #([runtime.Float32(runtime.Finite(65536.0)),            runtime.Float32(runtime.Finite(65537.0))],            runtime.false_),
                #([runtime.Float32(runtime.Finite(0.0)),                runtime.Float32(runtime.Finite(1.0))],                runtime.false_),
                #([runtime.Float32(runtime.Finite(-1.0)),               runtime.Float32(runtime.Finite(0.0))],                runtime.false_),
                #([runtime.Float32(runtime.Finite(-65537.0)),           runtime.Float32(runtime.Finite(-65536.0))],           runtime.false_),
            ]
        )
    ]
    |> list.each(
        fn (integer_type)
        {
            list.each(integer_type.1, fn (test_case) {
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = machine.float_ge(state, integer_type.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(test_case.1))
            })
        }
    )
}

pub fn float_comparison___nan___test()
{
    let test_functions =
    [
        #("machine.float_lt", machine.float_lt),
        #("machine.float_gt", machine.float_gt),
        #("machine.float_le", machine.float_le),
        #("machine.float_ge", machine.float_ge)
    ]
    
    let test_values =
    [
        #(
            types.Float32,
            [
                [runtime.Float32(runtime.NaN),                        runtime.Float32(runtime.NaN)],
                [runtime.Float32(runtime.Finite(1.0)),                runtime.Float32(runtime.NaN)],
                [runtime.Float32(runtime.NaN),                        runtime.Float32(runtime.Finite(1.0))],
                [runtime.Float32(runtime.Infinite(runtime.Positive)), runtime.Float32(runtime.NaN)],
                [runtime.Float32(runtime.NaN),                        runtime.Float32(runtime.Infinite(runtime.Positive))],
                [runtime.Float32(runtime.Infinite(runtime.Negative)), runtime.Float32(runtime.NaN)],
                [runtime.Float32(runtime.NaN),                        runtime.Float32(runtime.Infinite(runtime.Negative))],
            ]
        )
    ]

    list.each(test_functions, fn (function) {
        list.each(test_values, fn (tst_val) {
            list.each(tst_val.1, fn (val) {
                io.println(string.inspect(function.0))
                io.println(string.inspect(tst_val.0))
                let state = create_empty_state()
                let stack = stack.push(to: state.stack, push: list.map(val, fn (x) { stack.ValueEntry(x) }))
                let state = machine.MachineState(..state, stack: stack)
                let state = function.1(state, tst_val.0) |> should.be_ok

                stack.peek(state.stack)
                |> should.be_some
                |> should.equal(stack.ValueEntry(runtime.false_))
            })
        })
    })
}

pub fn i32_add_test()
{
    let state = create_empty_state()
    let stack = stack.push(to: state.stack, push: [stack.ValueEntry(runtime.Integer32(4))])
                |> stack.push([stack.ValueEntry(runtime.Integer32(6))])
    let state = machine.MachineState(..state, stack: stack)
    let state = machine.i32_add(state) |> should.be_ok
    
    stack.peek(state.stack)
    |> should.be_some
    |> should.equal(stack.ValueEntry(runtime.Integer32(10)))
}

pub fn local_get_test()
{
    let state = create_empty_state()
    let state = machine.MachineState
    (
        ..create_empty_state(),
        configuration: machine.Configuration
        (
            ..state.configuration,
            thread: machine.Thread
            (
                ..state.configuration.thread,
                framestate: stack.FrameState
                (
                    ..state.configuration.thread.framestate,
                    locals: [runtime.Integer32(2), runtime.Integer32(256), runtime.Integer32(512)] // 0, 1, 2
                )
            )
        )
    )

    let state = machine.local_get(state, 1) |> should.be_ok
    
    stack.peek(state.stack)
    |> should.be_some
    |> should.equal(stack.ValueEntry(runtime.Integer32(256)))
}
