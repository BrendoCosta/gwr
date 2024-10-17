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

pub type Machine
{
    Machine(module_instance: runtime.ModuleInstance, state: MachineState)
}

pub type MachineState
{
    MachineState(store: store.Store, stack: stack.Stack)
}

pub type Jump
{
    Branch(target: List(instruction.Instruction))
    Return
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

    let state = MachineState
    (
        store: update_references(from: store, with: module_instance),
        stack: stack.create()
    )

    Ok(Machine(state: state, module_instance: module_instance))
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

pub fn return(state: MachineState) -> Result(#(MachineState, option.Option(Jump)), String)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: state.stack), "gwr/execution/machine.return: couldn't get the current frame"))
    // 2. Let n be the arity of F.
    let n = frame.arity
    // 3. Assert: due to validation, there are at least n values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: state.stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < n, return: Error("gwr/execution/machine.return: expected the top of the stack to contains at least " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top)))
    // 4. Pop the results {\mathit{val}}^n from the stack.
    let #(stack, results) = stack.pop_repeat(from: state.stack, up_to: n)
    // 5. Assert: due to validation, the stack contains at least one frame.
    use <- bool.guard(when: stack.get_entries(stack) |> list.filter(stack.is_activation_frame) |> list.length <= 0, return: Error("gwr/execution/machine.return: expected the stack to contains at least one frame"))
    // 6. While the top of the stack is not a frame, do:
    //     a. Pop the top element from the stack.
    let #(stack, _) = stack.pop_while(from: stack, with: fn (entry) { !stack.is_activation_frame(entry) })
    // 7. Assert: the top of the stack is the frame F.
    use <- bool.guard(when: stack.peek(stack) != option.Some(stack.ActivationEntry(frame)), return: Error("gwr/execution/machine.return: expected the top of the stack to be the current frame"))
    // 8. Pop the frame from the stack.
    let #(stack, _) = stack.pop(from: stack)
    // 9. Push {\mathit{val}}^n to the stack.
    let stack = stack.push(to: stack, push: results |> list.reverse)
    // 10. Jump to the instruction after the original call that pushed the frame.
    Ok(#(MachineState(..state, stack: stack), option.Some(Return)))
}

pub fn call(state: MachineState, index: index.FunctionIndex) -> Result(MachineState, String)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: state.stack), "gwr/execution/machine.call: couldn't get the current frame"))
    // 2. Assert: due to validation, F.{\mathsf{module}}.{\mathsf{funcaddrs}}[x] exists.
    // 3. Let a be the function address F.{\mathsf{module}}.{\mathsf{funcaddrs}}[x].
    use address <- result.try(result.replace_error(dict.get(frame.framestate.module_instance.function_addresses, index), "gwr/execution/machine.call: couldn't find the address of the function with index " <> int.to_string(index)))
    // 4. Invoke the function instance at address a.
    invoke(state, address)
}

pub fn invoke(state: MachineState, address: runtime.Address) -> Result(MachineState, String)
{
    // 1. Assert: due to validation, S.{\mathsf{funcs}}[a] exists.
    // 2. Let f be the function instance, S.{\mathsf{funcs}}[a].
    use function_instance <- result.try(result.replace_error(dict.get(state.store.functions, address), "gwr/execution/machine.invoke: couldn't find the function instance with address " <> runtime.address_to_string(address)))
    case function_instance
    {
        runtime.HostFunctionInstance(_, _) -> Error("@TODO: call host function")
        runtime.WebAssemblyFunctionInstance(type_: function_type, module_instance: function_module_instance, code: function_code) ->
        {
            // 3. Let [t_1^n] {\rightarrow} [t_2^m] be the function type f.{\mathsf{type}}.
            let n = list.length(function_type.parameters)
            let m = list.length(function_type.results)
            // 4. Let t^\ast be the list of value types f.{\mathsf{code}}.{\mathsf{locals}}.
            let function_locals_types = function_code.locals
            // 5. Let {\mathit{instr}}^\ast~{\mathsf{end}} be the expression f.{\mathsf{code}}.{\mathsf{body}}.
            let function_instructions = function_code.body
            // 6. Assert: due to validation, n values are on the top of the stack.
            let count_of_values_on_top = stack.count_on_top(from: state.stack, with: stack.is_value)
            use <- bool.guard(when: count_of_values_on_top < n, return: Error("gwr/execution/machine.invoke: expected the top of the stack to contains " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top)))
            // 7. Pop the values {\mathit{val}}^n from the stack.
            let #(stack, values) = stack.pop_repeat(from: state.stack, up_to: n)
            let values = list.map(values, stack.to_value)
                         |> result.values
                         |> list.reverse
            // 8. Let F be the frame \{ {\mathsf{module}}~f.{\mathsf{module}}, {\mathsf{locals}}~{\mathit{val}}^n~({\mathrm{default}}_t)^\ast \}.
            let framestate = runtime.FrameState
            (
                locals: values
                        |> list.append(list.map(function_locals_types, get_default_value_for_type)) // function's arguments will be joined with function's locals
                        |> list.index_map(fn (x, i) { #(i, x) })
                        |> dict.from_list,
                module_instance: function_module_instance
            )
            execute_with_frame(MachineState(..state, stack: stack), runtime.Frame(arity: m, framestate: framestate), function_instructions)
        }
    }
}

pub fn unwind_stack(state: MachineState) -> Result(MachineState, String)
{
    case stack.get_current_label(from: state.stack)
    {
        Ok(label) ->
        {
            use state <- result.try(exit_with_label(state, label))
            unwind_stack(state)
        }
        Error(_) -> Ok(state)
    }
}

pub fn execute_with_frame(state: MachineState, frame: runtime.Frame, instructions: List(instruction.Instruction)) -> Result(MachineState, String)
{
    // 9. Push the activation of F with arity m to the stack.
    let stack = stack.push(to: state.stack, push: [stack.ActivationEntry(frame)])
    // 10. Let L be the label whose arity is m and whose continuation is the end of the function.
    let label = runtime.Label(arity: frame.arity, continuation: [])
    // 11. Enter the instruction sequence {\mathit{instr}}^\ast with label L.
    use #(state, jump) <- result.try(enter_with_label(MachineState(..state, stack: stack), label, instructions, []))
    // Returning from a function
    case jump
    {
        option.Some(Return) -> Ok(state)
        _ ->
        {
            use state <- result.try(unwind_stack(state))
            // 1. Let F be the current frame.
            use frame <- result.try(result.replace_error(stack.get_current_frame(from: state.stack), "gwr/execution/machine.execute_with_frame: couldn't get the current frame"))
            // 2. Let n be the arity of the activation of F.
            let n = frame.arity
            // 3. Assert: due to validation, there are n values on the top of the stack.
            let count_of_values_on_top = stack.count_on_top(from: state.stack, with: stack.is_value)
            use <- bool.guard(when: count_of_values_on_top != n, return: Error("gwr/execution/machine.execute_with_frame: expected the top of the stack to contains " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top)))
            // 4. Pop the results {\mathit{val}}^n from the stack.
            let #(stack, values) = stack.pop_repeat(from: state.stack, up_to: n)
            // 5. Assert: due to validation, the frame F is now on the top of the stack.
            use <- bool.guard(when: stack.peek(stack) != option.Some(stack.ActivationEntry(frame)), return: Error("gwr/execution/machine.execute_with_frame: expected the current frame to be on the top of the stack"))
            // 6. Pop the frame F from the stack.
            let #(stack, _) = stack.pop(from: stack)
            // 7. Push {\mathit{val}}^n back to the stack.
            let stack = stack.push(to: stack, push: values |> list.reverse)
            // 8. Jump to the instruction after the original call.
            Ok(MachineState(..state, stack: stack))
        }
    }
}

pub fn br(state: MachineState, index: index.LabelIndex) -> Result(#(MachineState, option.Option(Jump)), String)
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

    // 6. Repeat l+1 times:
    use stack <- result.try(
        iterator.fold(
            from: Ok(stack),
            over: iterator.range(1, index + 1),
            with: fn (accumulator, _)
            {
                use stack <- result.try(accumulator)
                // a. While the top of the stack is a value, do:
                //     i. Pop the value from the stack.
                let #(stack, _) = stack.pop_while(from: stack, with: stack.is_value)
                // b. Assert: due to validation, the top of the stack now is a label.
                // c. Pop the label from the stack.
                case stack.pop(from: stack)
                {
                    #(stack, option.Some(stack.LabelEntry(_))) -> Ok(stack)
                    #(_, anything_else) -> Error("gwr/execution/machine.br: expected the top of the stack to contain a label but got " <> string.inspect(anything_else))
                }
            }
        )
    )

    // 7. Push the values {\mathit{val}}^n to the stack.
    let stack = stack.push(to: stack, push: values |> list.reverse)
    // 8. Jump to the continuation of L.
    Ok(#(MachineState(..state, stack: stack), option.Some(Branch(target: label.continuation))))
}

pub fn br_if(state: MachineState, index: index.LabelIndex) -> Result(#(MachineState, option.Option(Jump)), String)
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
                False -> Ok(#(state, option.None))
            }
        }
        _ -> Error("gwr/execution/machine.br_if: expected the top of the stack to contain an i32 value")
    }
}

pub fn loop(state: MachineState, block_type: instruction.BlockType, instructions: List(instruction.Instruction)) -> Result(#(MachineState, option.Option(Jump)), String)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: state.stack), "gwr/execution/machine.loop: couldn't get the current frame"))
    // 2. Assert: due to validation, {\mathrm{expand}}_F({\mathit{blocktype}}) is defined.
    // 3. Let [t_1^m] {\rightarrow} [t_2^n] be the function type {\mathrm{expand}}_F({\mathit{blocktype}}).
    use function_type <- result.try(expand_block_type(frame.framestate, block_type))
    let m = list.length(function_type.parameters)
    // 4. Let L be the label whose arity is m and whose continuation is the start of the loop.
    let label = runtime.Label(arity: m, continuation: [instruction.Loop(block_type: block_type, instructions: instructions)])
    // 5. Assert: due to validation, there are at least m values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: state.stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < m, return: Error("gwr/execution/machine.loop: expected the top of the stack to contains at least " <> int.to_string(m) <> " values but got " <> int.to_string(count_of_values_on_top)))
    // 6. Pop the values {\mathit{val}}^m from the stack.
    let #(stack, values) = stack.pop_repeat(from: state.stack, up_to: m)
    // 7. Enter the block {\mathit{val}}^m~{\mathit{instr}}^\ast with label L.
    enter_with_label(MachineState(..state, stack: stack), label, instructions, values |> list.reverse)
}

pub fn block(state: MachineState, block_type: instruction.BlockType, instructions: List(instruction.Instruction)) -> Result(#(MachineState, option.Option(Jump)), String)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: state.stack), "gwr/execution/machine.block: couldn't get the current frame"))
    // 2. Assert: due to validation, {\mathrm{expand}}_F({\mathit{blocktype}}) is defined.
    // 3. Let [t_1^m] {\rightarrow} [t_2^n] be the function type {\mathrm{expand}}_F({\mathit{blocktype}}).
    use function_type <- result.try(expand_block_type(frame.framestate, block_type))
    let m = list.length(function_type.parameters)
    let n = list.length(function_type.results)
    // 4. Let L be the label whose arity is n and whose continuation is the end of the block.
    let label = runtime.Label(arity: n, continuation: [])
    // 5. Assert: due to validation, there are at least m values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: state.stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < m, return: Error("gwr/execution/machine.block: expected the top of the stack to contains at least " <> int.to_string(m) <> " values but got " <> int.to_string(count_of_values_on_top)))
    // 6. Pop the values {\mathit{val}}^m from the stack.
    let #(stack, values) = stack.pop_repeat(from: state.stack, up_to: m)
    // 7. Enter the block {\mathit{val}}^m~{\mathit{instr}}^\ast with label L.
    enter_with_label(MachineState(..state, stack: stack), label, instructions, values |> list.reverse)
}

pub fn enter_with_label(state: MachineState, label: runtime.Label, instructions: List(instruction.Instruction), parameters: List(stack.StackEntry)) -> Result(#(MachineState, option.Option(Jump)), String)
{
    let state = MachineState(..state, stack: stack.push(to: state.stack, push: [stack.LabelEntry(label)] |> list.append(parameters)))
    evaluate_expression(state, instructions)
}

pub fn exit_with_label(state: MachineState, label: runtime.Label) -> Result(MachineState, String)
{
    // 1. Pop all values {\mathit{val}}^\ast from the top of the stack.
    let #(stack, values) = stack.pop_while(from: state.stack, with: stack.is_value)
    // 2. Assert: due to validation, the label L is now on the top of the stack.
    // 3. Pop the label from the stack.
    use stack <- result.try(
        case stack.pop(stack)
        {
            #(stack, option.Some(stack.LabelEntry(some_label))) if some_label == label -> Ok(stack)
            #(_, anything_else) -> Error("gwr/execution/machine.exit_with_label: expected the label " <> string.inspect(label) <> " pushed to the stack before execution but got " <> string.inspect(anything_else))
        }
    )
    // 4. Push {\mathit{val}}^\ast back to the stack.
    let state = MachineState(..state, stack: stack.push(to: stack, push: values |> list.reverse))
    // 5. Jump to the position after the {\mathsf{end}} of the structured control instruction associated with the label L.
    Ok(state)
}

pub fn evaluate_expression(state: MachineState, instructions: List(instruction.Instruction)) -> Result(#(MachineState, option.Option(Jump)), String)
{
    case instructions
    {
        [] -> Ok(#(state, option.None))
        _ ->
        {
            use instruction <- result.try(result.replace_error(list.first(instructions), "gwr/execution/machine.evaluate_expression: couldn't get the current instruction"))
            use #(state, jump) <- result.try(
                case instruction
                {
                    instruction.Block(block_type:, instructions:) -> block(state, block_type, instructions)
                    instruction.If(block_type:, instructions:, else_: else_) -> if_else(state, block_type, instructions, else_)
                    instruction.Loop(block_type:, instructions:) -> loop(state, block_type, instructions)
                    instruction.Br(index:) -> br(state, index)
                    instruction.BrIf(index:) -> br_if(state, index)
                    instruction.Return -> return(state)
                    _ -> result.map(
                        case instruction {
                            instruction.End -> Ok(state)
                            instruction.Call(index:) -> call(state, index)

                            instruction.I32Const(value) -> integer_const(state, types.Integer32, value)
                            instruction.I64Const(value) -> integer_const(state, types.Integer64, value)
                            instruction.F32Const(value) -> float_const(state, types.Float32, value)
                            instruction.F64Const(value) -> float_const(state, types.Float64, value)
                            instruction.I32Eqz -> integer_eqz(state, types.Integer32)
                            instruction.I32Eq  -> integer_eq(state, types.Integer32)
                            instruction.I32Ne  -> integer_ne(state, types.Integer32)
                            instruction.I32LtS -> integer_lt_s(state, types.Integer32)
                            instruction.I32LtU -> integer_lt_u(state, types.Integer32)
                            instruction.I32GtS -> integer_gt_s(state, types.Integer32)
                            instruction.I32GtU -> integer_gt_u(state, types.Integer32)
                            instruction.I32LeS -> integer_le_s(state, types.Integer32)
                            instruction.I32LeU -> integer_le_u(state, types.Integer32)
                            instruction.I32GeS -> integer_ge_s(state, types.Integer32)
                            instruction.I32GeU -> integer_ge_u(state, types.Integer32)
                            instruction.I64Eqz -> integer_eqz(state, types.Integer64)
                            instruction.I64Eq  -> integer_eq(state, types.Integer64)
                            instruction.I64Ne  -> integer_ne(state, types.Integer64)
                            instruction.I64LtS -> integer_lt_s(state, types.Integer64)
                            instruction.I64LtU -> integer_lt_u(state, types.Integer64)
                            instruction.I64GtS -> integer_gt_s(state, types.Integer64)
                            instruction.I64GtU -> integer_gt_u(state, types.Integer64)
                            instruction.I64LeS -> integer_le_s(state, types.Integer64)
                            instruction.I64LeU -> integer_le_u(state, types.Integer64)
                            instruction.I64GeS -> integer_ge_s(state, types.Integer64)
                            instruction.I64GeU -> integer_ge_u(state, types.Integer64)
                            instruction.F32Eq  -> float_eq(state, types.Float32)
                            instruction.F32Ne  -> float_ne(state, types.Float32)
                            instruction.F32Lt  -> float_lt(state, types.Float32)
                            instruction.F32Gt  -> float_gt(state, types.Float32)
                            instruction.F32Le  -> float_le(state, types.Float32)
                            instruction.F32Ge  -> float_ge(state, types.Float32)
                            instruction.F64Eq  -> float_eq(state, types.Float64)
                            instruction.F64Ne  -> float_ne(state, types.Float64)
                            instruction.F64Lt  -> float_lt(state, types.Float64)
                            instruction.F64Gt  -> float_gt(state, types.Float64)
                            instruction.F64Le  -> float_le(state, types.Float64)
                            instruction.F64Ge  -> float_ge(state, types.Float64)

                            instruction.I32Clz -> integer_clz(state, types.Integer32)
                            instruction.I64Clz -> integer_clz(state, types.Integer64)
                            instruction.I32Ctz -> integer_ctz(state, types.Integer32)
                            instruction.I64Ctz -> integer_ctz(state, types.Integer64)
                            instruction.I32Popcnt -> integer_popcnt(state, types.Integer32)
                            instruction.I64Popcnt -> integer_popcnt(state, types.Integer64)
                            
                            instruction.LocalGet(index) -> local_get(state, index)
                            instruction.LocalSet(index) -> local_set(state, index)
                            instruction.I32Add -> integer_add(state, types.Integer32)
                            instruction.I64Add -> integer_add(state, types.Integer64)
                            instruction.I32Sub -> integer_sub(state, types.Integer32)
                            instruction.I64Sub -> integer_sub(state, types.Integer64)
                            unknown -> Error("gwr/execution/machine.evaluate_expression: attempt to execute an unknown or unimplemented instruction \"" <> string.inspect(unknown) <> "\"")
                        },
                        fn (state) { #(state, option.None) }
                    )
                }
            )
            case jump
            {
                option.Some(Return) -> Ok(#(state, jump))
                option.Some(Branch(target: instructions)) -> evaluate_expression(state, instructions)
                option.None -> evaluate_expression(state, instructions |> list.drop(1))
            }
        }
    }
}

pub fn if_else(state: MachineState, block_type: instruction.BlockType, if_instructions: List(instruction.Instruction), else_: option.Option(instruction.Instruction)) -> Result(#(MachineState, option.Option(Jump)), String)
{
    // 1. Assert: due to validation, a value of value type {\mathsf{i32}} is on the top of the stack.
    // 2. Pop the value {\mathsf{i32}}.{\mathsf{const}}~c from the stack.
    case stack.pop_as(from: state.stack, with: stack.to_value)
    {
        Ok(#(stack, runtime.Integer32(c))) ->
        {
            let state = MachineState(..state, stack: stack)
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
                    option.None -> Ok(#(state, option.None))
                    anything_else -> Error("gwr/execution/machine.if_else: illegal instruction in the Else's field " <> string.inspect(anything_else))
                }
            }
        }
        anything_else -> Error("gwr/execution/machine.if_else: expected the If's continuation flag but got " <> string.inspect(anything_else))
    }
}

pub fn expand_block_type(framestate: runtime.FrameState, block_type: instruction.BlockType) -> Result(types.FunctionType, String)
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
                use result <- result.try(handler(a, b))
                // Do operations with 64 bit, demote it to 32 bit if necessary
                case type_, result
                {
                    types.Integer32, runtime.Integer64(v) -> Ok(runtime.Integer32(v))
                    _, _ -> Ok(result)
                }
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

/// Return the result of adding i_1 and i_2 modulo 2^N.
/// 
/// \begin{array}{@{}lcll}{\mathrm{iadd}}_N(i_1, i_2) &=& (i_1 + i_2) \mathbin{\mathrm{mod}} 2^N\end{array}
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html#xref-exec-numerics-op-iadd-mathrm-iadd-n-i-1-i-2
pub fn integer_add(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        let m = int.absolute_value(2 * int.bitwise_shift_left(1, get_bitwidth(type_) - 1))
        Ok(runtime.Integer64({ a + b } % m))
    }))
}

/// Return the result of subtracting i_2 from i_1 modulo 2^N.
/// 
/// \begin{array}{@{}lcll}{\mathrm{isub}}_N(i_1, i_2) &=& (i_1 - i_2 + 2^N) \mathbin{\mathrm{mod}} 2^N\end{array}
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html#xref-exec-numerics-op-isub-mathrm-isub-n-i-1-i-2
pub fn integer_sub(state: MachineState, type_: types.NumberType) -> Result(MachineState, String)
{
    binary_operation(state, type_, IntegerBinaryOperation(fn (a, b) {
        let m = int.absolute_value(2 * int.bitwise_shift_left(1, get_bitwidth(type_) - 1))
        Ok(runtime.Integer64({ a - b + m } % m))
    }))
}

pub fn local_get(state: MachineState, index: index.LocalIndex) -> Result(MachineState, String)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: state.stack), "gwr/execution/machine.local_get: couldn't get the current frame"))
    // 2. Assert: due to validation, F.{\mathsf{locals}}[x] exists.
    // 3. Let {\mathit{val}} be the value F.{\mathsf{locals}}[x].
    use local <- result.try(result.replace_error(dict.get(frame.framestate.locals, index), "gwr/execution/machine.local_get: couldn't get the local with index " <> int.to_string(index)))
    // 4. Push the value {\mathit{val}} to the stack.
    let stack = stack.push(state.stack, [stack.ValueEntry(local)])
    Ok(MachineState(..state, stack: stack))
}

pub fn local_set(state: MachineState, index: index.LocalIndex) -> Result(MachineState, String)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: state.stack), "gwr/execution/machine.local_set: couldn't get the current frame"))
    // 2. Assert: due to validation, F.locals[x] exists.
    use _ <- result.try(result.replace_error(dict.get(frame.framestate.locals, index), "gwr/execution/machine.local_set: couldn't get the local with index " <> int.to_string(index)))
    
    // 3. Assert: due to validation, a value is on the top of the stack.
    // 4. Pop the value val from the stack.
    use #(stack, value) <- result.try(stack.pop_as(from: state.stack, with: stack.to_value))

    // 5. Replace F.locals[x] with the value val.
    use stack <- result.try(
        result.replace_error(
            stack.replace_current_frame(
                from: stack,
                with: runtime.Frame
                (
                    ..frame,
                    framestate: runtime.FrameState
                    (
                        ..frame.framestate,
                        locals: dict.insert(into: frame.framestate.locals, for: index, insert: value)
                    )
                )
            ),
            "gwr/execution/machine.local_set: couldn't update the current frame"
        )
    )
    Ok(MachineState(..state, stack: stack))
}