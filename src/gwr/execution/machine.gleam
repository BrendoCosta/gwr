import gleam/dict
import gleam/list
import gleam/result

import gwr/execution/evaluator
import gwr/execution/runtime
import gwr/execution/stack
import gwr/execution/store
import gwr/execution/trap
import gwr/syntax/module

pub type Machine
{
    Machine(module_instance: runtime.ModuleInstance, stack: stack.Stack, store: store.Store)
}

pub fn initialize(from module: module.Module) -> Result(Machine, String)
{
    let store = store.Store
    (
        datas: [],
        elements: [],
        functions: dict.new(),
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
        function_addresses: store.functions
                            |> dict.to_list
                            |> list.map(fn (x) { #(runtime.address_to_int(x.0), x.0) })
                            |> dict.from_list,
        table_addresses: [],
        memory_addresses: list.index_map(store.memories, fn (_, index) { runtime.MemoryAddress(index) }),
        global_addresses: [],
        element_addresses: [],
        data_addresses: [],
        exports: [],
    )

    Ok(Machine(module_instance:, stack: stack.create(), store: update_references(from: store, with: module_instance)))
}

pub fn update_references(from store: store.Store, with new_module_instance: runtime.ModuleInstance) -> store.Store
{
    let updated_functions = dict.map_values(
        in: store.functions,
        with: fn (_address, function)
        {
            case function
            {
                runtime.WebAssemblyFunctionInstance(type_: type_, module_instance: _, code: code) -> runtime.WebAssemblyFunctionInstance(type_: type_, module_instance: new_module_instance, code: code)
                _ -> function
            }
        }
    )

    store.Store(..store, functions: updated_functions)
}

pub fn invoke(machine: Machine, address: runtime.Address, arguments: List(runtime.Value)) -> Result(#(Machine, List(runtime.Value)), trap.Trap)
{
    // Push the arguments to the stack
    let stack = stack.push(to: machine.stack, push: arguments |> list.map(fn (x) { stack.ValueEntry(x) }))

    // Invoke the function at given index
    use #(stack, store) <- result.try(evaluator.invoke(stack, machine.store, address))

    // Pop the results from the stack
    let #(stack, values) = stack.pop_while(from: stack, with: stack.is_value)
    let results = list.map(values, stack.to_value)
                  |> result.values
                  |> list.reverse
    Ok(#(Machine(..machine, stack:, store:), results))
}

