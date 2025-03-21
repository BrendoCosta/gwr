import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/yielder

import gwr/execution/numerics
import gwr/execution/runtime
import gwr/execution/stack
import gwr/execution/store
import gwr/execution/trap
import gwr/syntax/index
import gwr/syntax/instruction
import gwr/syntax/types

import ieee_float

pub type ConstValue
{
    IntegerConstValue(value: Int)
    FloatConstValue(value: ieee_float.IEEEFloat)
}

pub type UnaryOperationType
{
    IntegerUnaryOperation(fn (types.NumberType, Int) -> Result(Int, trap.Trap))
    FloatUnaryOperation(fn (ieee_float.IEEEFloat) -> Result(runtime.Value, trap.Trap))
}

pub type BinaryOperationType
{
    IntegerBinaryOperation(fn (types.NumberType, Int, Int) -> Result(Int, trap.Trap))
    FloatBinaryOperation(fn (ieee_float.IEEEFloat, ieee_float.IEEEFloat) -> Result(runtime.Value, trap.Trap))
}

pub type TestOperationType
{
    IntegerTestOperation(fn (Int) -> Result(Int, trap.Trap))
    FloatTestOperation(fn (ieee_float.IEEEFloat) -> Result(Int, trap.Trap))
}

pub type ComparisonOperationType
{
    IntegerComparisonOperation(fn (types.NumberType, Int, Int) -> Result(Int, trap.Trap))
    FloatComparisonOperation(fn (ieee_float.IEEEFloat, ieee_float.IEEEFloat) -> Result(Int, trap.Trap))
}

pub type Jump
{
    Branch(target: List(instruction.Instruction))
    Return
}

/// https://webassembly.github.io/spec/core/exec/instructions.html#t-mathsf-xref-syntax-instructions-syntax-unop-mathit-unop
fn unary_operation(stack: stack.Stack, type_: types.NumberType, operation_type: UnaryOperationType) -> Result(stack.Stack, trap.Trap)
{
    // 1. Assert: due to validation, a value of value type t is on the top of the stack.
    // 2. Pop the value t.{\mathsf{const}}~c_1 from the stack.
    let #(stack, values) = stack.pop(stack)
    use c <- result.try(
        case type_, operation_type, values
        {
            // 3. If {\mathit{unop}}_t(c_1) is defined, then:
            //      3a. Let c be a possible result of computing {\mathit{unop}}_t(c_1).
              types.Integer32, IntegerUnaryOperation(unop), option.Some(stack.ValueEntry(runtime.Integer32(c1))) 
            | types.Integer64, IntegerUnaryOperation(unop), option.Some(stack.ValueEntry(runtime.Integer64(c1))) ->
            {
                use c <- result.try(unop(type_, c1))
                // Do operations with 64 bit, demote it to 32 bit if necessary
                case type_
                {
                    types.Integer32 -> Ok(runtime.Integer32(c))
                    _ -> Ok(runtime.Integer64(c))
                }
            }
              types.Float32, FloatUnaryOperation(unop), option.Some(stack.ValueEntry(runtime.Float32(c1)))
            | types.Float64, FloatUnaryOperation(unop), option.Some(stack.ValueEntry(runtime.Float64(c1))) ->
            {
                unop(runtime.builtin_float_to_ieee_float(c1))
            }
            // 4. Else:
            //      4a. Trap
            t, h, args -> trap.make(trap.BadArgument)
                          |> trap.add_message(string.inspect(#(t, h, args)))
                          |> trap.to_error()
        }
    )
    // 3b. Push the value t.{\mathsf{const}}~c to the stack.
    Ok(stack.push(stack, [stack.ValueEntry(c)]))
}

/// https://webassembly.github.io/spec/core/exec/instructions.html#t-mathsf-xref-syntax-instructions-syntax-binop-mathit-binop
fn binary_operation(stack: stack.Stack, type_: types.NumberType, operation_type: BinaryOperationType) -> Result(stack.Stack, trap.Trap)
{
    // 1. Assert: due to validation, two values of value type t are on the top of the stack.
    // 2. Pop the value t.{\mathsf{const}}~c_2 from the stack.
    // 3. Pop the value t.{\mathsf{const}}~c_1 from the stack.
    let #(stack, values) = stack.pop_repeat(stack, 2)
    use c <- result.try(
        case type_, operation_type, values
        {
            // 4. If {\mathit{binop}}_t(c_1, c_2) is defined, then:
            //      4a. Let c be a possible result of computing {\mathit{binop}}_t(c_1, c_2).
              types.Integer32, IntegerBinaryOperation(binop), [stack.ValueEntry(runtime.Integer32(c2)), stack.ValueEntry(runtime.Integer32(c1))] 
            | types.Integer64, IntegerBinaryOperation(binop), [stack.ValueEntry(runtime.Integer64(c2)), stack.ValueEntry(runtime.Integer64(c1))] ->
            {
                use c <- result.try(binop(type_, c1, c2))
                // Do operations with 64 bit, demote it to 32 bit if necessary
                case type_
                {
                    types.Integer32 -> Ok(runtime.Integer32(c))
                    _ -> Ok(runtime.Integer64(c))
                }
            }
              types.Float32, FloatBinaryOperation(binop), [stack.ValueEntry(runtime.Float32(c2)), stack.ValueEntry(runtime.Float32(c1))]
            | types.Float64, FloatBinaryOperation(binop), [stack.ValueEntry(runtime.Float64(c2)), stack.ValueEntry(runtime.Float64(c1))] ->
            {
                binop(runtime.builtin_float_to_ieee_float(c1), runtime.builtin_float_to_ieee_float(c2))
            }
            // 5. Else:
            //      5a. Trap
            t, h, args -> trap.make(trap.BadArgument)
                          |> trap.add_message(string.inspect(#(t, h, args)))
                          |> trap.to_error()
        }
    )
    // 4b. Push the value t.{\mathsf{const}}~c to the stack.
    Ok(stack.push(stack, [stack.ValueEntry(c)]))
}

fn get_bitwidth(type_: types.NumberType) -> Int
{
    case type_
    {
        types.Integer32 | types.Float32 -> 32
        types.Integer64 | types.Float64 -> 64
    }
}

/// https://webassembly.github.io/spec/core/exec/instructions.html#t-mathsf-xref-syntax-instructions-syntax-testop-mathit-testop
fn test_operation(stack: stack.Stack, type_: types.NumberType, operation_type: TestOperationType) -> Result(stack.Stack, trap.Trap)
{
    // 1. Assert: due to validation, a value of value type t is on the top of the stack.
    // 2. Pop the value t.{\mathsf{const}}~c_1 from the stack.
    let #(stack, values) = stack.pop(stack)
    use c <- result.try(
        case type_, operation_type, values
        {
            // 3. Let c be the result of computing {\mathit{testop}}_t(c_1).
              types.Integer32 , IntegerTestOperation(testop), option.Some(stack.ValueEntry(runtime.Integer32(c1))) 
            | types.Integer64, IntegerTestOperation(testop), option.Some(stack.ValueEntry(runtime.Integer64(c1))) ->
            {
                testop(c1)
            }
              types.Float32, FloatTestOperation(testop), option.Some(stack.ValueEntry(runtime.Float32(c1)))
            | types.Float64, FloatTestOperation(testop), option.Some(stack.ValueEntry(runtime.Float64(c1))) ->
            {
                testop(runtime.builtin_float_to_ieee_float(c1))
            }
            t, h, args -> trap.make(trap.BadArgument)
                          |> trap.add_message(string.inspect(#(t, h, args)))
                          |> trap.to_error()
        }
    )
    // 4 Push the value {\mathsf{i32}}.{\mathsf{const}}~c to the stack.
    Ok(stack.push(stack, [stack.ValueEntry(runtime.Integer32(c))]))
}

/// https://webassembly.github.io/spec/core/exec/instructions.html#t-mathsf-xref-syntax-instructions-syntax-relop-mathit-relop
fn comparison_operation(stack: stack.Stack, type_: types.NumberType, operation_type: ComparisonOperationType) -> Result(stack.Stack, trap.Trap)
{
    // 1. Assert: due to validation, two values of value type t are on the top of the stack.
    // 2. Pop the value t.{\mathsf{const}}~c_2 from the stack.
    // 3. Pop the value t.{\mathsf{const}}~c_1 from the stack.
    let #(stack, values) = stack.pop_repeat(stack, 2)
    use c <- result.try(
        case type_, operation_type, values
        {
            // 3. Let c be the result of computing {\mathit{relop}}_t(c_1, c_2).
              types.Integer32, IntegerComparisonOperation(relop), [stack.ValueEntry(runtime.Integer32(c2)), stack.ValueEntry(runtime.Integer32(c1))] 
            | types.Integer64, IntegerComparisonOperation(relop), [stack.ValueEntry(runtime.Integer64(c2)), stack.ValueEntry(runtime.Integer64(c1))] ->
            {
                relop(type_, c1, c2)
            }
              types.Float32, FloatComparisonOperation(relop), [stack.ValueEntry(runtime.Float32(c2)), stack.ValueEntry(runtime.Float32(c1))]
            | types.Float64, FloatComparisonOperation(relop), [stack.ValueEntry(runtime.Float64(c2)), stack.ValueEntry(runtime.Float64(c1))] ->
            {
                relop(runtime.builtin_float_to_ieee_float(c1), runtime.builtin_float_to_ieee_float(c2))
            }
            t, h, args -> trap.make(trap.BadArgument)
                          |> trap.add_message(string.inspect(#(t, h, args)))
                          |> trap.to_error()
        }
    )
    // 5. Push the value t.{\mathsf{const}}~c to the stack.
    Ok(stack.push(stack, [stack.ValueEntry(runtime.Integer32(c))]))
}

/// https://webassembly.github.io/spec/core/exec/instructions.html#t-mathsf-xref-syntax-instructions-syntax-instr-numeric-mathsf-const-c
pub fn evaluate_const(stack: stack.Stack, type_: types.NumberType, value: ConstValue) -> Result(stack.Stack, trap.Trap)
{
    // 1. Push the value t.{\mathsf{const}}~c to the stack.
    use c <- result.try(
        case type_, value
        {
            types.Integer32, IntegerConstValue(value:) -> Ok(runtime.Integer32(value))
            types.Integer64, IntegerConstValue(value:) -> Ok(runtime.Integer64(value))
            types.Float32, FloatConstValue(value:) ->
            {
                use built_in_float <- result.try(runtime.ieee_float_to_builtin_float(value))
                Ok(runtime.Float32(built_in_float))
            }
            types.Float64, FloatConstValue(value:) ->
            {
                use built_in_float <- result.try(runtime.ieee_float_to_builtin_float(value))
                Ok(runtime.Float64(built_in_float))
            }
            _, _ -> trap.make(trap.BadArgument)
                    |> trap.to_error()
        }
    )
    Ok(stack.push(to: stack, push: [stack.ValueEntry(c)]))
}

pub fn evaluate_iadd(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { Ok(numerics.iadd(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_isub(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { Ok(numerics.isub(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_imul(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { Ok(numerics.imul(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_idiv_u(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { numerics.idiv_u(get_bitwidth(t), a, b) }))
}

pub fn evaluate_idiv_s(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { numerics.idiv_s(get_bitwidth(t), a, b) }))
}

pub fn evaluate_irem_u(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { numerics.irem_u(get_bitwidth(t), a, b) }))
}

pub fn evaluate_irem_s(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { numerics.irem_s(get_bitwidth(t), a, b) }))
}

pub fn evaluate_iand(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { Ok(numerics.iand(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_ior(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { Ok(numerics.ior(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_ixor(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    binary_operation(stack, type_, IntegerBinaryOperation(fn (t, a, b) { Ok(numerics.ixor(get_bitwidth(t), a, b)) }))
}

// ishl
// ishr_u
// ishr_s
// irotl
// irotr

pub fn evaluate_iclz(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    unary_operation(stack, type_, IntegerUnaryOperation(fn (t, a) { numerics.iclz(get_bitwidth(t), a) }))
}

pub fn evaluate_ictz(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    unary_operation(stack, type_, IntegerUnaryOperation(fn (t, a) { numerics.ictz(get_bitwidth(t), a) }))
}

pub fn evaluate_ipopcnt(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    unary_operation(stack, type_, IntegerUnaryOperation(fn (t, a) { numerics.ipopcnt(get_bitwidth(t), a) }))
}

pub fn evaluate_ieqz(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    test_operation(stack, type_, IntegerTestOperation(fn (a) { Ok(numerics.ieqz(a)) }))
}

pub fn evaluate_ieq(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (_, a, b) { Ok(numerics.ieq(a, b)) }))
}

pub fn evaluate_ine(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (_, a, b) { Ok(numerics.ine(a, b)) }))
}

pub fn evaluate_ilt_u(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.ilt_u(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_ilt_s(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.ilt_s(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_igt_u(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.igt_u(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_igt_s(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.igt_s(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_ile_u(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.ile_u(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_ile_s(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.ile_s(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_ige_u(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.ige_u(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_ige_s(stack: stack.Stack, type_: types.NumberType) -> Result(stack.Stack, trap.Trap)
{
    comparison_operation(stack, type_, IntegerComparisonOperation(fn (t, a, b) { Ok(numerics.ige_s(get_bitwidth(t), a, b)) }))
}

pub fn evaluate_local_get(stack: stack.Stack, index: index.LocalIndex) -> Result(stack.Stack, trap.Trap)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: stack), trap.make(trap.Unknown) |> trap.add_message("gwr/execution/evaluator.evaluate_local_get: couldn't get the current frame")))
    // 2. Assert: due to validation, F.{\mathsf{locals}}[x] exists.
    // 3. Let {\mathit{val}} be the value F.{\mathsf{locals}}[x].
    use local <- result.try(result.replace_error(dict.get(frame.framestate.locals, index), trap.make(trap.Unknown) |> trap.add_message("gwr/execution/evaluator.evaluate_local_get: couldn't get the local with index " <> int.to_string(index))))
    // 4. Push the value {\mathit{val}} to the stack.
    Ok(stack.push(stack, [stack.ValueEntry(local)]))
}

pub fn evaluate_local_set(stack: stack.Stack, index: index.LocalIndex) -> Result(stack.Stack, trap.Trap)
{
    // 1. Let F be the current frame.
    use frame <- result.try(result.replace_error(stack.get_current_frame(from: stack), trap.make(trap.Unknown) |> trap.add_message("gwr/execution/evaluator.evaluate_local_set: couldn't get the current frame")))
    // 2. Assert: due to validation, F.locals[x] exists.
    use _ <- result.try(result.replace_error(dict.get(frame.framestate.locals, index), trap.make(trap.Unknown) |> trap.add_message("gwr/execution/evaluator.evaluate_local_set: couldn't get the local with index " <> int.to_string(index))))
    
    // 3. Assert: due to validation, a value is on the top of the stack.
    // 4. Pop the value val from the stack.
    use #(stack, value) <- result.try(stack.pop_as(from: stack, with: stack.to_value) |> result.replace_error(trap.make(trap.Unknown) |> trap.add_message("gwr/execution/evaluator.evaluate_local_set: couldn't pop the value from stack")))

    // 5. Replace F.locals[x] with the value val.
    use stack <- result.try(
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
        )
        |> result.replace_error(trap.make(trap.Unknown) |> trap.add_message("gwr/execution/evaluator.evaluate_local_set: couldn't update the current frame"))
    )
    Ok(stack)
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

pub fn evaluate_return(stack: stack.Stack) -> Result(#(stack.Stack, option.Option(Jump)), trap.Trap)
{
    // 1. Let F be the current frame.
    use frame <- result.try(
        stack.get_current_frame(from: stack)
        |> result.replace_error(
            trap.make(trap.Unknown)
            |> trap.add_message("gwr/execution/evaluator.evaluate_return: couldn't get the current frame")
        )
    )
    // 2. Let n be the arity of F.
    let n = frame.arity
    // 3. Assert: due to validation, there are at least n values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < n, return:
        trap.make(trap.Unknown)
        |> trap.add_message("gwr/execution/evaluator.evaluate_return: expected the top of the stack to contains at least " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top))
        |> trap.to_error()
    )
    // 4. Pop the results {\mathit{val}}^n from the stack.
    let #(stack, results) = stack.pop_repeat(from: stack, up_to: n)
    // 5. Assert: due to validation, the stack contains at least one frame.
    use <- bool.guard(when: stack.get_entries(stack) |> list.filter(stack.is_activation_frame) |> list.length <= 0, return:
        trap.make(trap.Unknown)
        |> trap.add_message("gwr/execution/evaluator.evaluate_return: expected the stack to contains at least one frame")
        |> trap.to_error()
    )
    // 6. While the top of the stack is not a frame, do:
    //     a. Pop the top element from the stack.
    let #(stack, _) = stack.pop_while(from: stack, with: fn (entry) { !stack.is_activation_frame(entry) })
    // 7. Assert: the top of the stack is the frame F.
    use <- bool.guard(when: stack.peek(stack) != option.Some(stack.ActivationEntry(frame)), return:
        trap.make(trap.Unknown)
        |> trap.add_message("gwr/execution/evaluator.evaluate_return: expected the top of the stack to be the current frame")
        |> trap.to_error()
    )
    // 8. Pop the frame from the stack.
    let #(stack, _) = stack.pop(from: stack)
    // 9. Push {\mathit{val}}^n to the stack.
    let stack = stack.push(to: stack, push: results |> list.reverse)
    // 10. Jump to the instruction after the original call that pushed the frame.
    Ok(#(stack, option.Some(Return)))
}

pub fn evaluate_call(stack: stack.Stack, store: store.Store, index: index.FunctionIndex) -> Result(#(stack.Stack, store.Store), trap.Trap)
{
    // 1. Let F be the current frame.
    use frame <- result.try(
        stack.get_current_frame(from: stack)
        |> result.replace_error(
            trap.make(trap.Unknown)
            |> trap.add_message("gwr/execution/evaluator.evaluate_call: couldn't get the current frame")
        )
    )
    // 2. Assert: due to validation, F.{\mathsf{module}}.{\mathsf{funcaddrs}}[x] exists.
    // 3. Let a be the function address F.{\mathsf{module}}.{\mathsf{funcaddrs}}[x].
    use address <- result.try(
        dict.get(frame.framestate.module_instance.function_addresses, index)
        |> result.replace_error(
            trap.make(trap.Unknown)
            |> trap.add_message("gwr/execution/evaluator.evaluate_call: couldn't find the address of the function with index " <> int.to_string(index))
        )
    )
    // 4. Invoke the function instance at address a.
    invoke(stack, store, address)
}

pub fn invoke(stack: stack.Stack, store: store.Store, address: runtime.Address) -> Result(#(stack.Stack, store.Store), trap.Trap)
{
    // 1. Assert: due to validation, S.{\mathsf{funcs}}[a] exists.
    // 2. Let f be the function instance, S.{\mathsf{funcs}}[a].
    use function_instance <- result.try(
        dict.get(store.functions, address)
        |> result.replace_error(
            trap.make(trap.Unknown)
            |> trap.add_message("gwr/execution/evaluator.invoke: couldn't find the function instance with address " <> runtime.address_to_string(address))
        )
    )
    case function_instance
    {
        runtime.HostFunctionInstance(_, _) -> trap.make(trap.Unknown)
                                              |> trap.add_message("@TODO: call host function")
                                              |> trap.to_error()
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
            let count_of_values_on_top = stack.count_on_top(from: stack, with: stack.is_value)
            use <- bool.guard(when: count_of_values_on_top < n, return:
                trap.make(trap.Unknown)
                |> trap.add_message("gwr/execution/evaluator.invoke: expected the top of the stack to contains " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top))
                |> trap.to_error()
            )
            // 7. Pop the values {\mathit{val}}^n from the stack.
            let #(stack, values) = stack.pop_repeat(from: stack, up_to: n)
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
            evaluate_with_frame(stack, store, runtime.Frame(arity: m, framestate: framestate), function_instructions)
        }
    }
}

pub fn unwind_stack(stack: stack.Stack) -> Result(stack.Stack, trap.Trap)
{
    case stack.get_current_label(from: stack)
    {
        Ok(label) ->
        {
            use stack <- result.try(exit_with_label(stack, label))
            unwind_stack(stack)
        }
        Error(_) -> Ok(stack)
    }
}

pub fn evaluate_with_frame(stack: stack.Stack, store: store.Store, frame: runtime.Frame, instructions: List(instruction.Instruction)) -> Result(#(stack.Stack, store.Store), trap.Trap)
{
    // 9. Push the activation of F with arity m to the stack.
    let stack = stack.push(to: stack, push: [stack.ActivationEntry(frame)])
    // 10. Let L be the label whose arity is m and whose continuation is the end of the function.
    let label = runtime.Label(arity: frame.arity, continuation: [])
    // 11. Enter the instruction sequence {\mathit{instr}}^\ast with label L.
    use #(stack, store, jump) <- result.try(enter_with_label(stack, store, label, instructions, []))
    // Returning from a function
    case jump
    {
        option.Some(Return) -> Ok(#(stack, store))
        _ ->
        {
            use stack <- result.try(unwind_stack(stack))
            // 1. Let F be the current frame.
            use frame <- result.try(
                stack.get_current_frame(from: stack)
                |> result.replace_error(
                    trap.make(trap.Unknown)
                    |> trap.add_message("gwr/execution/evaluator.evaluate_with_frame: couldn't get the current frame")
                )
            )
            // 2. Let n be the arity of the activation of F.
            let n = frame.arity
            // 3. Assert: due to validation, there are n values on the top of the stack.
            let count_of_values_on_top = stack.count_on_top(from: stack, with: stack.is_value)
            use <- bool.guard(when: count_of_values_on_top != n, return:
                trap.make(trap.Unknown)
                |> trap.add_message("gwr/execution/evaluator.evaluate_with_frame: expected the top of the stack to contains " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top))
                |> trap.to_error()
            )
            // 4. Pop the results {\mathit{val}}^n from the stack.
            let #(stack, values) = stack.pop_repeat(from: stack, up_to: n)
            // 5. Assert: due to validation, the frame F is now on the top of the stack.
            use <- bool.guard(when: stack.peek(stack) != option.Some(stack.ActivationEntry(frame)), return:
                trap.make(trap.Unknown)
                |> trap.add_message("gwr/execution/evaluator.evaluate_with_frame: expected the current frame to be on the top of the stack")
                |> trap.to_error()
            )
            // 6. Pop the frame F from the stack.
            let #(stack, _) = stack.pop(from: stack)
            // 7. Push {\mathit{val}}^n back to the stack.
            let stack = stack.push(to: stack, push: values |> list.reverse)
            // 8. Jump to the instruction after the original call.
            Ok(#(stack, store))
        }
    }
}

pub fn evaluate_br(stack: stack.Stack, store: store.Store, index: index.LabelIndex) -> Result(#(stack.Stack, store.Store, option.Option(Jump)), trap.Trap)
{
    // 1. Assert: due to validation, the stack contains at least l+1 labels.
    let all_labels = stack.pop_all(from: stack).1 |> list.filter(stack.is_label)
    let count_of_labels_in_stack = all_labels |> list.length
    use <- bool.guard(when: count_of_labels_in_stack < index + 1, return:
        trap.make(trap.Unknown)
        |> trap.add_message("gwr/execution/evaluator.evaluate_br: expected the stack to contains at least " <> int.to_string(index + 1) <> " labels but got " <> int.to_string(count_of_labels_in_stack))
        |> trap.to_error()
    )
    // 2. Let L be the l-th label appearing on the stack, starting from the top and counting from zero.
    // 3. Let n be the arity of L.
    use label_entry <- result.try(
        all_labels
        |> list.take(up_to: index + 1)
        |> list.last
        |> result.replace_error(
            trap.make(trap.Unknown)
            |> trap.add_message("gwr/execution/evaluator.evaluate_br: couldn't find the label with index " <> int.to_string(index))
        )
    )
    use label <- result.try(stack.to_label(label_entry))
    let n = label.arity
    // 4. Assert: due to validation, there are at least n values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < n, return:
        trap.make(trap.Unknown)
        |> trap.add_message("gwr/execution/evaluator.evaluate_br: expected the top of the stack to contains at least " <> int.to_string(n) <> " values but got " <> int.to_string(count_of_values_on_top))
        |> trap.to_error()
    )
    // 5. Pop the values {\mathit{val}}^n from the stack.
    let #(stack, values) = stack.pop_repeat(stack, n)

    // 6. Repeat l+1 times:
    use stack <- result.try(
        yielder.fold(
            from: Ok(stack),
            over: yielder.range(1, index + 1),
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
                    #(_, anything_else) -> trap.make(trap.Unknown)
                                           |> trap.add_message("gwr/execution/evaluator.evaluate_br: expected the top of the stack to contain a label but got " <> string.inspect(anything_else))
                                           |> trap.to_error()
                }
            }
        )
    )

    // 7. Push the values {\mathit{val}}^n to the stack.
    let stack = stack.push(to: stack, push: values |> list.reverse)
    // 8. Jump to the continuation of L.
    Ok(#(stack, store, option.Some(Branch(target: label.continuation))))
}

pub fn evaluate_br_if(stack: stack.Stack, store: store.Store, index: index.LabelIndex) -> Result(#(stack.Stack, store.Store, option.Option(Jump)), trap.Trap)
{
    // 1. Assert: due to validation, a value of value type {\mathsf{i32}} is on the top of the stack.
    // 2. Pop the value {\mathsf{i32}}.{\mathsf{const}}~c from the stack.
    case stack.pop(from: stack)
    {
        #(stack, option.Some(stack.ValueEntry(runtime.Integer32(c)))) ->
        {
            // 3. If c is non-zero, then:
            case c != 0
            {
                // a. Execute the instruction {\mathsf{br}}~l.
                True -> evaluate_br(stack, store, index)
                // 4. Else:
                //     b. Do nothing.
                False -> Ok(#(stack, store, option.None))
            }
        }
        _ -> trap.make(trap.Unknown)
             |> trap.add_message("gwr/execution/evaluator.evaluate_br_if: expected the top of the stack to contain an i32 value")
             |> trap.to_error()
    }
}

pub fn evaluate_loop(stack: stack.Stack, store: store.Store, block_type: instruction.BlockType, instructions: List(instruction.Instruction)) -> Result(#(stack.Stack, store.Store, option.Option(Jump)), trap.Trap)
{
    // 1. Let F be the current frame.
    use frame <- result.try(
        stack.get_current_frame(from: stack)
        |> result.replace_error(
            trap.make(trap.Unknown)
            |> trap.add_message("gwr/execution/evaluator.evaluate_loop: couldn't get the current frame")
        )
    )
    // 2. Assert: due to validation, {\mathrm{expand}}_F({\mathit{blocktype}}) is defined.
    // 3. Let [t_1^m] {\rightarrow} [t_2^n] be the function type {\mathrm{expand}}_F({\mathit{blocktype}}).
    use function_type <- result.try(expand_block_type(frame.framestate, block_type))
    let m = list.length(function_type.parameters)
    // 4. Let L be the label whose arity is m and whose continuation is the start of the loop.
    let label = runtime.Label(arity: m, continuation: [instruction.Loop(block_type: block_type, instructions: instructions)])
    // 5. Assert: due to validation, there are at least m values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < m, return:
        trap.make(trap.Unknown)
        |> trap.add_message("gwr/execution/evaluator.evaluate_loop: expected the top of the stack to contains at least " <> int.to_string(m) <> " values but got " <> int.to_string(count_of_values_on_top))
        |> trap.to_error()
    )
    // 6. Pop the values {\mathit{val}}^m from the stack.
    let #(stack, values) = stack.pop_repeat(from: stack, up_to: m)
    // 7. Enter the block {\mathit{val}}^m~{\mathit{instr}}^\ast with label L.
    enter_with_label(stack, store, label, instructions, values |> list.reverse)
}

pub fn evaluate_block(stack: stack.Stack, store: store.Store, block_type: instruction.BlockType, instructions: List(instruction.Instruction)) -> Result(#(stack.Stack, store.Store, option.Option(Jump)), trap.Trap)
{
    // 1. Let F be the current frame.
    use frame <- result.try(
        stack.get_current_frame(from: stack)
        |> result.replace_error(
            trap.make(trap.Unknown)
            |> trap.add_message("gwr/execution/evaluator.evaluate_block: couldn't get the current frame")
        )
    )
    // 2. Assert: due to validation, {\mathrm{expand}}_F({\mathit{blocktype}}) is defined.
    // 3. Let [t_1^m] {\rightarrow} [t_2^n] be the function type {\mathrm{expand}}_F({\mathit{blocktype}}).
    use function_type <- result.try(expand_block_type(frame.framestate, block_type))
    let m = list.length(function_type.parameters)
    let n = list.length(function_type.results)
    // 4. Let L be the label whose arity is n and whose continuation is the end of the block.
    let label = runtime.Label(arity: n, continuation: [])
    // 5. Assert: due to validation, there are at least m values on the top of the stack.
    let count_of_values_on_top = stack.pop_while(from: stack, with: stack.is_value).1 |> list.length
    use <- bool.guard(when: count_of_values_on_top < m, return:
        trap.make(trap.Unknown)
        |> trap.add_message("gwr/execution/evaluator.evaluate_block: expected the top of the stack to contains at least " <> int.to_string(m) <> " values but got " <> int.to_string(count_of_values_on_top))
        |> trap.to_error()
    )
    // 6. Pop the values {\mathit{val}}^m from the stack.
    let #(stack, values) = stack.pop_repeat(from: stack, up_to: m)
    // 7. Enter the block {\mathit{val}}^m~{\mathit{instr}}^\ast with label L.
    enter_with_label(stack, store, label, instructions, values |> list.reverse)
}

pub fn enter_with_label(stack: stack.Stack, store: store.Store, label: runtime.Label, instructions: List(instruction.Instruction), parameters: List(stack.StackEntry)) -> Result(#(stack.Stack, store.Store, option.Option(Jump)), trap.Trap)
{
    evaluate_expression(stack.push(to: stack, push: [stack.LabelEntry(label)] |> list.append(parameters)), store, instructions)
}

pub fn exit_with_label(stack: stack.Stack, label: runtime.Label) -> Result(stack.Stack, trap.Trap)
{
    // 1. Pop all values {\mathit{val}}^\ast from the top of the stack.
    let #(stack, values) = stack.pop_while(from: stack, with: stack.is_value)
    // 2. Assert: due to validation, the label L is now on the top of the stack.
    // 3. Pop the label from the stack.
    use stack <- result.try(
        case stack.pop(stack)
        {
            #(stack, option.Some(stack.LabelEntry(some_label))) if some_label == label -> Ok(stack)
            #(_, anything_else) -> trap.make(trap.Unknown)
                                   |> trap.add_message("gwr/execution/evaluator.exit_with_label: expected the label " <> string.inspect(label) <> " pushed to the stack before execution but got " <> string.inspect(anything_else))
                                   |> trap.to_error()
        }
    )
    // 4. Push {\mathit{val}}^\ast back to the stack.
    // 5. Jump to the position after the {\mathsf{end}} of the structured control instruction associated with the label L.
    Ok(stack.push(to: stack, push: values |> list.reverse))
}

pub fn evaluate_expression(stack: stack.Stack, store: store.Store, instructions: List(instruction.Instruction)) -> Result(#(stack.Stack, store.Store, option.Option(Jump)), trap.Trap)
{
    case instructions
    {
        [] -> Ok(#(stack, store, option.None))
        _ ->
        {
            use instruction <- result.try(
                list.first(instructions)
                |> result.replace_error(
                    trap.make(trap.Unknown)
                    |> trap.add_message("gwr/execution/evaluator.evaluate_expression: couldn't get the current instruction")
                )
            )
            use #(stack, store, jump) <- result.try(
                case instruction
                {
                    // Control Instructions
                    instruction.NoOp -> Ok(#(stack, store, option.None))
                    instruction.Unreachable -> trap.make(trap.Unreachable) |> trap.to_error()
                    instruction.End -> Ok(#(stack, store, option.None))
                    instruction.Block(block_type:, instructions:) -> evaluate_block(stack, store, block_type, instructions)
                    instruction.If(block_type:, instructions:, else_: else_) -> evaluate_if_else(stack, store, block_type, instructions, else_)
                    instruction.Loop(block_type:, instructions:) -> evaluate_loop(stack, store, block_type, instructions)
                    instruction.Br(index:) -> evaluate_br(stack, store, index)
                    instruction.BrIf(index:) -> evaluate_br_if(stack, store, index)
                    instruction.Return -> evaluate_return(stack) |> result.map(fn (x) { #(x.0, store, x.1) })
                    instruction.Call(index:) -> evaluate_call(stack, store, index) |> result.map(fn (x) { #(x.0, x.1, option.None) })
                    // Stack-only instructions
                    _ -> result.map(
                        case instruction {
                            // Reference Instructions
                            // Parametric Instructions
                            // Variable Instructions
                            instruction.LocalGet(index) -> evaluate_local_get(stack, index)
                            instruction.LocalSet(index) -> evaluate_local_set(stack, index)
                            // Table Instructions
                            // Memory Instructions
                            // Numeric Instructions
                            instruction.I32Const(value) -> evaluate_const(stack, types.Integer32, IntegerConstValue(value))
                            instruction.I64Const(value) -> evaluate_const(stack, types.Integer64, IntegerConstValue(value))
                            instruction.I32Add -> evaluate_iadd(stack, types.Integer32)
                            instruction.I64Add -> evaluate_iadd(stack, types.Integer64)
                            instruction.I32Sub -> evaluate_isub(stack, types.Integer32)
                            instruction.I64Sub -> evaluate_isub(stack, types.Integer64)
                            instruction.I32Mul -> evaluate_imul(stack, types.Integer32)
                            instruction.I64Mul -> evaluate_imul(stack, types.Integer64)
                            instruction.I32DivU -> evaluate_idiv_u(stack, types.Integer32)
                            instruction.I64DivU -> evaluate_idiv_u(stack, types.Integer64)
                            instruction.I32DivS -> evaluate_idiv_s(stack, types.Integer32)
                            instruction.I64DivS -> evaluate_idiv_s(stack, types.Integer64)
                            instruction.I32RemU -> evaluate_irem_u(stack, types.Integer32)
                            instruction.I64RemU -> evaluate_irem_u(stack, types.Integer64)
                            instruction.I32RemS -> evaluate_irem_s(stack, types.Integer32)
                            instruction.I64RemS -> evaluate_irem_s(stack, types.Integer64)
                            instruction.I32And -> evaluate_iand(stack, types.Integer32)
                            instruction.I64And -> evaluate_iand(stack, types.Integer64)
                            instruction.I32Or -> evaluate_ior(stack, types.Integer32)
                            instruction.I64Or -> evaluate_ior(stack, types.Integer64)
                            instruction.I32Xor -> evaluate_ixor(stack, types.Integer32)
                            instruction.I64Xor -> evaluate_ixor(stack, types.Integer64)
                            //instruction.I32Shl
                            //instruction.I32ShrS
                            //instruction.I32ShrU
                            //instruction.I32Rotl
                            //instruction.I32Rotr
                            instruction.I32Clz -> evaluate_iclz(stack, types.Integer32)
                            instruction.I64Clz -> evaluate_iclz(stack, types.Integer64)
                            instruction.I32Ctz -> evaluate_ictz(stack, types.Integer32)
                            instruction.I64Ctz -> evaluate_ictz(stack, types.Integer64)
                            instruction.I32Popcnt -> evaluate_ipopcnt(stack, types.Integer32)
                            instruction.I64Popcnt -> evaluate_ipopcnt(stack, types.Integer64)
                            instruction.I32Eqz -> evaluate_ieqz(stack, types.Integer32)
                            instruction.I64Eqz -> evaluate_ieqz(stack, types.Integer64)
                            instruction.I32Eq  -> evaluate_ieq(stack, types.Integer32)
                            instruction.I64Eq  -> evaluate_ieq(stack, types.Integer64)
                            instruction.I32Ne  -> evaluate_ine(stack, types.Integer32)
                            instruction.I64Ne  -> evaluate_ine(stack, types.Integer64)
                            instruction.I32LtU -> evaluate_ilt_u(stack, types.Integer32)
                            instruction.I64LtU -> evaluate_ilt_u(stack, types.Integer64)
                            instruction.I32LtS -> evaluate_ilt_s(stack, types.Integer32)
                            instruction.I64LtS -> evaluate_ilt_s(stack, types.Integer64)
                            instruction.I32GtU -> evaluate_igt_u(stack, types.Integer32)
                            instruction.I64GtU -> evaluate_igt_u(stack, types.Integer64)
                            instruction.I32GtS -> evaluate_igt_s(stack, types.Integer32)
                            instruction.I64GtS -> evaluate_igt_s(stack, types.Integer64)
                            instruction.I32LeU -> evaluate_ile_u(stack, types.Integer32)
                            instruction.I64LeU -> evaluate_ile_u(stack, types.Integer64)
                            instruction.I32LeS -> evaluate_ile_s(stack, types.Integer32)
                            instruction.I64LeS -> evaluate_ile_s(stack, types.Integer64)
                            instruction.I32GeU -> evaluate_ige_u(stack, types.Integer32)
                            instruction.I64GeU -> evaluate_ige_u(stack, types.Integer64)
                            instruction.I32GeS -> evaluate_ige_s(stack, types.Integer32)
                            instruction.I64GeS -> evaluate_ige_s(stack, types.Integer64)
                            unknown -> trap.make(trap.Unknown)
                                       |> trap.add_message("gwr/execution/evaluator.evaluate_expression: attempt to execute an unknown or unimplemented instruction \"" <> string.inspect(unknown) <> "\"")
                                       |> trap.to_error()
                        },
                        fn (stack) { #(stack, store, option.None) }
                    )
                }
            )
            case jump
            {
                option.Some(Return) -> Ok(#(stack, store, jump))
                option.Some(Branch(target: instructions)) -> evaluate_expression(stack, store, instructions)
                option.None -> evaluate_expression(stack, store, instructions |> list.drop(1))
            }
        }
    }
}

pub fn evaluate_if_else(stack: stack.Stack, store: store.Store, block_type: instruction.BlockType, if_instructions: List(instruction.Instruction), else_: option.Option(instruction.Instruction)) -> Result(#(stack.Stack, store.Store, option.Option(Jump)), trap.Trap)
{
    // 1. Assert: due to validation, a value of value type {\mathsf{i32}} is on the top of the stack.
    // 2. Pop the value {\mathsf{i32}}.{\mathsf{const}}~c from the stack.
    case stack.pop_as(from: stack, with: stack.to_value)
    {
        Ok(#(stack, runtime.Integer32(c))) ->
        {
            case c != 0
            {
                // 3. If c is non-zero, then:
                //     a. Execute the block instruction {\mathsf{block}}~{\mathit{blocktype}}~{\mathit{instr}}_1^\ast~{\mathsf{end}}.
                True -> evaluate_block(stack, store, block_type, if_instructions)
                // 4. Else:
                //     a. Execute the block instruction {\mathsf{block}}~{\mathit{blocktype}}~{\mathit{instr}}_2^\ast~{\mathsf{end}}.
                False -> case else_
                {
                    option.Some(instruction.Else(else_instructions)) -> evaluate_block(stack, store, block_type, else_instructions)
                    option.None -> Ok(#(stack, store, option.None))
                    anything_else -> trap.make(trap.Unknown)
                                     |> trap.add_message("gwr/execution/evaluator.evaluate_if_else: illegal instruction in the Else's field " <> string.inspect(anything_else))
                                     |> trap.to_error()
                }
            }
        }
        anything_else -> trap.make(trap.Unknown)
                         |> trap.add_message("gwr/execution/evaluator.evaluate_if_else: expected the If's continuation flag but got " <> string.inspect(anything_else))
                         |> trap.to_error()
    }
}

pub fn expand_block_type(framestate: runtime.FrameState, block_type: instruction.BlockType) -> Result(types.FunctionType, trap.Trap)
{
    case block_type
    {
        instruction.TypeIndexBlock(index) -> framestate.module_instance.types
                                             |> list.take(up_to: index + 1)
                                             |> list.last
                                             |> result.replace_error(
                                                trap.make(trap.Unknown)
                                                |> trap.add_message("gwr/execution/evaluator.expand_block_type: couldn't find the function type with index \"" <> int.to_string(index) <> "\"")
                                             )
        instruction.ValueTypeBlock(type_: option.Some(valtype)) -> Ok(types.FunctionType(parameters: [], results: [valtype]))
        instruction.ValueTypeBlock(type_: option.None) -> Ok(types.FunctionType(parameters: [], results: []))
    }
}