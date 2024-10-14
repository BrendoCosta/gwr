import gleam/list
import gleam/result

import gwr/binary
import gwr/execution/machine
import gwr/execution/runtime
import gwr/execution/stack
import gwr/parser/binary_parser
import gwr/parser/byte_reader
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
    use #(_, binary) <- result.try(binary_parser.parse_binary_module(byte_reader.create(from: data)))
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
            _ -> Error("gwr/gwr.call: couldn't find an exported function with name \"" <> name <>"\" in the given module")
        }
    )

    // Push the arguments to the stack
    let state = machine.MachineState
    (
        ..instance.machine.state,
        stack: stack.push(to: instance.machine.state.stack, push: arguments |> list.map(fn (x) { stack.ValueEntry(x) }))
    )

    // Invoke the function at given index
    use state <- result.try(machine.invoke(state, runtime.FunctionAddress(function_index)))

    // Pop the results from the stack
    let #(stack, values) = stack.pop_while(from: state.stack, with: stack.is_value)
    let results = list.map(values, stack.to_value)
                  |> result.values
                  |> list.reverse

    Ok(#(WebAssemblyInstance(..instance, machine: machine.Machine(..instance.machine, state: machine.MachineState(..state, stack: stack))), results))
}