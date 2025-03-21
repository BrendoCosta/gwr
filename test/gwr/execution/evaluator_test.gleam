import gleam/dict
import gleam/list
import gleam/option
import gleam/pair

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

// A function call return should be flagged with an "Return" jump
pub fn evaluate_return___return_flag___test()
{
    stack.create()
    |> stack.push([
        stack.ActivationEntry(
            runtime.Frame(
                arity: 0,
                framestate: runtime.FrameState(
                    module_instance: create_empty_module_instance(),
                    locals: dict.new()
                )
            )
        ),
        stack.LabelEntry(
            runtime.Label(arity: 0, continuation: [])
        )
    ])
    |> evaluator.evaluate_return()
    |> should.be_ok
    |> pair.second
    |> should.be_some
    |> should.equal(evaluator.Return)
}

pub fn evaluate_return_test()
{
    stack.create()
    |> stack.push([
        // Function Call #1 should return 0 values from Function Call #2
        stack.ActivationEntry(
            runtime.Frame(
                arity: 0,
                framestate: runtime.FrameState(
                    module_instance: create_empty_module_instance(),
                    locals: dict.new()
                )
            )
        ),
        stack.LabelEntry(
            runtime.Label(arity: 0, continuation: [])
        ),
        // Function Call #2 should return 2 values from Function Call #3
        stack.ActivationEntry(
            runtime.Frame(
                arity: 2,
                framestate: runtime.FrameState(
                    module_instance: create_empty_module_instance(),
                    locals: dict.new()
                )
            )
        ),
        stack.LabelEntry(
            runtime.Label(arity: 2, continuation: [])
        ),
        // Function Call #3 should return 3 values
        stack.ActivationEntry(
            runtime.Frame(
                arity: 3,
                framestate: runtime.FrameState(
                    module_instance: create_empty_module_instance(),
                    locals: dict.new()
                )
            )
        ),
        stack.LabelEntry(
            runtime.Label(arity: 3, continuation: [])
        ),
        stack.ValueEntry(runtime.Integer32(128)),
        stack.ValueEntry(runtime.Integer32(256)),
        stack.ValueEntry(runtime.Integer32(512))
    ])
    |> evaluator.evaluate_return() // Return from Function Call #3
    |> should.be_ok
    |> pair.first
    |> evaluator.evaluate_return() // Return from Function Call #2
    |> should.be_ok
    |> should.equal(
        #(
            stack.create()
            |> stack.push([
                // Function Call #1
                stack.ActivationEntry(
                    runtime.Frame(
                        arity: 0,
                        framestate: runtime.FrameState(
                            module_instance: create_empty_module_instance(),
                            locals: dict.new()
                        )
                    )
                ),
                stack.LabelEntry(
                    runtime.Label(arity: 0, continuation: [])
                ),
                // Values returned from Function Call #2
                stack.ValueEntry(runtime.Integer32(256)),
                stack.ValueEntry(runtime.Integer32(512))
            ]),
            option.Some(evaluator.Return)
        )
    )
}