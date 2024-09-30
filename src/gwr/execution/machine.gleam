import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/option
import gleam/order

import gwr/execution/runtime
import gwr/execution/stack
import gwr/execution/store
import gwr/syntax/index
import gwr/syntax/instruction
import gwr/syntax/module
import gwr/syntax/types

import ieee_float
import ranged_int/builtin/int32
import ranged_int/builtin/uint32

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
            let function_frame = stack.ActivationFrame
            (
                arity: list.length(function_type.results), // "[...] Activation frames carry the return arity <n> of the respective function [...]"
                framestate: stack.FrameState
                (
                    locals: function_locals,
                    module_instance: function_module_instance
                )
            )
            let new_state_stack = stack.push(push: [stack.ActivationEntry(function_frame)], to: state.stack)
            let new_state_configuration = Configuration(..state.configuration, thread: Thread(framestate: function_frame.framestate, instructions: function_code.body))
            let new_state = MachineState(configuration: new_state_configuration, stack: new_state_stack)

            use after_state <- result.try(execute(new_state))

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

pub fn execute(current_state: MachineState) -> Result(MachineState, String)
{
    use new_state <- result.try(
        list.fold(
            from: Ok(current_state),
            over: current_state.configuration.thread.instructions,
            with: fn (current_state, instruction)
            {
                use current_state <- result.try(current_state)
                case instruction
                {
                    instruction.I32Const(value) -> i32_const(current_state, value)
                    instruction.I64Const(value) -> i64_const(current_state, value)
                    instruction.F32Const(value) -> f32_const(current_state, value)
                    instruction.F64Const(value) -> f64_const(current_state, value)
                    instruction.I32Eqz -> i32_eqz(current_state)
                    instruction.I32Eq -> i32_eq(current_state)
                    instruction.I32Ne -> i32_ne(current_state)
                    instruction.I32LtS -> i32_lt_s(current_state)
                    instruction.I32LtU -> i32_lt_u(current_state)

                    instruction.LocalGet(index) -> local_get(current_state, index)
                    instruction.I32Add -> i32_add(current_state)
                    _ -> Ok(current_state)
                }
            }
        )
    )

    Ok(new_state)
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

pub fn i32_const(state: MachineState, value: Int) -> Result(MachineState, String)
{
    let stack = stack.push(state.stack, [stack.ValueEntry(runtime.Integer32(value))])
    Ok(MachineState(..state, stack: stack))
}

pub fn i64_const(state: MachineState, value: Int) -> Result(MachineState, String)
{
    let stack = stack.push(state.stack, [stack.ValueEntry(runtime.Integer64(value))])
    Ok(MachineState(..state, stack: stack))
}

pub fn f32_const(state: MachineState, value: ieee_float.IEEEFloat) -> Result(MachineState, String)
{
    use built_in_float <- result.try(runtime.ieee_float_to_builtin_float(value))
    let stack = stack.push(state.stack, [stack.ValueEntry(runtime.Float32(built_in_float))])
    Ok(MachineState(..state, stack: stack))
}

pub fn f64_const(state: MachineState, value: ieee_float.IEEEFloat) -> Result(MachineState, String)
{
    use built_in_float <- result.try(runtime.ieee_float_to_builtin_float(value))
    let stack = stack.push(state.stack, [stack.ValueEntry(runtime.Float64(built_in_float))])
    Ok(MachineState(..state, stack: stack))
}

pub fn i32_eqz(state: MachineState) -> Result(MachineState, String)
{
    let #(stack, entry) = stack.pop(state.stack)
    use result <- result.try(
        case entry
        {
            option.Some(stack.ValueEntry(runtime.Integer32(value: 0))) -> Ok(stack.ValueEntry(runtime.true_))
            option.Some(stack.ValueEntry(runtime.Integer32(value: _))) -> Ok(stack.ValueEntry(runtime.false_))
            anything_else -> Error("gwr/execution/machine.i32_eqz: unexpected arguments \"" <> string.inspect(anything_else) <> "\"")
        }
    )
    let stack = stack.push(state.stack, [result])
    Ok(MachineState(..state, stack: stack))
}

pub fn i32_comparison(state: MachineState, comparison_function: fn (Int, Int) -> Result(Bool, String)) -> Result(MachineState, String)
{
    let #(stack, values) = stack.pop_repeat(state.stack, 2)
    use result <- result.try(
        case option.values(values)
        {
            [stack.ValueEntry(runtime.Integer32(value: b)), stack.ValueEntry(runtime.Integer32(value: a))] ->
            {
                case comparison_function(a, b)
                {
                    Ok(True) -> Ok(runtime.true_)
                    Ok(False) -> Ok(runtime.false_)
                    Error(reason) -> Error("gwr/execution/machine.i32_comparison: couldn't compare operands: " <> reason)
                }
            }
            anything_else -> Error("gwr/execution/machine.i32_comparison: unexpected arguments \"" <> string.inspect(anything_else) <> "\"")
        }
    )

    let stack = stack.push(stack, [stack.ValueEntry(result)])
    Ok(MachineState(..state, stack: stack))
}

pub fn i32_eq(state: MachineState) -> Result(MachineState, String)
{
    i32_comparison(state, fn (a, b) { Ok(a == b) })
}

pub fn i32_ne(state: MachineState) -> Result(MachineState, String)
{
    i32_comparison(state, fn (a, b) { Ok(a != b) })
}

pub fn i32_lt_s(state: MachineState) -> Result(MachineState, String)
{
    i32_comparison(state, fn (a, b) {
        use #(a, b) <- result.try(
            result.replace_error(
                {
                    use a <- result.try(int32.from_int(a))
                    use b <- result.try(int32.from_int(b))
                    Ok(#(a, b))
                },
                "gwr/execution/machine.i32_lt_s: overflow"
            )
        )
        case int32.compare(a, b)
        {
            order.Lt -> Ok(True)
            _ -> Ok(False)
        }
    })
}

pub fn i32_lt_u(state: MachineState) -> Result(MachineState, String)
{
    i32_comparison(state, fn (a, b) {
        use #(a, b) <- result.try(
            result.replace_error(
                {
                    use a <- result.try(uint32.from_int(a))
                    use b <- result.try(uint32.from_int(b))
                    Ok(#(a, b))
                },
                "gwr/execution/machine.i32_lt_u: overflow"
            )
        )
        case uint32.compare(a, b)
        {
            order.Lt -> Ok(True)
            _ -> Ok(False)
        }
    })
}

pub fn i32_gt_s(state: MachineState) -> Result(MachineState, String)
{
    i32_comparison(state, fn (a, b) {
        use #(a, b) <- result.try(
            result.replace_error(
                {
                    use a <- result.try(int32.from_int(a))
                    use b <- result.try(int32.from_int(b))
                    Ok(#(a, b))
                },
                "gwr/execution/machine.i32_gt_s: overflow"
            )
        )
        case int32.compare(a, b)
        {
            order.Gt -> Ok(True)
            _ -> Ok(False)
        }
    })
}

pub fn i32_gt_u(state: MachineState) -> Result(MachineState, String)
{
    i32_comparison(state, fn (a, b) {
        use #(a, b) <- result.try(
            result.replace_error(
                {
                    use a <- result.try(uint32.from_int(a))
                    use b <- result.try(uint32.from_int(b))
                    Ok(#(a, b))
                },
                "gwr/execution/machine.i32_gt_u: overflow"
            )
        )
        case uint32.compare(a, b)
        {
            order.Gt -> Ok(True)
            _ -> Ok(False)
        }
    })
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