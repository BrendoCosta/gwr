import gleam/io
import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/order
import gleam/option

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
        framestate: stack.FrameState(locals: [], module_instance: module_instance),
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
            let function_locals = list.fold(
                from: arguments, // function's arguments will be joined with function's locals
                over: function_code.locals,
                with: fn (function_locals, local) {
                let value = case local
                {
                    types.Number(types.Integer32) -> runtime.Integer32(runtime.number_value_default_value)
                    types.Number(types.Integer64) -> runtime.Integer64(runtime.number_value_default_value)
                    types.Number(types.Float32) -> runtime.Float32(runtime.Finite(int.to_float(runtime.number_value_default_value)))
                    types.Number(types.Float64) -> runtime.Float64(runtime.Finite(int.to_float(runtime.number_value_default_value)))
                    types.Vector(types.Vector128) -> runtime.Vector(runtime.vector_value_default_value)
                    types.Reference(types.FunctionReference) -> runtime.Reference(runtime.NullReference)
                    types.Reference(types.ExternReference) -> runtime.Reference(runtime.NullReference)
                }
                list.append(function_locals, [value])
            })
            let function_arity = list.length(function_type.results)
            let function_frame = stack.ActivationFrame
            (
                arity: function_arity, // "[...] Activation frames carry the return arity <n> of the respective function [...]"
                framestate: stack.FrameState
                (
                    locals: function_locals,
                    module_instance: function_module_instance
                )
            )
            let new_state_stack = stack.push(push: [stack.ActivationEntry(function_frame)], to: state.stack)
            let new_state_configuration = Configuration(..state.configuration, thread: Thread(framestate: function_frame.framestate, instructions: function_code.body))
            let new_state = MachineState(configuration: new_state_configuration, stack: new_state_stack)

            use after_state <- result.try(execute_with_label(new_state, stack.Label(arity: function_arity, continuation: []), []))

            let #(result_stack, result_values) = stack.pop_repeat(after_state.stack, function_frame.arity)

            use <- bool.guard(when: option.values([stack.peek(result_stack)]) != [stack.ActivationEntry(function_frame)], return: Error("gwr/execution/machine.call: expected the last stack frame to be the calling function frame"))

            let result_values = option.values(result_values)
            let result_arity = list.length(result_values)
            use <- bool.guard(when: result_arity != function_frame.arity, return: Error("gwr/execution/machine.call: expected " <> int.to_string(function_frame.arity) <> " values but got only " <> int.to_string(result_arity)))

            let results = list.filter_map(result_values, fn (entry) {
                case entry
                {
                    stack.ValueEntry(v) -> Ok(v)
                    _ -> Error(Nil)
                }
            })

            Ok(#(MachineState(..after_state, stack: result_stack), results))
        }
        runtime.HostFunctionInstance(type_: _, code: _) -> Error("@TODO: call host function")
    }
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

pub fn execute_with_label(state: MachineState, label: stack.Label, parameters: List(stack.StackEntry)) -> Result(MachineState, String)
{
    let label_entry = stack.LabelEntry(label)
    let state_to_be_executed = MachineState(..state, stack: stack.push(state.stack, [label_entry] |> list.append(parameters)))
    use state_after_execution <- result.try(execute(state_to_be_executed))
    use #(stack_after_label_popped, results) <- result.try(
        {
            let #(stack_after_results_popped, results) = stack.pop_repeat(from: state_after_execution.stack, up_to: label.arity)
            case stack.pop(stack_after_results_popped)
            {
                #(stack_after_label_popped, option.Some(entry)) if entry == label_entry -> Ok(#(stack_after_label_popped, results))
                #(_, anything_else) -> Error("gwr/execution/machine.execute_with_label: expected the label " <> string.inspect(option.Some(label_entry)) <> " pushed to the stack before execution but got " <> string.inspect(anything_else))
            }
        }
    )
    
    Ok(MachineState(..state, stack: stack.push(stack_after_label_popped, option.values(results))))
}

pub fn execute(state: MachineState) -> Result(MachineState, String)
{
    use state <- result.try(
        list.fold(
            from: Ok(state),
            over: state.configuration.thread.instructions,
            with: fn (current_state, instruction)
            {
                use current_state <- result.try(current_state)
                case instruction
                {
                    instruction.End -> Ok(current_state)

                    instruction.Block(block_type: bt, instructions: inst) ->
                    {
                        use function_type <- result.try(expand_block_type(current_state.configuration.thread.framestate, bt))
                        let arity = list.length(function_type.results)
                        let label = stack.Label(arity: arity, continuation: [])
                        // Assert: due to validation, there are at least <m> values on the top of the stack.
                        let #(stack, parameters) = stack.pop_repeat(from: current_state.stack, up_to: label.arity)
                        // Change thread's instructions to the block's instructions
                        use after_state <- result.try(execute_with_label(MachineState(configuration: Configuration(..current_state.configuration, thread: Thread(..current_state.configuration.thread, instructions: inst)), stack: stack), label, option.values(parameters)))
                        // Change thread's instructions back
                        Ok(MachineState(..after_state, configuration: Configuration(..after_state.configuration, thread: Thread(..after_state.configuration.thread, instructions: current_state.configuration.thread.instructions))))
                    }

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
                    instruction.I32Add -> i32_add(current_state)
                    unknown -> Error("gwr/execution/machine.execute: unknown instruction \"" <> string.inspect(unknown) <> "\"")
                }
            }
        )
    )

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
        case type_, operation_handler, option.values(values)
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
    let #(stack, entry) = stack.pop(state.stack)
    use result <- result.try(
        case type_, entry
        {
            types.Integer32, option.Some(stack.ValueEntry(runtime.Integer32(value: 0)))
            | types.Integer64, option.Some(stack.ValueEntry(runtime.Integer64(value: 0))) -> Ok(stack.ValueEntry(runtime.true_))

            types.Integer32, option.Some(stack.ValueEntry(runtime.Integer32(value: _)))
            | types.Integer64, option.Some(stack.ValueEntry(runtime.Integer64(value: _))) -> Ok(stack.ValueEntry(runtime.false_))

            _, anything_else -> Error("gwr/execution/machine.integer_eqz: unexpected arguments \"" <> string.inspect(anything_else) <> "\"")
        }
    )
    let stack = stack.push(state.stack, [result])
    Ok(MachineState(..state, stack: stack))
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
        case option.values(values)
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
    use local <- result.try(
        case state.configuration.thread.framestate.locals |> list.take(up_to: index + 1) |> list.last
        {
            Ok(v) -> Ok(v)
            Error(_) -> Error("gwr/execution/machine.local_get: couldn't get the local with index " <> int.to_string(index))
        }
    )

    let stack = stack.push(state.stack, [stack.ValueEntry(local)])
    Ok(MachineState(..state, stack: stack))
}