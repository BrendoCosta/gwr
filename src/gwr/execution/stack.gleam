import gleam/option
import gleam/iterator
import gleam/list

import gwr/execution/runtime
import gwr/syntax/instruction

/// https://webassembly.github.io/spec/core/exec/runtime.html#stack
pub type Stack
{
    Stack(entries: List(StackEntry))
}

/// https://webassembly.github.io/spec/core/exec/runtime.html#stack
pub type StackEntry
{
    ValueEntry(runtime.Value)
    LabelEntry(Label)
    ActivationEntry(ActivationFrame)
}

/// Labels carry an argument arity <n> and their associated branch target, which is expressed
/// syntactically as an instruction sequence:
/// 
/// https://webassembly.github.io/spec/core/exec/runtime.html#labels
pub type Label
{
    Label(arity: Int, continuation: List(instruction.Instruction))
}

/// Activation frames carry the return arity <n> of the respective function, hold the values of
/// its locals (including arguments) in the order corresponding to their static local indices, and
/// a reference to the function’s own module instance:
/// 
/// https://webassembly.github.io/spec/core/exec/runtime.html#activation-frames
pub type ActivationFrame
{
    ActivationFrame(arity: Int, framestate: FrameState)
}

/// https://webassembly.github.io/spec/core/exec/runtime.html#activation-frames
pub type FrameState
{
    FrameState(locals: List(runtime.Value), module_instance: runtime.ModuleInstance)
}

pub fn create() -> Stack
{
    Stack(entries: [])
}

pub fn length(from stack: Stack) -> Int
{
    list.length(stack.entries)
}

pub fn push(to stack: Stack, push new_entries: List(StackEntry)) -> Stack
{
    Stack(entries: list.append(stack.entries, new_entries))
}

pub fn peek(from stack: Stack) -> option.Option(StackEntry)
{
    option.from_result(list.last(stack.entries))
}

pub fn pop(from stack: Stack) -> #(Stack, option.Option(StackEntry))
{
    #(Stack(entries: list.take(from: stack.entries, up_to: length(stack) - 1)), peek(stack))
}

pub fn pop_repeat(from stack: Stack, up_to count: Int)
{
    iterator.fold(from: #(stack, []), over: iterator.range(1, count), with: fn (state, _) {
        let #(stack, results) = pop(state.0)
        #(stack, list.append(state.1, [results]))
    })
}