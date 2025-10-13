import gleam/dict
import gleam/option
import gleam/pair

import gwr/exec
import gwr/exec/stack
import gwr/spec

import gleeunit
import gleeunit/should
import ieee_float

pub fn main() {
  gleeunit.main()
}

fn create_empty_module_instance() -> spec.ModuleInstance {
  spec.ModuleInstance(
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

pub fn evaluate_const___i32___test() {
  exec.evaluate_const(
    stack.create(),
    spec.Integer32,
    exec.IntegerConstValue(65_536),
  )
  |> should.be_ok
  |> should.equal(
    stack.push(stack.create(), [stack.ValueEntry(spec.Integer32Value(65_536))]),
  )
}

pub fn evaluate_const___i64___test() {
  exec.evaluate_const(
    stack.create(),
    spec.Integer64,
    exec.IntegerConstValue(65_536),
  )
  |> should.be_ok
  |> should.equal(
    stack.push(stack.create(), [stack.ValueEntry(spec.Integer64Value(65_536))]),
  )
}

pub fn evaluate_const___f32___test() {
  exec.evaluate_const(
    stack.create(),
    spec.Float32,
    exec.FloatConstValue(ieee_float.finite(65_536.0)),
  )
  |> should.be_ok
  |> should.equal(
    stack.push(stack.create(), [
      stack.ValueEntry(spec.Float32Value(spec.Finite(65_536.0))),
    ]),
  )
}

pub fn evaluate_const___f64___test() {
  exec.evaluate_const(
    stack.create(),
    spec.Float64,
    exec.FloatConstValue(ieee_float.finite(65_536.0)),
  )
  |> should.be_ok
  |> should.equal(
    stack.push(stack.create(), [
      stack.ValueEntry(spec.Float64Value(spec.Finite(65_536.0))),
    ]),
  )
}

pub fn evaluate_const___bad_argument_1___test() {
  exec.evaluate_const(
    stack.create(),
    spec.Integer32,
    exec.FloatConstValue(ieee_float.finite(65_536.0)),
  )
  |> should.be_error
}

pub fn evaluate_const___bad_argument_2___test() {
  exec.evaluate_const(
    stack.create(),
    spec.Float64,
    exec.IntegerConstValue(65_536),
  )
  |> should.be_error
}

pub fn evaluate_local_get_test() {
  let test_stack =
    stack.create()
    |> stack.push([
      stack.ActivationEntry(spec.Frame(
        arity: 0,
        framestate: spec.FrameState(
          module_instance: create_empty_module_instance(),
          locals: dict.from_list([
            #(0, spec.Integer32Value(0)),
            #(1, spec.Integer32Value(2)),
            #(2, spec.Integer32Value(4)),
            #(3, spec.Integer32Value(8)),
            #(4, spec.Integer32Value(16)),
            #(5, spec.Integer32Value(32)),
            #(6, spec.Integer32Value(64)),
          ]),
        ),
      )),
    ])

  test_stack
  |> exec.evaluate_local_get(4)
  |> should.be_ok
  |> should.equal(
    stack.push(test_stack, [stack.ValueEntry(spec.Integer32Value(16))]),
  )
}

pub fn evaluate_local_set_test() {
  stack.create()
  |> stack.push([
    stack.ActivationEntry(spec.Frame(
      arity: 0,
      framestate: spec.FrameState(
        module_instance: create_empty_module_instance(),
        locals: dict.from_list([
          #(0, spec.Integer32Value(0)),
          #(1, spec.Integer32Value(2)),
          #(2, spec.Integer32Value(4)),
          #(3, spec.Integer32Value(8)),
          #(4, spec.Integer32Value(16)),
          #(5, spec.Integer32Value(32)),
          #(6, spec.Integer32Value(64)),
        ]),
      ),
    )),
    stack.ValueEntry(spec.Integer32Value(128)),
  ])
  |> exec.evaluate_local_set(5)
  |> should.be_ok
  |> should.equal(
    stack.create()
    |> stack.push([
      stack.ActivationEntry(spec.Frame(
        arity: 0,
        framestate: spec.FrameState(
          module_instance: create_empty_module_instance(),
          locals: dict.from_list([
            #(0, spec.Integer32Value(0)),
            #(1, spec.Integer32Value(2)),
            #(2, spec.Integer32Value(4)),
            #(3, spec.Integer32Value(8)),
            #(4, spec.Integer32Value(16)),
            #(5, spec.Integer32Value(128)),
            #(6, spec.Integer32Value(64)),
          ]),
        ),
      )),
    ]),
  )
}

pub fn evaluate_local_tee_test() {
  stack.create()
  |> stack.push([
    stack.ActivationEntry(spec.Frame(
      arity: 0,
      framestate: spec.FrameState(
        module_instance: create_empty_module_instance(),
        locals: dict.from_list([
          #(0, spec.Integer32Value(0)),
          #(1, spec.Integer32Value(2)),
          #(2, spec.Integer32Value(4)),
          #(3, spec.Integer32Value(8)),
          #(4, spec.Integer32Value(16)),
          #(5, spec.Integer32Value(32)),
          #(6, spec.Integer32Value(64)),
        ]),
      ),
    )),
    stack.ValueEntry(spec.Integer32Value(128)),
  ])
  |> exec.evaluate_local_tee(5)
  |> should.be_ok
  |> should.equal(
    stack.create()
    |> stack.push([
      stack.ActivationEntry(spec.Frame(
        arity: 0,
        framestate: spec.FrameState(
          module_instance: create_empty_module_instance(),
          locals: dict.from_list([
            #(0, spec.Integer32Value(0)),
            #(1, spec.Integer32Value(2)),
            #(2, spec.Integer32Value(4)),
            #(3, spec.Integer32Value(8)),
            #(4, spec.Integer32Value(16)),
            #(5, spec.Integer32Value(128)),
            #(6, spec.Integer32Value(64)),
          ]),
        ),
      )),
      stack.ValueEntry(spec.Integer32Value(128)),
    ]),
  )
}

// A function call return should be flagged with an "Return" jump
pub fn evaluate_return___return_flag___test() {
  stack.create()
  |> stack.push([
    stack.ActivationEntry(spec.Frame(
      arity: 0,
      framestate: spec.FrameState(
        module_instance: create_empty_module_instance(),
        locals: dict.new(),
      ),
    )),
    stack.LabelEntry(spec.Label(arity: 0, continuation: [])),
  ])
  |> exec.evaluate_return()
  |> should.be_ok
  |> pair.second
  |> should.be_some
  |> should.equal(exec.Return)
}

pub fn evaluate_return_test() {
  stack.create()
  |> stack.push([
    // Function Call #1 should return 0 values from Function Call #2
    stack.ActivationEntry(spec.Frame(
      arity: 0,
      framestate: spec.FrameState(
        module_instance: create_empty_module_instance(),
        locals: dict.new(),
      ),
    )),
    stack.LabelEntry(spec.Label(arity: 0, continuation: [])),
    // Function Call #2 should return 2 values from Function Call #3
    stack.ActivationEntry(spec.Frame(
      arity: 2,
      framestate: spec.FrameState(
        module_instance: create_empty_module_instance(),
        locals: dict.new(),
      ),
    )),
    stack.LabelEntry(spec.Label(arity: 2, continuation: [])),
    // Function Call #3 should return 3 values
    stack.ActivationEntry(spec.Frame(
      arity: 3,
      framestate: spec.FrameState(
        module_instance: create_empty_module_instance(),
        locals: dict.new(),
      ),
    )),
    stack.LabelEntry(spec.Label(arity: 3, continuation: [])),
    stack.ValueEntry(spec.Integer32Value(128)),
    stack.ValueEntry(spec.Integer32Value(256)),
    stack.ValueEntry(spec.Integer32Value(512)),
  ])
  |> exec.evaluate_return()
  // Return from Function Call #3
  |> should.be_ok
  |> pair.first
  |> exec.evaluate_return()
  // Return from Function Call #2
  |> should.be_ok
  |> should.equal(#(
    stack.create()
      |> stack.push([
        // Function Call #1
        stack.ActivationEntry(spec.Frame(
          arity: 0,
          framestate: spec.FrameState(
            module_instance: create_empty_module_instance(),
            locals: dict.new(),
          ),
        )),
        stack.LabelEntry(spec.Label(arity: 0, continuation: [])),
        // Values returned from Function Call #2
        stack.ValueEntry(spec.Integer32Value(256)),
        stack.ValueEntry(spec.Integer32Value(512)),
      ]),
    option.Some(exec.Return),
  ))
}
