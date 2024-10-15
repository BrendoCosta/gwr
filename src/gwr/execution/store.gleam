import gleam/dict
import gleam/list

import gwr/execution/runtime
import gwr/syntax/module
import gwr/syntax/types

/// The store represents all global state that can be manipulated by WebAssembly programs.
/// It consists of the runtime representation of all instances of functions, tables, memories,
/// and globals, element segments, and data segments that have been allocated during the
/// life time of the abstract machine.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#store
pub type Store
{
    Store
    (
        functions: dict.Dict(runtime.Address, runtime.FunctionInstance),
        tables: List(runtime.TableInstance),
        memories: List(runtime.MemoryInstance),
        globals: List(runtime.GlobalInstance),
        elements: List(runtime.ElementInstance),
        datas: List(runtime.DataInstance),
    )
}

pub fn append_web_assembly_function(to store: Store, append function: module.Function, using types_list: List(types.FunctionType)) -> Result(Store, String)
{
    let empty_module_instance = runtime.ModuleInstance
    (
        types: [],
        function_addresses: dict.new(),
        table_addresses: [],
        memory_addresses: [],
        global_addresses: [],
        element_addresses: [],
        data_addresses: [],
        exports: [],
    )

    let function_address = runtime.FunctionAddress(dict.keys(store.functions) |> list.length)

    case types_list |> list.take(up_to: function.type_ + 1) |> list.last
    {
        Ok(function_type) -> Ok(Store(..store, functions: dict.insert(into: store.functions, for: function_address, insert: runtime.WebAssemblyFunctionInstance(type_: function_type, module_instance: empty_module_instance, code: function))))
        Error(_) -> Error("gwr/execution/store.append_web_assembly_function: couldn't find the type of the function among types list")
    }
}

pub fn append_memory(to store: Store, append memory: module.Memory) -> Store
{
    let memory_data = <<0x00:size(memory.type_.min * runtime.memory_page_size)>>
    Store(..store, memories: list.append(store.memories, [runtime.MemoryInstance(type_: memory.type_, data: memory_data)]))
}
