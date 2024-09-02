import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/option

import gwr/execution/runtime
import gwr/execution/stack
import gwr/syntax/index
import gwr/syntax/instruction
import gwr/syntax/module
import gwr/syntax/types

/// A configuration consists of the current store and an executing thread.
/// 
/// https://webassembly.github.io/spec/core/exec/runtime.html#configurations
pub type Configuration
{
    Configuration(store: runtime.Store, thread: Thread)
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
    let module_instance = runtime.ModuleInstance
    (
        types: module.types,
        function_addresses: [],
        table_addresses: [],
        memory_addresses: [],
        global_addresses: [],
        element_addresses: [],
        data_addresses: [],
        exports: [],
    )

    let config = Configuration
    (
        store: runtime.Store
        (
            datas: [],
            elements: [],
            functions: [],
            globals: [],
            memories: [],
            tables: [],
        ),
        thread: Thread(
            framestate: stack.FrameState(
                locals: [],
                module_instance: module_instance
            ),
            instructions: []
        )
    )

    let stack = stack.create()

    // Allocates web aseembly functions

    use #(store, allocations) <- result.try(
        list.fold(
            from: Ok(#(config.store, [])),
            over: module.functions,
            with: fn (state, function)
            {
                use #(store, allocations) <- result.try(state)
                allocate_web_assembly_function(function, store, allocations, module.types)
            }
        )
    )

    let module_instance = runtime.ModuleInstance(..module_instance, function_addresses: allocations)

    let results = list.filter_map(store.functions, fn (function) {
        case function
        {
            runtime.WebAssemblyFunctionInstance(type_: type_, module_instance: _, code: code) -> Ok(runtime.WebAssemblyFunctionInstance(type_: type_, module_instance: module_instance, code: code))
            _ -> Error(Nil)
        }
    })

    let store = runtime.Store(..store, functions: results)
    // We need to update the thread's framestate's module_instance too
    let thread = Thread(..config.thread, framestate: stack.FrameState(..config.thread.framestate, module_instance: module_instance))

    Ok(Machine(state: MachineState(configuration: Configuration(store: store, thread: thread), stack: stack), module_instance: module_instance))

}

// Should be the last to be allocated due to WebAssemblyFunctionInstance requering
// a reference to the full initialized ModuleInstance

pub fn allocate_web_assembly_function(function: module.Function, store: runtime.Store, addresses: List(runtime.Address), types_list: List(types.FunctionType)) -> Result(#(runtime.Store, List(runtime.Address)), String)
{
    let empty_module_instance = runtime.ModuleInstance
    (
        types: [],
        function_addresses: [],
        table_addresses: [],
        memory_addresses: [],
        global_addresses: [],
        element_addresses: [],
        data_addresses: [],
        exports: [],
    )

    let function_address = runtime.FunctionAddress(list.length(addresses))
    case types_list |> list.take(up_to: function.type_ + 1) |> list.last
    {
        Ok(function_type) ->
        {
            Ok(
                #(
                    runtime.Store(..store, functions: list.append(store.functions, [runtime.WebAssemblyFunctionInstance(type_: function_type, module_instance: empty_module_instance, code: function)])),
                    list.append(addresses, [function_address])
                )
            )
        }
        Error(_) -> Error("gwr/execution/machine.allocate_web_assembly_function: couldn't find the type of the function among module instance's types list")
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
            let function_locals = list.fold(
                from: arguments, // function's arguments will be joined with function's locals
                over: function_code.locals,
                with: fn (function_locals, local) {
                let value = case local
                {
                    types.Number(types.Integer32) -> runtime.Number(runtime.number_value_default_value)
                    types.Number(types.Integer64) -> runtime.Number(runtime.number_value_default_value)
                    types.Number(types.Float32) -> runtime.Number(runtime.number_value_default_value)
                    types.Number(types.Float64) -> runtime.Number(runtime.number_value_default_value)
                    types.Vector(types.Vector128) -> runtime.Vector(runtime.vector_value_default_value)
                    types.Reference(types.FunctionReference) -> runtime.Reference(runtime.Null)
                    types.Reference(types.ExternReference) -> runtime.Reference(runtime.Null)
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
            let new_state_stack = stack.push(push: stack.ActivationEntry(function_frame), to: state.stack)
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
                    instruction.LocalGet(index) -> local_get(current_state, index)
                    instruction.I32Add -> i32_add(current_state)
                    instruction.I32Const(value) -> i32_const(current_state, value)
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

pub fn i32_add(state: MachineState) -> Result(MachineState, String)
{
    let #(stack, values) = stack.pop_repeat(state.stack, 2)
    use result <- result.try(
        case option.values(values)
        {
            [stack.ValueEntry(runtime.Number(a)), stack.ValueEntry(runtime.Number(b))] -> Ok(a + b)
            [stack.LabelEntry(_), _] | [_, stack.LabelEntry(_)] -> Error("gwr/execution/machine.i32_add: expected a value entry but got a label entry")
            [stack.ActivationEntry(_), _] | [_, stack.ActivationEntry(_)] -> Error("gwr/execution/machine.i32_add: expected a value entry but got an activation entry")
            [] -> Error("gwr/execution/machine.i32_add: empty operands")
            _ -> Error("gwr/execution/machine.i32_add: unknown error")
        }
    )
    Ok(
        MachineState(
            ..state,
            stack: stack.push(stack, stack.ValueEntry(runtime.Number(result)))
        )
    )
}

pub fn i32_const(state: MachineState, value: Int)
{
    Ok(
        MachineState(
            ..state,
            stack: stack.push(state.stack, stack.ValueEntry(runtime.Number(value)))
        )
    )
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
    Ok(
        MachineState(
            ..state,
            stack: stack.push(state.stack, stack.ValueEntry(local))
        )
    )
}