import gleam/dict.{type Dict}
import gleam/iterator
import gleam/list
import gleam/option
import gleam/result

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
    FrameState(locals: Dict(Int, runtime.Value), module_instance: runtime.ModuleInstance)
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
    case count > 0
    {
        False -> #(stack, [])
        True ->
        {
            iterator.fold(
                from: #(stack, []),
                over: iterator.range(1, count),
                with: fn (accumulator, _)
                {
                    let #(stack_after_pop, maybe_popped_entry) = pop(accumulator.0)
                    case maybe_popped_entry
                    {
                        option.Some(entry) -> #(stack_after_pop, accumulator.1 |> list.append([entry]))
                        option.None -> #(stack_after_pop, accumulator.1)
                    }
                }
            )
        }
    }
}

pub fn pop_all(from stack: Stack) -> #(Stack, List(StackEntry))
{
    #(create(), stack.entries |> list.reverse)
}

pub fn pop_while(from stack: Stack, with predicate: fn (StackEntry) -> Bool)
{
    do_pop_while(#(stack, []), predicate)
}

fn do_pop_while(accumulator: #(Stack, List(StackEntry)), predicate: fn (StackEntry) -> Bool) -> #(Stack, List(StackEntry))
{
    case peek(from: accumulator.0)
    {
        option.Some(entry) ->
        {
            case predicate(entry)
            {
                True -> do_pop_while(#(pop(accumulator.0).0, accumulator.1 |> list.append([entry])), predicate)
                False -> #(accumulator.0, accumulator.1)
            }
        }
        _ -> #(accumulator.0, accumulator.1)
    }
}

pub fn pop_if(from stack: Stack, with predicate: fn (StackEntry) -> Bool) -> Result(#(Stack, StackEntry), Nil)
{
    case pop(from: stack)
    {
        #(stack, option.Some(entry)) ->
        {
            case predicate(entry)
            {
                True -> Ok(#(stack, entry))
                False -> Error(Nil)
            }
        }
        _ -> Error(Nil)
    }
}

pub fn pop_as(from stack: Stack, with convert: fn (StackEntry) -> Result(a, String)) -> Result(#(Stack, a), String)
{
    case pop(from: stack)
    {
        #(stack, option.Some(entry)) ->
        {
            use value <- result.try(convert(entry))
            Ok(#(stack, value))
        }
        _ -> Error("gwr/execution/stack.pop_as: the stack is empty")
    }
}

pub fn is_value(entry: StackEntry) -> Bool
{
    case entry
    {
        ValueEntry(_) -> True
        _ -> False
    }
}

pub fn is_label(entry: StackEntry) -> Bool
{
    case entry
    {
        LabelEntry(_) -> True
        _ -> False
    }
}

pub fn is_activation_frame(entry: StackEntry) -> Bool
{
    case entry
    {
        ActivationEntry(_) -> True
        _ -> False
    }
}

pub fn to_value(entry: StackEntry) -> Result(runtime.Value, String)
{
    case entry
    {
        ValueEntry(value) -> Ok(value)
        _ -> Error("gwr/execution/stack.to_value: the entry at the top of the stack is not a ValueEntry")
    }
}

pub fn to_label(entry: StackEntry) -> Result(Label, String)
{
    case entry
    {
        LabelEntry(label) -> Ok(label)
        _ -> Error("gwr/execution/stack.to_label: the entry at the top of the stack is not a LabelEntry")
    }
}

pub fn to_activation_frame(entry: StackEntry) -> Result(ActivationFrame, String)
{
    case entry
    {
        ActivationEntry(activation_frame) -> Ok(activation_frame)
        _ -> Error("gwr/execution/stack.to_activation_frame: the entry at the top of the stack is not a ActivationEntry")
    }
}