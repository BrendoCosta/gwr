import gleam/list
import gleam/result

import gwr/exec
import gwr/exec/trap
import gwr/parser
import gwr/parser/byte_reader
import gwr/parser/parsing_error
import gwr/spec

pub type WebAssemblyInstance
{
    WebAssemblyInstance
    (
        binary: spec.Binary,
        machine: exec.Machine
    )
}

pub fn load(from data: BitArray) -> Result(spec.Binary, parsing_error.ParsingError)
{
    use #(_, binary) <- result.try(parser.parse_binary_module(byte_reader.create(from: data)))
    Ok(binary)
}

pub fn create(from binary: spec.Binary) -> Result(WebAssemblyInstance, String)
{
    use machine <- result.try(exec.initialize(binary.module))
    Ok(WebAssemblyInstance(binary: binary, machine: machine))
}

pub fn call(instance: WebAssemblyInstance, name: String, arguments: List(spec.Value)) -> Result(#(WebAssemblyInstance, List(spec.Value)), trap.Trap)
{
    use function_index <- result.try(
        case list.find(in: instance.binary.module.exports, one_that: fn (export) {
            case export.name == name, export.descriptor
            {
                True, spec.FunctionExport(_) -> True
                _, _ -> False
            }
        })
        {
            Ok(spec.Export(name: _, descriptor: spec.FunctionExport(index))) -> Ok(index)
            _ -> trap.make(trap.Unknown)
                 |> trap.add_message("gwr/gwr.call: couldn't find an exported function with name \"" <> name <>"\" in the given module")
                 |> trap.to_error()
        }
    )

    use #(machine, results) <- result.try(exec.invoke(instance.machine, spec.FunctionAddress(function_index), arguments))

    Ok(#(WebAssemblyInstance(..instance, machine:), results))
}