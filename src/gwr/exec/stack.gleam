import gleam/list
import gleam/option
import gleam/result
import gleam/yielder

import gwr/exec/trap
import gwr/spec

/// https://webassembly.github.io/spec/core/exec/runtime.html#stack
pub type Stack
{
    Stack(entries: List(StackEntry))
}

/// https://webassembly.github.io/spec/core/exec/runtime.html#stack
pub type StackEntry
{
    ValueEntry(spec.Value)
    LabelEntry(spec.Label)
    ActivationEntry(spec.Frame)
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

pub fn count_on_top(from stack: Stack, with predicate: fn (StackEntry) -> Bool) -> Int
{
    pop_while(from: stack, with: predicate).1 |> list.length
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
            yielder.fold(
                from: #(stack, []),
                over: yielder.range(1, count),
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

pub fn pop_as(from stack: Stack, with convert: fn (StackEntry) -> Result(a, trap.Trap)) -> Result(#(Stack, a), trap.Trap)
{
    case pop(from: stack)
    {
        #(stack, option.Some(entry)) ->
        {
            use value <- result.try(convert(entry))
            Ok(#(stack, value))
        }
        _ -> trap.make(trap.Unknown)
             |> trap.add_message("gwr/execution/stack.pop_as: the stack is empty")
             |> trap.to_error()
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

pub fn to_value(entry: StackEntry) -> Result(spec.Value, trap.Trap)
{
    case entry
    {
        ValueEntry(value) -> Ok(value)
        _ -> trap.make(trap.Unknown)
             |> trap.add_message("gwr/execution/stack.to_value: the entry at the top of the stack is not a ValueEntry")
             |> trap.to_error()
    }
}

pub fn to_label(entry: StackEntry) -> Result(spec.Label, trap.Trap)
{
    case entry
    {
        LabelEntry(label) -> Ok(label)
        _ -> trap.make(trap.Unknown)
             |> trap.add_message("gwr/execution/stack.to_label: the entry at the top of the stack is not a LabelEntry")
             |> trap.to_error()
    }
}

pub fn to_frame(entry: StackEntry) -> Result(spec.Frame, trap.Trap)
{
    case entry
    {
        ActivationEntry(frame) -> Ok(frame)
        _ -> trap.make(trap.Unknown)
             |> trap.add_message("gwr/execution/stack.to_frame: the entry at the top of the stack is not a ActivationEntry")
             |> trap.to_error()
    }
}

pub fn get_current_frame(from stack: Stack) -> Result(spec.Frame, Nil)
{
    case pop_while(from: stack, with: fn (entry) { !is_activation_frame(entry) }).0 |> pop
    {
        #(_, option.Some(ActivationEntry(frame))) -> Ok(frame)
        _ -> Error(Nil)
    }
}

pub fn get_current_label(from stack: Stack) -> Result(spec.Label, Nil)
{
    pop_while(from: stack, with: fn (entry) { !is_activation_frame(entry) }).1
    |> list.filter(is_label)
    |> list.map(to_label)
    |> result.values
    |> list.first
}

pub fn replace_current_frame(from stack: Stack, with new_frame: spec.Frame) -> Result(Stack, Nil)
{
    let #(stack, upper_entries) = pop_while(from: stack, with: fn (entry) { !is_activation_frame(entry) })
    let #(stack, frame) = pop(stack)
    case frame
    {
        option.Some(ActivationEntry(_)) -> Ok(push(to: stack, push: [ActivationEntry(new_frame)] |> list.append(upper_entries |> list.reverse)))
        _ -> Error(Nil)
    }
}

pub fn get_entries(from stack: Stack) -> List(StackEntry)
{
    stack.entries
}