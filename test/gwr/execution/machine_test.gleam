import gleam/io
import gleam/list
import gleam/string

import gwr/execution/machine
import gwr/execution/runtime
import gwr/execution/stack
import gwr/execution/store

import gleeunit
import gleeunit/should

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

pub fn i32_eqz_test()
{
    [
        #(runtime.Integer32(0), runtime.true_),
        #(runtime.Integer32(1), runtime.false_),
        #(runtime.Integer32(-1), runtime.false_),
        #(runtime.Integer32(65536), runtime.false_)
    ]
    |> list.each(
        fn (test_case)
        {
            let state = create_empty_state()
            let stack = stack.push(to: state.stack, push: [stack.ValueEntry(test_case.0)])
            let state = machine.MachineState(..state, stack: stack)
            let state = machine.i32_eqz(state) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.1))
        }
    )
}

pub fn i32_eq_test()
{
    [
        #([runtime.Integer32(0), runtime.Integer32(0)], runtime.true_),
        #([runtime.Integer32(65536), runtime.Integer32(65536)], runtime.true_),
        #([runtime.Integer32(0), runtime.Integer32(1)], runtime.false_),
        #([runtime.Integer32(0), runtime.Integer32(-1)], runtime.false_),
        #([runtime.Integer32(-65536), runtime.Integer32(-65536)], runtime.true_)
    ]
    |> list.each(
        fn (test_case)
        {
            let state = create_empty_state()
            let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
            let state = machine.MachineState(..state, stack: stack)
            let state = machine.i32_eq(state) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.1))
        }
    )
}

pub fn i32_ne_test()
{
    [
        #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
        #([runtime.Integer32(65536), runtime.Integer32(65536)], runtime.false_),
        #([runtime.Integer32(0), runtime.Integer32(1)], runtime.true_),
        #([runtime.Integer32(0), runtime.Integer32(-1)], runtime.true_),
        #([runtime.Integer32(-65536), runtime.Integer32(-65536)], runtime.false_)
    ]
    |> list.each(
        fn (test_case)
        {
            let state = create_empty_state()
            let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
            let state = machine.MachineState(..state, stack: stack)
            let state = machine.i32_ne(state) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.1))
        }
    )
}

pub fn i32_lt_s_test()
{
    [
        #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
        #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.true_),
        #([runtime.Integer32(0), runtime.Integer32(1)], runtime.true_),
        #([runtime.Integer32(-1), runtime.Integer32(0)], runtime.true_),
        #([runtime.Integer32(-65536), runtime.Integer32(-1024)], runtime.true_)
    ]
    |> list.each(
        fn (test_case)
        {
            let state = create_empty_state()
            let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
            let state = machine.MachineState(..state, stack: stack)
            let state = machine.i32_lt_s(state) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.1))
        }
    )
}

pub fn i32_lt_u_test()
{
    [
        #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
        #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.true_),
        #([runtime.Integer32(65536), runtime.Integer32(1024)], runtime.false_),
        #([runtime.Integer32(0), runtime.Integer32(1)], runtime.true_)
    ]
    |> list.each(
        fn (test_case)
        {
            let state = create_empty_state()
            let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
            let state = machine.MachineState(..state, stack: stack)
            let state = machine.i32_lt_u(state) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.1))
        }
    )
}

pub fn i32_gt_s_test()
{
    [
        #([runtime.Integer32(0x7fffffff), runtime.Integer32(65536)], runtime.true_),
        #([runtime.Integer32(65536), runtime.Integer32(1024)], runtime.true_),
        #([runtime.Integer32(-2), runtime.Integer32(-1024)], runtime.true_),
        #([runtime.Integer32(0x7fffffff * -1), runtime.Integer32(0)], runtime.false_),
        #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
        #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.false_),
        #([runtime.Integer32(0), runtime.Integer32(1)], runtime.false_)
    ]
    |> list.each(
        fn (test_case)
        {
            let state = create_empty_state()
            let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
            let state = machine.MachineState(..state, stack: stack)
            let state = machine.i32_gt_s(state) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.1))
        }
    )
}

pub fn i32_gt_u_test()
{
    [
        #([runtime.Integer32(0xffffffff), runtime.Integer32(0x7fffffff)], runtime.true_),
        #([runtime.Integer32(65536), runtime.Integer32(1024)], runtime.true_),
        #([runtime.Integer32(0), runtime.Integer32(0)], runtime.false_),
        #([runtime.Integer32(1024), runtime.Integer32(65536)], runtime.false_),
        #([runtime.Integer32(0), runtime.Integer32(1)], runtime.false_)
    ]
    |> list.each(
        fn (test_case)
        {
            let state = create_empty_state()
            let stack = stack.push(to: state.stack, push: list.map(test_case.0, fn (x) { stack.ValueEntry(x) }))
            let state = machine.MachineState(..state, stack: stack)
            let state = machine.i32_gt_u(state) |> should.be_ok

            stack.peek(state.stack)
            |> should.be_some
            |> should.equal(stack.ValueEntry(test_case.1))
        }
    )
}

pub fn i32_comparison___signed_overflow_error___test()
{
    let test_functions =
    [
        #("machine.i32_lt_s", machine.i32_lt_s),
        #("machine.i32_gt_s", machine.i32_gt_s),
        #("machine.i32_le_s", machine.i32_le_s)
    ]
    
    let test_values =
    [
        #(runtime.Integer32(0x80000000), runtime.Integer32(0x80000000)),
        #(runtime.Integer32(0), runtime.Integer32(0x80000000)),
        #(runtime.Integer32(0x80000000), runtime.Integer32(0)),
        #(runtime.Integer32(0x80000001 * -1), runtime.Integer32(0)),
        #(runtime.Integer32(0), runtime.Integer32(0x80000001 * -1)),
    ]

    test_functions
    |> list.each(
        fn (function)
        {
            test_values
            |> list.each(
                fn (value)
                {
                    io.println(string.inspect(function.0))
                    io.println(string.inspect(value))

                    let state = create_empty_state()
                    let stack = stack.push(to: state.stack, push: [stack.ValueEntry(value.0), stack.ValueEntry(value.1)])
                    let state = machine.MachineState(..state, stack: stack)

                    function.1(state)
                    |> should.be_error
                    |> should.equal("gwr/execution/machine.i32_comparison: couldn't compare operands: gwr/execution/machine.unwrap_integers: overflow")
                }
            )
        }
    )
}

pub fn i32_comparison___unsigned_overflow_error___test()
{
    let test_functions =
    [
        #("machine.i32_lt_u", machine.i32_lt_u),
        #("machine.i32_gt_u", machine.i32_gt_u),
        #("machine.i32_le_u", machine.i32_le_u)
    ]
    
    let test_values =
    [
        #(runtime.Integer32(0x100000000), runtime.Integer32(0x100000000)),
        #(runtime.Integer32(-1), runtime.Integer32(0x100000000)),
        #(runtime.Integer32(0x100000000), runtime.Integer32(-1)),
        #(runtime.Integer32(0x100000000), runtime.Integer32(0)),
        #(runtime.Integer32(0), runtime.Integer32(0x100000000)),
        #(runtime.Integer32(0), runtime.Integer32(-1)),
        #(runtime.Integer32(-1), runtime.Integer32(0))
    ]

    test_functions
    |> list.each(
        fn (function)
        {
            test_values
            |> list.each(
                fn (value)
                {
                    io.println(string.inspect(function.0))
                    io.println(string.inspect(value))

                    let state = create_empty_state()
                    let stack = stack.push(to: state.stack, push: [stack.ValueEntry(value.0), stack.ValueEntry(value.1)])
                    let state = machine.MachineState(..state, stack: stack)

                    function.1(state)
                    |> should.be_error
                    |> should.equal("gwr/execution/machine.i32_comparison: couldn't compare operands: gwr/execution/machine.unwrap_integers: overflow")
                }
            )
        }
    )
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

pub fn i32_const_test()
{
    let state = machine.i32_const(create_empty_state(), 65536) |> should.be_ok
    
    stack.peek(state.stack)
    |> should.be_some
    |> should.equal(stack.ValueEntry(runtime.Integer32(65536)))
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
