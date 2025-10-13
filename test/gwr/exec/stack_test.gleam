import gwr/exec/stack
import gwr/spec

import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn create_test() {
  let stack = stack.create()

  stack.peek(stack)
  |> should.be_none
}

pub fn push___once___test() {
  let stack =
    stack.create()
    |> stack.push([stack.ValueEntry(spec.Integer32Value(1))])

  stack.peek(stack)
  |> should.be_some
  |> should.equal(stack.ValueEntry(spec.Integer32Value(1)))
}

pub fn push___multiple___test() {
  let stack =
    stack.create()
    |> stack.push([
      stack.ValueEntry(spec.Integer32Value(1)),
      stack.ValueEntry(spec.Integer32Value(2)),
      stack.ValueEntry(spec.Integer32Value(3)),
    ])

  stack.peek(stack)
  |> should.be_some
  |> should.equal(stack.ValueEntry(spec.Integer32Value(3)))
}

pub fn pop___once___test() {
  let stack =
    stack.create()
    |> stack.push([stack.ValueEntry(spec.Integer32Value(1))])

  let #(stack, result) = stack.pop(stack)
  result
  |> should.be_some
  |> should.equal(stack.ValueEntry(spec.Integer32Value(1)))

  stack.peek(stack)
  |> should.be_none
}

pub fn pop___multiple___test() {
  let stack =
    stack.create()
    |> stack.push([stack.ValueEntry(spec.Integer32Value(1))])
    |> stack.push([stack.ValueEntry(spec.Integer32Value(2))])
    |> stack.push([stack.ValueEntry(spec.Integer32Value(3))])

  let #(stack, result) = stack.pop(stack)
  result
  |> should.be_some
  |> should.equal(stack.ValueEntry(spec.Integer32Value(3)))

  let #(stack, result) = stack.pop(stack)
  result
  |> should.be_some
  |> should.equal(stack.ValueEntry(spec.Integer32Value(2)))

  let #(stack, result) = stack.pop(stack)
  result
  |> should.be_some
  |> should.equal(stack.ValueEntry(spec.Integer32Value(1)))

  stack.peek(stack)
  |> should.be_none
}

pub fn pop_repeat_test() {
  let stack =
    stack.create()
    |> stack.push([stack.ValueEntry(spec.Integer32Value(1))])
    |> stack.push([stack.ValueEntry(spec.Integer32Value(2))])
    |> stack.push([stack.ValueEntry(spec.Integer32Value(3))])

  let #(stack, result) = stack.pop_repeat(stack, 3)
  result
  |> should.equal([
    stack.ValueEntry(spec.Integer32Value(3)),
    stack.ValueEntry(spec.Integer32Value(2)),
    stack.ValueEntry(spec.Integer32Value(1)),
  ])

  stack.peek(stack)
  |> should.be_none
}

pub fn pop_while_test() {
  let stack =
    stack.create()
    |> stack.push([stack.ValueEntry(spec.Integer32Value(1))])
    |> stack.push([stack.LabelEntry(spec.Label(arity: 0, continuation: []))])
    |> stack.push([stack.ValueEntry(spec.Integer32Value(2))])
    |> stack.push([stack.ValueEntry(spec.Integer32Value(3))])

  let #(stack, result) = stack.pop_while(stack, stack.is_value)
  result
  |> should.equal([
    stack.ValueEntry(spec.Integer32Value(3)),
    stack.ValueEntry(spec.Integer32Value(2)),
  ])

  stack.peek(stack)
  |> should.be_some
  |> should.equal(stack.LabelEntry(spec.Label(arity: 0, continuation: [])))
}
