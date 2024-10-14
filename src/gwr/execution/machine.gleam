import gleam/bool
import gleam/dict
import gleam/int
import gleam/iterator
import gleam/list
import gleam/order
import gleam/option
import gleam/result
import gleam/string

import gwr/execution/runtime
import gwr/execution/stack
import gwr/execution/store
import gwr/syntax/index
import gwr/syntax/instruction
import gwr/syntax/module
import gwr/syntax/types

import ieee_float

/// A configuration consists of the current store and an executing thread.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#configurations
pub type Configuration
{
    Configuration(store: store.Store, thread: Thread)
}

/// A thread is a computation over instructions that operates relative to the state of
/// a current frame referring to the module instance in which the computation runs, i.e.,
/// where the current function originates from.
///
/// NOTE: The current version of WebAssembly is single-threaded, but configurations with
/// multiple threads may be supported in the future.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#configurations
pub type Thread
{
    Thread(framestate: stack.FrameState, instructions: List(instruction.Instruction))
}

pub type Machine
{
    Machine(module_instance: runtime.ModuleInstance, state: MachineState)
}

pub type MachineState
{
    MachineState(configuration: Configuration, stack: stack.Stack)
}

pub fn initialize(from module: module.Module) -> Result(Machine, String)
{

    let store = store.Store
    (
        datas: [],
        elements: [],
        functions: [],
        globals: [],
        memories: [],
        tables: [],
    )

    // Instantiates web aseembly functions

    use store <- result.try(
        list.fold(
            from: Ok(store),
            over: module.functions,
            with: fn (store, function)
            {
                use store <- result.try(store)
                use store <- result.try(
                    store
                    |> store.append_web_assembly_function(function, module.types)
                )
                Ok(store)
            }
        )
    )

    // Instantiates memories

    let store = list.fold(
        from: store,
        over: module.memories,
        with: fn (store, memory)
        {
            store
            |> store.append_memory(memory)
        }
    )

    let module_instance = runtime.ModuleInstance
    (
        types: module.types,
        function_addresses: list.index_map(store.functions, fn (_, index) { runtime.FunctionAddress(index) }),
        table_addresses: [],
        memory_addresses: list.index_map(store.memories, fn (_, index) { runtime.MemoryAddress(index) }),
        global_addresses: [],
        element_addresses: [],
        data_addresses: [],
        exports: [],
    )

    // Remaining configuration

    let thread = Thread
    (
        framestate: stack.FrameState(locals: dict.new(), module_instance: module_instance),
        instructions: []
    )

    let configuration = update_references(
        from: Configuration(store: store, thread: thread),
        with: module_instance
    )

    let state = MachineState(configuration: configuration, stack: stack.create())

    Ok(Machine(state: state, module_instance: module_instance))

}

pub fn update_references(from configuration: Configuration, with module_instance: runtime.ModuleInstance) -> Configuration
{
    let updated_functions = list.filter_map(configuration.store.functions, fn (function) {
        case function
        {
            runtime.WebAssemblyFunctionInstance(type_: type_, module_instance: _, code: code) -> Ok(runtime.WebAssemblyFunctionInstance(type_: type_, module_instance: module_instance, code: code))
            _ -> Error(Nil)
        }
    })

    let store = store.Store(..configuration.store, functions: updated_functions)

    // Remaining configuration

    let thread = Thread
    (
        framestate: stack.FrameState(..configuration.thread.framestate, module_instance: module_instance),
        instructions: configuration.thread.instructions
    )

    Configuration(store: store, thread: thread)
}

pub fn execute(state: MachineState, instructions: List(instruction.Instruction)) -> Result(MachineState, String)
{
    use state <- result.try(
        list.fold(
            from: Ok(state),
            over: instructions, //state.configuration.thread.instructions,
            with: fn (current_state, instruction)
            {
                use current_state <- result.try(current_state)
                case instruction
                {
                    instruction.End -> Ok(current_state)
                    instruction.Block(block_type:, instructions:) -> block(current_state, block_type, instructions)
                    instruction.If(block_type:, instructions: if_instructions, else_: else_) ->
                    {
                        // 1. Assert: due to validation, a value of value type {\mathsf{i32}} is on the top of the stack.
                        // 2. Pop the value {\mathsf{i32}}.{\mathsf{const}}~c from the stack.
                        case stack.pop_as(from: current_state.stack, with: stack.to_value)
                        {
                            Ok(#(stack, runtime.Integer32(c))) ->
                            {
                                let state = MachineState(..current_state, stack: stack)
                                case c != 0
                                {
                                    // 3. If c is non-zero, then:
                                    //     a. Execute the block instruction {\mathsf{block}}~{\mathit{blocktype}}~{\mathit{instr}}_1^\ast~{\mathsf{end}}.
                                    True -> block(state, block_type, if_instructions)
                                    // 4. Else:
                                    //     a. Execute the block instruction {\mathsf{block}}~{\mathit{blocktype}}~{\mathit{instr}}_2^\ast~{\mathsf{end}}.
                                    False -> case else_
                                    {
                                        option.Some(instruction.Else(else_instructions)) -> block(state, block_type, else_instructions)
                                        option.None -> Ok(state)
                                        anything_else -> Error("gwr/execution/machine.execute: (If/Else) illegal instruction in the Else's field " <> string.inspect(anything_else))
                                    }
                                }
                            }
                            anything_else -> Error("gwr/execution/machine.execute: (If/Else) expected the If's continuation flag but got " <> string.inspect(anything_else))
                        }
                    }
                    instruction.Loop(block_type:, instructions:) -> loop(current_state, block_type, instructions)
                    instruction.Br(index:) -> br(current_state, index)
                    instruction.BrIf(index:) -> br_if(current_state, index)

                    instruction.I32Const(value) -> integer_const(current_state, types.Integer32, value)
                    instruction.I64Const(value) -> integer_const(current_state, types.Integer64, value)
                    instruction.F32Const(value) -> float_const(current_state, types.Float32, value)
                    instruction.F64Const(value) -> float_const(current_state, types.Float64, value)
                    instruction.I32Eqz -> integer_eqz(current_state, types.Integer32)
                    instruction.I32Eq  -> integer_eq(current_state, types.Integer32)
                    instruction.I32Ne  -> integer_ne(current_state, types.Integer32)
                    instruction.I32LtS -> integer_lt_s(current_state, types.Integer32)
                    instruction.I32LtU -> integer_lt_u(current_state, types.Integer32)
                    instruction.I32GtS -> integer_gt_s(current_state, types.Integer32)
                    instruction.I32GtU -> integer_gt_u(current_state, types.Integer32)
                    instruction.I32LeS -> integer_le_s(current_state, types.Integer32)
                    instruction.I32LeU -> integer_le_u(current_state, types.Integer32)
                    instruction.I32GeS -> integer_ge_s(current_state, types.Integer32)
                    instruction.I32GeU -> integer_ge_u(current_state, types.Integer32)
                    instruction.I64Eqz -> integer_eqz(current_state, types.Integer64)
                    instruction.I64Eq  -> integer_eq(current_state, types.Integer64)
                    instruction.I64Ne  -> integer_ne(current_state, types.Integer64)
                    instruction.I64LtS -> integer_lt_s(current_state, types.Integer64)
                    instruction.I64LtU -> integer_lt_u(current_state, types.Integer64)
                    instruction.I64GtS -> integer_gt_s(current_state, types.Integer64)
                    instruction.I64GtU -> integer_gt_u(current_state, types.Integer64)
                    instruction.I64LeS -> integer_le_s(current_state, types.Integer64)
                    instruction.I64LeU -> integer_le_u(current_state, types.Integer64)
                    instruction.I64GeS -> integer_ge_s(current_state, types.Integer64)
                    instruction.I64GeU -> integer_ge_u(current_state, types.Integer64)
                    instruction.F32Eq  -> float_eq(current_state, types.Float32)
                    instruction.F32Ne  -> float_ne(current_state, types.Float32)
                    instruction.F32Lt  -> float_lt(current_state, types.Float32)
                    instruction.F32Gt  -> float_gt(current_state, types.Float32)
                    instruction.F32Le  -> float_le(current_state, types.Float32)
                    instruction.F32Ge  -> float_ge(current_state, types.Float32)
                    instruction.F64Eq  -> float_eq(current_state, types.Float64)
                    instruction.F64Ne  -> float_ne(current_state, types.Float64)
                    instruction.F64Lt  -> float_lt(current_state, types.Float64)
                    instruction.F64Gt  -> float_gt(current_state, types.Float64)
                    instruction.F64Le  -> float_le(current_state, types.Float64)
                    instruction.F64Ge  -> float_ge(current_state, types.Float64)

                    instruction.I32Clz -> integer_clz(current_state, types.Integer32)
                    instruction.I64Clz -> integer_clz(current_state, types.Integer64)
                    instruction.I32Ctz -> integer_ctz(current_state, types.Integer32)
                    instruction.I64Ctz -> integer_ctz(current_state, types.Integer64)
                    instruction.I32Popcnt -> integer_popcnt(current_state, types.Integer32)
                    instruction.I64Popcnt -> integer_popcnt(current_state, types.Integer64)
                    
                    instruction.LocalGet(index) -> local_get(current_state, index)
                    instruction.LocalSet(index) -> local_set(current_state, index)
                    instruction.I32Add -> i32_add(current_state)
                    unknown -> Error("gwr/execution/machine.execute: unknown instruction \"" <> string.inspect(unknown) <> "\"")
                }
            }
        )
    )

    Ok(state)
}

fn get_default_value_for_type(type_: types.ValueType) -> runtime.Value
{
    case type_
    {
        types.Number(types.Integer32) -> runtime.Integer32(runtime.number_value_default_value)
        types.Number(types.Integer64) -> runtime.Integer64(runtime.number_value_default_value)
        types.Number(types.Float32) -> runtime.Float32(runtime.Finite(int.to_float(runtime.number_value_default_value)))
        types.Number(types.Float64) -> runtime.Float64(runtime.Finite(int.to_float(runtime.number_value_default_value)))
        types.Vector(types.Vector128) -> runtime.Vector(runtime.vector_value_default_value)
        types.Reference(types.FunctionReference) -> runtime.Reference(runtime.NullReference)
        types.Reference(types.ExternReference) -> runtime.Reference(runtime.NullReference)
    }
}

pub fn call(state: MachineState, index: index.FunctionIndex, arguments: List(runtime.Value)) -> Result(#(MachineState, List(runtime.Value)), String)
{
    // We can do this because we are allocating functions in the same order as they appears in the Module's list.
    // Maybe we can try using something else e.g. a Dict
    let function_address = runtime.FunctionAddress(index)

    use function_instance <- result.try(
        case state.configuration.store.functions |> list.take(up_to: address_to_int(function_address) + 1) |> list.last
        {
            Ok(function_instance) -> Ok(function_instance)
            Error(_) -> Error("gwr/execution/machine.call: couldn't find a function instance with the give address \"" <> address_to_string(function_address) <> "\"")
        }
    )

    case function_instance
    {
        runtime.WebAssemblyFunctionInstance(type_: function_type, module_instance: function_module_instance, code: function_code) ->
        {
            let function_arity = list.length(function_type.results)
            let function_frame = stack.ActivationFrame
            (
                arity: function_arity, // "[...] Activation frames carry the return arity <n> of the respective function [...]"
                framestate: stack.FrameState
                (
                    locals: arguments
                            |> list.append(list.map(function_code.locals, get_default_value_for_type)) // function's arguments will be joined with function's locals
                            |> list.index_map(fn (x, i) { #(i, x) })
                            |> dict.from_list,
                    module_instance: function_module_instance
                )
            )
            let state = MachineState
            (
                configuration: Configuration
                (
                    ..state.configuration,
                    thread: Thread
                    (
                        framestate: function_frame.framestate,
                        instructions: function_code.body
                    )
                ),
                stack: stack.push(push: [stack.ActivationEntry(function_frame)], to: state.stack)
            )

            let label = stack.Label(arity: function_arity, continuation: [])
            use state <- result.try(execute_with_label(state, label, state.configuration.thread.instructions, []))

            let #(stack, result_values) = stack.pop_repeat(state.stack, function_arity)
            let results = result.values(list.map(result_values, stack.to_value)) |> list.reverse
            let count_of_results_returned = list.length(results)
            use <- bool.guard(when: count_of_results_returned != function_arity, return: Error("gwr/execution/machine.call: expected " <> int.to_string(function_arity) <> " values but got only " <> int.to_string(count_of_results_returned)))

            use #(stack, result_frame) <- result.try(stack.pop_as(from: stack, with: stack.to_activation_frame))
            use <- bool.guard(when: result_frame != function_frame, return: Error("gwr/execution/machine.call: expected the last stack frame to be the calling function frame"))

            Ok(#(MachineState(..state, stack: stack), results))
        }
        runtime.HostFunctionInstance(type_: _, code: _) -> Error("@TODO: call host function")
    }
}

pub fn br(state: MachineState, index: index.LabelIndex)
{
    // 1. Assert: due to validation, the stack contains at least l+1 labels.
    let all_labels = stack.pop_all(from: state.stack).1 |> list.filter(stack.is_label)
    let count_of_labels_in_stack = all_labels |> list.length
    use <- bool.guard(when: count_of_labels_in_stack < index + 1, return: Error("gwr/execution/machine.br: expected the stack to contains at least " <> int.to_string(index + 1) <> " labels but got " <> int.to_string(count_of_labels_in_stack)))
    // 2. Let L be the l-th label appearing on the stack, starting from the top and counting from zero.
    // 3. Let n be the arity of L.
    use label_entry <- result.try(result.replace_error(all_labels |> list.take(up_to: index + 1) |> list.last, "gwr/execution/machine.br: couldn't find the label with index " <> int.to_string(index)))
    use label <- result.try(stack.to_label(label_entry))
    let n = label.arity
    // 4. Assert: due to validation, there are at least n values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: state.stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < n, return: Error("gwr/execution/machine.br: expected the top of the stack to contains at least " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top)))
    // 5. Pop the values {\mathit{val}}^n from the stack.
    let #(stack, values) = stack.pop_repeat(state.stack, n)
    
    // @NOTE: while the procedure described in the specification for
    // "exiting an instruction sequence with a label" simply discards
    // the previous labels, here we are going to collect and put them
    // right below the continuation values in the stack. That way they
    // won't interfere with the execution at all, plus the execute_with_label
    // function will not throw us an error complaining about missing
    // labels.

    // 6. Repeat l+1 times:
    use #(stack, popped_labels) <- result.try(
        iterator.fold(
            from: Ok(#(stack, [])),
            over: iterator.range(1, index + 1),
            with: fn (accumulator, _)
            {
                use #(stack, popped_labels) <- result.try(accumulator)
                // a. While the top of the stack is a value, do:
                //     i. Pop the value from the stack.
                let #(stack, _) = stack.pop_while(from: stack, with: stack.is_value)
                // b. Assert: due to validation, the top of the stack now is a label.
                // c. Pop the label from the stack.
                case stack.pop(from: stack)
                {
                    #(stack, option.Some(popped_label)) -> Ok(#(stack, popped_labels |> list.append([popped_label])))
                    #(_, anything_else) -> Error("gwr/execution/machine.br: expected the top of the stack to contain a label but got " <> string.inspect(anything_else))
                }
            }
        )
    )

    // 7. Push the values {\mathit{val}}^n to the stack.
    let stack = stack.push(to: stack, push: popped_labels |> list.append(values) |> list.reverse)
    // 8. Jump to the continuation of L.
    execute(MachineState(..state, stack: stack), label.continuation)
}

pub fn br_if(state: MachineState, index: index.LabelIndex)
{
    // 1. Assert: due to validation, a value of value type {\mathsf{i32}} is on the top of the stack.
    // 2. Pop the value {\mathsf{i32}}.{\mathsf{const}}~c from the stack.
    case stack.pop(from: state.stack)
    {
        #(stack, option.Some(stack.ValueEntry(runtime.Integer32(c)))) ->
        {
            let state = MachineState(..state, stack: stack)
            // 3. If c is non-zero, then:
            case c != 0
            {
                // a. Execute the instruction {\mathsf{br}}~l.
                True -> br(state, index)
                // 4. Else:
                //     b. Do nothing.
                False -> Ok(state)
            }
        }
        _ -> Error("gwr/execution/machine.br_if: expected the top of the stack to contain an i32 value")
    }
}

pub fn loop(state: MachineState, block_type: instruction.BlockType, instructions: List(instruction.Instruction)) -> Result(MachineState, String)
{
    // 1. Let F be the current frame.
    // 2. Assert: due to validation, {\mathrm{expand}}_F({\mathit{blocktype}}) is defined.
    // 3. Let [t_1^m] {\rightarrow} [t_2^n] be the function type {\mathrm{expand}}_F({\mathit{blocktype}}).
    use function_type <- result.try(expand_block_type(state.configuration.thread.framestate, block_type))
    let m = list.length(function_type.parameters)
    // let n = list.length(function_type.results)
    // 4. Let L be the label whose arity is m and whose continuation is the start of the loop.
    let label = stack.Label(arity: m, continuation: [instruction.Loop(block_type: block_type, instructions: instructions)])
    // 5. Assert: due to validation, there are at least m values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: state.stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < m, return: Error("gwr/execution/machine.loop: expected the top of the stack to contains at least " <> int.to_string(m) <> " values but got " <> int.to_string(count_of_values_on_top)))
    // 6. Pop the values {\mathit{val}}^m from the stack.
    let #(stack, values) = stack.pop_repeat(from: state.stack, up_to: m)
    // 7. Enter the block {\mathit{val}}^m~{\mathit{instr}}^\ast with label L.
    execute_with_label(MachineState(..state, stack: stack), label, instructions, values |> list.reverse)
}

pub fn block(state: MachineState, block_type: instruction.BlockType, instructions: List(instruction.Instruction)) -> Result(MachineState, String)
{
    // 1. Let F be the current frame.
    // 2. Assert: due to validation, {\mathrm{expand}}_F({\mathit{blocktype}}) is defined.
    // 3. Let [t_1^m] {\rightarrow} [t_2^n] be the function type {\mathrm{expand}}_F({\mathit{blocktype}}).
    use function_type <- result.try(expand_block_type(state.configuration.thread.framestate, block_type))
    let m = list.length(function_type.parameters)
    let n = list.length(function_type.results)
    // 4. Let L be the label whose arity is n and whose continuation is the end of the block.
    let label = stack.Label(arity: n, continuation: [])
    // 5. Assert: due to validation, there are at least m values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: state.stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < m, return: Error("gwr/execution/machine.block: expected the top of the stack to contains at least " <> int.to_string(m) <> " values but got " <> int.to_string(count_of_values_on_top)))
    // 6. Pop the values {\mathit{val}}^m from the stack.
    let #(stack, values) = stack.pop_repeat(from: state.stack, up_to: m)
    // 7. Enter the block {\mathit{val}}^m~{\mathit{instr}}^\ast with label L.
    execute_with_label(MachineState(..state, stack: stack), label, instructions, values |> list.reverse)
}

pub fn execute_with_label(state: MachineState, label: stack.Label, instructions: List(instruction.Instruction), parameters: List(stack.StackEntry)) -> Result(MachineState, String)
{
    // Entering {\mathit{instr}}^\ast with label L
    // 1. Push L to the stack.
    let state = MachineState(..state, stack: stack.push(state.stack, [stack.LabelEntry(label)] |> list.append(parameters) ))
    // 2. Jump to the start of the instruction sequence {\mathit{instr}}^\ast.
    use state <- result.try(execute(state, instructions))
    
    // Exiting {\mathit{instr}}^\ast with label L
    // 1. Pop all values {\mathit{val}}^\ast from the top of the stack.
    let #(stack, values) = stack.pop_while(from: state.stack, with: stack.is_value)
    // 2. Assert: due to validation, the label L is now on the top of the stack.
    // 3. Pop the label from the stack.
    use stack <- result.try(
        case stack.pop(stack)
        {
            #(stack, option.Some(stack.LabelEntry(some_label))) if some_label == label -> Ok(stack)
            #(_, anything_else) -> Error("gwr/execution/machine.execute_with_label: expected the label " <> string.inspect(label) <> " pushed to the stack before execution but got " <> string.inspect(anything_else))
        }
    )
    // 4. Push {\mathit{val}}^\ast back to the stack.
    let state = MachineState(..state, stack: stack.push(to: stack, push: values |> list.reverse))
    // 5. Jump to the position after the {\mathsf{end}} of the structured control instruction associated with the label L.
    Ok(state)
}

pub fn address_to_int(address: runtime.Address) -> Int
{
    case address
    {
        runtime.FunctionAddress(addr) -> addr
        runtime.TableAddress(addr) -> addr
        runtime.MemoryAddress(addr) -> addr
        runtime.GlobalAddress(addr) -> addr
        runtime.ElementAddress(addr) -> addr
        runtime.DataAddress(addr) -> addr
        runtime.ExternAddress(addr) -> addr
    }
}

pub fn address_to_string(address: runtime.Address) -> String
{
    int.to_string(address_to_int(address))
}

pub fn expand_block_type(framestate: stack.FrameState, block_type: instruction.BlockType) -> Result(types.FunctionType, String)
{
    case block_type
    {
        instruction.TypeIndexBlock(index) -> result.replace_error(framestate.module_instance.types |> list.take(up_to: index + 1) |> list.last, "gwr/execution/machine.expand: couldn't find the function type with index \"" <> int.to_string(index) <> "\"")
        instruction.ValueTypeBlock(type_: option.Some(valtype)) -> Ok(types.FunctionType(parameters: [], results: [valtype]))
        instruction.ValueTypeBlock(type_: option.None) -> Ok(types.FunctionType(parameters: [], results: []))
    }
}

pub type BinaryOperationHandler
{
    IntegerBinaryOperation(fn (Int, Int) -> Result(runtime.Value, String))
    FloatBinaryOperation(fn (ieee_float.IEEEFloat, ieee_float.IEEEFloat) -> Result(runtime.Value, String))
}

pub type UnaryOperationHandler
{
    IntegerUnaryOperation(fn (Int) -> Result(runtime.Value, String))
    FloatUnaryOperation(fn (ieee_float.IEEEFloat) -> Result(runtime.Value, String))
}

pub fn binary_operation(state: MachineState, type_: types.NumberType, operation_handler: BinaryOperationHandler) -> Result(MachineState, String)
{
    let #(stack, values) = stack.pop_repeat(state.stack, 2)
    use result <- result.try(
        case type_, operation_handler, values
        {
              types.Integer32, IntegerBinaryOperation(handler), [stack.ValueEntry(runtime.Integer32(value: b)), stack.ValueEntry(runtime.Integer32(value: a))] 
            | types.Integer64, IntegerBinaryOperation(handler), [stack.ValueEntry(runtime.Integer64(value: b)), stack.ValueEntry(runtime.Integer64(value: a))] ->
            {
                handler(a, b)
            }
              types.Float32, FloatBinaryOperation(handler), [stack.ValueEntry(runtime.Float32(value: b)), stack.ValueEntry(runtime.Float32(value: a))]
            | types.Float64, FloatBinaryOperation(handler), [stack.ValueEntry(runtime.Float64(value: b)), stack.ValueEntry(runtime.Float64(value: a))] ->
            {
                use a <- result.try(runtime.builtin_float_to_ieee_float(a))
                use b <- result.try(runtime.builtin_float_to_ieee_float(b))
                handler(a, b)
            }
            t, h, args -> Error("gwr/execution/machine.binary_operation: wrong operands type or handler for an instruction of type \"" <> string.inspect(t) <> "\": \"" <> string.inspect(h) <> "\" \"" <> string.inspect(args) <> "\"")
        }
    )

    let stack = stack.push(stack, [stack.ValueEntry(result)])
    Ok(MachineState(..state, stack: stack))
}

pub fn unary_operation(state: MachineState, type_: types.NumberType, operation_handler: UnaryOperationHandler) -> Result(MachineState, String)
{
    let #(stack, values) = stack.pop(state.stack)
    use result <- result.try(
        case type_, operation_handler, values
        {
              types.Integer32, IntegerUnaryOperation(handler), option.Some(stack.ValueEntry(runtime.Integer32(value: a))) 
            | types.Integer64, IntegerUnaryOperation(handler), option.Some(stack.ValueEntry(runtime.Integer64(value: a))) ->
            {
                use result <- result.try(handler(a))
                // Do operations with 64 bit, demote it to 32 bit if necessary
                case type_, result
                {
                    types.Integer32, runtime.Integer64(v) -> Ok(runtime.Integer32(v))
                    _, _ -> Ok(result)
                }
            }
              types.Float32, FloatUnaryOperation(handler), option.Some(stack.ValueEntry(runtime.Float32(value: a)))
            | types.Float64, FloatUnaryOperation(handler), option.Some(stack.ValueEntry(runtime.Float64(value: a))) ->
            {
                use a <- result.try(runtime.builtin_float_to_ieee_float(a))
                handler(a)
            }
            t, h, args -> Error("gwr/execution/machine.unary_operation: wrong operands type or handler for an instruction of type \"" <> string.inspect(t) <> "\": \"" <> string.inspect(h) <> "\" \"" <> string.inspect(args) <> "\"")
        }
    )

    let stack = stack.push(stack, [stack.ValueEntry(result)])
    Ok(MachineState(..state, stack: stack))
}

pub fn get_bitwidth(type_: types.NumberType) -> Int
{
    case type_
    {
        types.Integer32 | types.Float32 -> 32
        types.Integer64 | types.Float64 -> 64
    }
}

pub fn bool_to_i32_bool(value: Bool) -> runtime.Value
{
    case value
    {
        True -> runtime.true_
        False -> runtime.false_
    }
}

fn signed_integer_overflow_check(value: Int, bits: Int) -> Result(Int, String)
{
    case bits, value
    {
        32, v if v >= -2_147_483_648 && v <= 2_147_483_647 -> Ok(v)
        64, v if v >= -9_223_372_036_854_775_808 && v <= 9_223_372_036_854_775_807 -> Ok(v)
        b, _ if b != 32 && b != 64 -> Error("gwr/execution/machine.signed_integer_overflow_check: unsupported bit width \"" <> int.to_string(b) <> "\"")
        _, _ -> Error("gwr/execution/machine.signed_integer_overflow_check: signed integer overflow")
    }
}

fn unsigned_integer_overflow_check(value: Int, bits: Int) -> Result(Int, String)
{
    case bits, value
    {
        32, v if v >= 0 && v <= 4_294_967_295 -> Ok(v)
        64, v if v >= 0 && v <= 18_446_744_073_709_551_615 -> Ok(v)
        b, _ if b != 32 && b != 64 -> Error("gwr/execution/machine.unsigned_integer_overflow_check: unsupported bit width \"" <> int.to_string(b) <> "\"")
        _, _ -> Error("gwr/execution/machine.unsigned_integer_overflow_check: unsigned integer overflow")
    }
}

pub fn integer_const(state: MachineState, type_: types.NumberType, value: Int) -> Result(MachineState, String)
{
    use entry <- result.try(
        case type_
        {
            types.Integer32 -> Ok(runtime.Integer32(value))
            types.Integer64 -> Ok(runtime.Integer64(value))
            anything_else -> Error("gwr/execution/machine.integer_const: unexpected arguments \"" <> string.inspect(anything_else) <> "\"")
        }
    )
    let stack = stack.push(state.stack, [stack.ValueEntry(entry)])
    Ok(MachineState(..state, stack: stack))
}

pub fn float_const(state: MachineState, type_: types.NumberType, value: ieee_float.IEEEFloat) -> Result(MachineState, String)
{
    use built_in_float <- result.try(runtime.ieee_float_to_builtin_float(value))
    use entry <- result.try(
        case type_
        {
            types.Float32 -> Ok(runtime.Float32(built_in_float))
            types.Float64 -> Ok(runtime.Float64(built_in_float))
            anything_else -> Error("gwr/execution/machine.float_const: unexpected arguments \"" <> string.inspect(anything_else) <> "\"")
        }
    )
    let stack = stack.push(state.stack, [stack.ValueEntry(entry)])
    Ok(MachineState(..state, stack: stack))
}

pub fn integer_eqz(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    unary_operation(state, type_, IntegerUnaryOperation(fn (a) {
        Ok(bool_to_i32_bool(a == 0))
    }))
}

pub fn integer_eq(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) { Ok(bool_to_i32_bool(a == b)) }))
}

pub fn integer_ne(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) { Ok(bool_to_i32_bool(a != b)) }))
}

pub fn integer_lt_s(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
            use a <- result.try(signed_integer_overflow_check(a, get_bitwidth(type_)))
            use b <- result.try(signed_integer_overflow_check(b, get_bitwidth(type_)))
            Ok(bool_to_i32_bool(a < b))
        })
    )
}

pub fn integer_lt_u(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        use a <- result.try(unsigned_integer_overflow_check(a, get_bitwidth(type_)))
        use b <- result.try(unsigned_integer_overflow_check(b, get_bitwidth(type_)))
        Ok(bool_to_i32_bool(a < b))
    }))
}

pub fn integer_gt_s(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        use a <- result.try(signed_integer_overflow_check(a, get_bitwidth(type_)))
        use b <- result.try(signed_integer_overflow_check(b, get_bitwidth(type_)))
        Ok(bool_to_i32_bool(a > b))
    }))
}

pub fn integer_gt_u(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        use a <- result.try(unsigned_integer_overflow_check(a, get_bitwidth(type_)))
        use b <- result.try(unsigned_integer_overflow_check(b, get_bitwidth(type_)))
        Ok(bool_to_i32_bool(a > b))
    }))
}

pub fn integer_le_s(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        use a <- result.try(signed_integer_overflow_check(a, get_bitwidth(type_)))
        use b <- result.try(signed_integer_overflow_check(b, get_bitwidth(type_)))
        Ok(bool_to_i32_bool(a <= b))
    }))
}

pub fn integer_le_u(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        use a <- result.try(unsigned_integer_overflow_check(a, get_bitwidth(type_)))
        use b <- result.try(unsigned_integer_overflow_check(b, get_bitwidth(type_)))
        Ok(bool_to_i32_bool(a <= b))
    }))
}

pub fn integer_ge_s(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        use a <- result.try(signed_integer_overflow_check(a, get_bitwidth(type_)))
        use b <- result.try(signed_integer_overflow_check(b, get_bitwidth(type_)))
        Ok(bool_to_i32_bool(a >= b))
    }))
}

pub fn integer_ge_u(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        use a <- result.try(unsigned_integer_overflow_check(a, get_bitwidth(type_)))
        use b <- result.try(unsigned_integer_overflow_check(b, get_bitwidth(type_)))
        Ok(bool_to_i32_bool(a >= b))
    }))
}

pub fn float_eq(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, FloatBinaryOperation(fn (a, b) {
        Ok(bool_to_i32_bool(
            case ieee_float.compare(a, b)
            {
                Ok(order.Eq) -> True
                _ -> False
            }
        ))
    }))
}

pub fn float_ne(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, FloatBinaryOperation(fn (a, b) {
        Ok(bool_to_i32_bool(
            case ieee_float.compare(a, b)
            {
                Ok(order.Eq) -> False
                Error(Nil) -> False
                _ -> True
            }
        ))
    }))
}

pub fn float_lt(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, FloatBinaryOperation(fn (a, b) {
        Ok(bool_to_i32_bool(
            case ieee_float.compare(a, b)
            {
                Ok(order.Lt) -> True
                _ -> False
            }
        ))
    }))
}

pub fn float_gt(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, FloatBinaryOperation(fn (a, b) {
        Ok(bool_to_i32_bool(
            case ieee_float.compare(a, b)
            {
                Ok(order.Gt) -> True
                _ -> False
            }
        ))
    }))
}

pub fn float_le(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, FloatBinaryOperation(fn (a, b) {
        Ok(bool_to_i32_bool(
            case ieee_float.compare(a, b)
            {
                Ok(order.Lt) | Ok(order.Eq) -> True
                _ -> False
            }
        ))
    }))
}

pub fn float_ge(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, FloatBinaryOperation(fn (a, b) {
        Ok(bool_to_i32_bool(
            case ieee_float.compare(a, b)
            {
                Ok(order.Gt) | Ok(order.Eq) -> True
                _ -> False
            }
        ))
    }))
}

pub fn integer_clz(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    unary_operation(state, type_, IntegerUnaryOperation(fn (a) {

        let mask_32: fn(Int) -> Int = fn (value)
        {
            int.bitwise_and(value, 0xffffffff)
        }
        
        let clz_32: fn(Int) -> Int = fn (value)
        {
            case value
            {
                0 -> 32
                _ ->
                {
                    let n = 0
                    let #(n, value) = case value <= 0x0000ffff
                    {
                        True -> #(n + 16, int.bitwise_shift_left(value, 16) |> mask_32)
                        False -> #(n, value)
                    }
                    let #(n, value) = case value <= 0x00ffffff
                    {
                        True -> #(n + 8, int.bitwise_shift_left(value, 8) |> mask_32)
                        False -> #(n, value)
                    }
                    let #(n, value) = case value <= 0x0fffffff
                    {
                        True -> #(n + 4, int.bitwise_shift_left(value, 4) |> mask_32)
                        False -> #(n, value)
                    }
                    let #(n, value) = case value <= 0x3fffffff
                    {
                        True -> #(n + 2, int.bitwise_shift_left(value, 2) |> mask_32)
                        False -> #(n, value)
                    }
                    let n = case value <= 0x7fffffff
                    {
                        True -> n + 1
                        False -> n
                    }
                    n
                }
            }
        }

        let res = case type_
        {
            types.Integer32 -> clz_32(a)
            types.Integer64 ->
            {
                case a
                {
                    0 -> 64
                    _ ->
                    {
                        let low = int.bitwise_and(a, 0x00000000ffffffff)
                        let high = int.bitwise_shift_right(a, 32)
                        case high
                        {
                            0 -> 32 + clz_32(low)
                            _ -> clz_32(high)
                        }
                    }
                }
            }
            _ -> 0
        } 

        Ok(runtime.Integer64(res))
    }))
}

pub fn integer_ctz(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    unary_operation(state, type_, IntegerUnaryOperation(fn (a) {
        
        let ctz_32: fn(Int) -> Int = fn (value)
        {
            case value
            {
                0 -> 32
                _ ->
                {
                    let n = 0
                    let #(n, value) = case int.bitwise_and(value, 0x0000ffff)
                    {
                        0 -> #(n + 16, int.bitwise_shift_right(value, 16))
                        _ -> #(n, value)
                    }
                    let #(n, value) = case int.bitwise_and(value, 0x000000ff)
                    {
                        0 -> #(n + 8, int.bitwise_shift_right(value, 8))
                        _ -> #(n, value)
                    }
                    let #(n, value) = case int.bitwise_and(value, 0x0000000f)
                    {
                        0 -> #(n + 4, int.bitwise_shift_right(value, 4))
                        _ -> #(n, value)
                    }
                    let #(n, value) = case int.bitwise_and(value, 0x00000003)
                    {
                        0 -> #(n + 2, int.bitwise_shift_right(value, 2))
                        _ -> #(n, value)
                    }
                    let n = case int.bitwise_and(value, 0x00000001)
                    {
                        0 -> n + 1
                        _ -> n
                    }
                    n
                }
            }
        }

        let res = case type_
        {
            types.Integer32 -> ctz_32(a)
            types.Integer64 ->
            {
                case a
                {
                    0 -> 64
                    _ ->
                    {
                        let low = int.bitwise_and(a, 0x00000000ffffffff)
                        let high = int.bitwise_shift_right(a, 32)
                        case low
                        {
                            0 -> 32 + ctz_32(high)
                            _ -> ctz_32(low)
                        }
                    }
                }
            }
            _ -> 0
        } 

        Ok(runtime.Integer64(res))
    }))
}

pub fn integer_popcnt(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    unary_operation(state, type_, IntegerUnaryOperation(fn (a) {

        let popcnt_32: fn(Int) -> Int = fn (value)
        {
            let value = int.bitwise_and(value, 0x55555555) + int.bitwise_and(int.bitwise_shift_right(value, 1), 0x55555555)
            let value = int.bitwise_and(value, 0x33333333) + int.bitwise_and(int.bitwise_shift_right(value, 2), 0x33333333)
            let value = int.bitwise_and(value, 0x0f0f0f0f) + int.bitwise_and(int.bitwise_shift_right(value, 4), 0x0f0f0f0f)
            let value = int.bitwise_and(value, 0x00ff00ff) + int.bitwise_and(int.bitwise_shift_right(value, 8), 0x00ff00ff)
            let value = int.bitwise_and(value, 0x0000ffff) + int.bitwise_and(int.bitwise_shift_right(value, 16), 0x0000ffff)
            value
        }
        
        let res = case type_
        {
            types.Integer32 -> popcnt_32(a)
            types.Integer64 ->
            {
                let low_cnt = popcnt_32(a)
                let high_cnt = popcnt_32(int.bitwise_shift_right(a, 32))
                low_cnt + high_cnt
            }
            _ -> 0
        } 

        Ok(runtime.Integer64(res))
    }))
}

pub fn i32_add(state: MachineState) -> Result(MachineState, String)
{
    let #(stack, values) = stack.pop_repeat(state.stack, 2)
    use result <- result.try(
        case values
        {
            [stack.ValueEntry(runtime.Integer32(value: a)), stack.ValueEntry(runtime.Integer32(value: b))] -> Ok(a + b)
            anything_else -> Error("gwr/execution/machine.i32_add: unexpected arguments \"" <> string.inspect(anything_else) <> "\"")
        }
    )

    let stack = stack.push(stack, [stack.ValueEntry(runtime.Integer32(result))])
    Ok(MachineState(..state, stack: stack))
}

pub fn local_get(state: MachineState, index: index.LocalIndex) -> Result(MachineState, String)
{
    use local <- result.try(result.replace_error(dict.get(state.configuration.thread.framestate.locals, index), "gwr/execution/machine.local_get: couldn't get the local with index " <> int.to_string(index)))

    let stack = stack.push(state.stack, [stack.ValueEntry(local)])
    Ok(MachineState(..state, stack: stack))
}

pub fn local_set(state: MachineState, index: index.LocalIndex) -> Result(MachineState, String)
{
    // 1. Let F be the current frame.
    // 2. Assert: due to validation, F.locals[x] exists.
    use _ <- result.try(result.replace_error(dict.get(state.configuration.thread.framestate.locals, index), "gwr/execution/machine.local_set: couldn't get the local with index " <> int.to_string(index)))
    
    // 3. Assert: due to validation, a value is on the top of the stack.
    // 4. Pop the value val from the stack.
    use #(stack, value) <- result.try(stack.pop_as(from: state.stack, with: stack.to_value))

    // 5. Replace F.locals[x] with the value val.
    Ok(
        MachineState
        (
            configuration: Configuration
            (
                ..state.configuration,
                thread: Thread
                (
                    ..state.configuration.thread,
                    framestate: stack.FrameState
                    (
                        ..state.configuration.thread.framestate,
                        locals: dict.insert(into: state.configuration.thread.framestate.locals, for: index, insert: value)
                    )
                )
            ), stack: stack
        )
    )
}