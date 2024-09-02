import gleam/list
import gleam/result

import gwr/binary
import gwr/execution/machine
import gwr/execution/runtime
import gwr/parser/binary_parser
import gwr/parser/binary_reader
import gwr/syntax/module

pub type WebAssemblyInstance
{
    WebAssemblyInstance
    (
        binary: binary.Binary,
        machine: machine.Machine
    )
}

pub fn create(from data: BitArray) -> Result(WebAssemblyInstance, String)
{
    use #(_, binary) <- result.try(binary_parser.parse_binary_module(binary_reader.create(from: data)))
    use machine <- result.try(machine.initialize(binary.module))
    Ok(WebAssemblyInstance(binary: binary, machine: machine))
}

pub fn call(instance: WebAssemblyInstance, name: String, arguments: List(runtime.Value)) -> Result(#(WebAssemblyInstance, List(runtime.Value)), String)
{
    use function_index <- result.try(
        case list.find(in: instance.binary.module.exports, one_that: fn (export) {
            case export.name == name, export.descriptor
            {
                True, module.FunctionExport(_) -> True
                _, _ -> False
            }
        })
        {
            Ok(module.Export(name: _, descriptor: module.FunctionExport(index))) -> Ok(index)
            _ -> Error("gwr/execution/instance.call: couldn't find an exported function with name \"" <> name <>"\" in the given module")
        }
    )

    use #(new_state, results) <- result.try(machine.call(instance.machine.state, function_index, arguments))
    Ok(#(WebAssemblyInstance(..instance, machine: machine.Machine(..instance.machine, state: new_state)), results))
}