import gleam/list
import gleam/result

import gwr/binary
import gwr/execution/machine
import gwr/execution/runtime
import gwr/execution/trap
import gwr/parser/binary_parser
import gwr/parser/byte_reader
import gwr/parser/parsing_error
import gwr/syntax/module

pub type WebAssemblyInstance
{
    WebAssemblyInstance
    (
        binary: binary.Binary,
        machine: machine.Machine
    )
}

pub fn load(from data: BitArray) -> Result(binary.Binary, parsing_error.ParsingError)
{
    use #(_, binary) <- result.try(binary_parser.parse_binary_module(byte_reader.create(from: data)))
    Ok(binary)
}

pub fn create(from binary: binary.Binary) -> Result(WebAssemblyInstance, String)
{
    use machine <- result.try(machine.initialize(binary.module))
    Ok(WebAssemblyInstance(binary: binary, machine: machine))
}

pub fn call(instance: WebAssemblyInstance, name: String, arguments: List(runtime.Value)) -> Result(#(WebAssemblyInstance, List(runtime.Value)), trap.Trap)
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
            _ -> trap.make(trap.Unknown)
                 |> trap.add_message("gwr/gwr.call: couldn't find an exported function with name \"" <> name <>"\" in the given module")
                 |> trap.to_error()
        }
    )

    use #(machine, results) <- result.try(machine.invoke(instance.machine, runtime.FunctionAddress(function_index), arguments))

    Ok(#(WebAssemblyInstance(..instance, machine:), results))
}