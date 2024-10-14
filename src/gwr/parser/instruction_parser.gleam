import gleam/option
import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/iterator
import gleam/list
import gleam/result

import gwr/syntax/instruction
import gwr/parser/byte_reader
import gwr/parser/types_parser
import gwr/parser/value_parser

pub fn parse_instruction(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, instruction.Instruction), String)
{
    use #(reader, opcode) <- result.try(
        case byte_reader.read(from: reader, take: 1)
        {
            Ok(#(reader, <<opcode>>)) -> Ok(#(reader, opcode))
            Error(reason) -> Error("gwr/parser/instruction_parser.parse_instruction: couldn't read opcode: " <> reason)
            _ -> Error("gwr/parser/instruction_parser.parse_instruction: unknown error reading opcode")
        }
    )
    
    use #(reader, instruction) <- result.try(
        case opcode
        {
            // Control Instructions
            // https://webassembly.github.io/spec/core/binary/instructions.html#control-instructions
            0x00 -> Ok(#(reader, instruction.Unreachable))
            0x01 -> Ok(#(reader, instruction.NoOp))
            0x02 ->
            {
                use #(reader, block_type) <- result.try(parse_block_type(from: reader))
                use #(reader, expression) <- result.try(parse_expression(from: reader))
                Ok(#(reader, instruction.Block(block_type: block_type, instructions: expression)))
            }
            0x03 ->
            {
                use #(reader, block_type) <- result.try(parse_block_type(from: reader))
                use #(reader, expression) <- result.try(parse_expression(from: reader))
                Ok(#(reader, instruction.Loop(block_type: block_type, instructions: expression)))
            }
            0x04 ->
            {
                use #(reader, block_type) <- result.try(parse_block_type(from: reader))
                use #(reader, body) <- result.try(
                    parse_instructions_until(
                        from: reader,
                        with: fn (inst) {
                        case inst
                        {
                            instruction.End -> True
                            instruction.Else(_) -> True
                            _ -> False
                        }
                    })
                )
                case list.last(body)
                {
                    Ok(instruction.End) -> Ok(#(reader, instruction.If(block_type: block_type, instructions: body, else_: option.None)))
                    Ok(instruction.Else(_) as els) -> Ok(#(reader, instruction.If(block_type: block_type, instructions: list.take(from: body, up_to: list.length(body) - 1), else_: option.Some(els))))
                    _ -> Error("gwr/parser/instruction_parser.parse_instruction: expected the If instruction's block to end either with an End instruction or an Else instruction")
                }
            }
            0x05 ->
            {
                use #(reader, expression) <- result.try(parse_expression(from: reader))
                Ok(#(reader, instruction.Else(instructions: expression)))
            }
            0xc ->
            {
                use #(reader, label_index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, instruction.Br(index: label_index)))
            }
            0xd ->
            {
                use #(reader, label_index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, instruction.BrIf(index: label_index)))
            }
            0x10 ->
            {
                use #(reader, function_index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, instruction.Call(index: function_index)))
            }
            // Variable Instructions
            // https://webassembly.github.io/spec/core/binary/instructions.html#variable-instructions
            0x20 ->
            {
                use #(reader, local_index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, instruction.LocalGet(index: local_index)))
            }
            0x21 ->
            {
                use #(reader, local_index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, instruction.LocalSet(index: local_index)))
            }
            // Numeric Instructions
            // https://webassembly.github.io/spec/core/binary/instructions.html#numeric-instructions
            0x41 ->
            {
                use #(reader, value) <- result.try(value_parser.parse_uninterpreted_leb128_integer(from: reader))
                Ok(#(reader, instruction.I32Const(value: value)))
            }
            0x42 ->
            {
                use #(reader, value) <- result.try(value_parser.parse_uninterpreted_leb128_integer(from: reader))
                Ok(#(reader, instruction.I64Const(value: value)))
            }
            0x43 ->
            {
                use #(reader, value) <- result.try(value_parser.parse_le32_float(from: reader))
                Ok(#(reader, instruction.F32Const(value: value)))
            }
            0x44 ->
            {
                use #(reader, value) <- result.try(value_parser.parse_le64_float(from: reader))
                Ok(#(reader, instruction.F64Const(value: value)))
            }
            0x45 -> Ok(#(reader, instruction.I32Eqz))
            0x46 -> Ok(#(reader, instruction.I32Eq))
            0x47 -> Ok(#(reader, instruction.I32Ne))
            0x48 -> Ok(#(reader, instruction.I32LtS))
            0x49 -> Ok(#(reader, instruction.I32LtU))
            0x4a -> Ok(#(reader, instruction.I32GtS))
            0x4b -> Ok(#(reader, instruction.I32GtU))
            0x4c -> Ok(#(reader, instruction.I32LeS))
            0x4d -> Ok(#(reader, instruction.I32LeU))
            0x4e -> Ok(#(reader, instruction.I32GeS))
            0x4f -> Ok(#(reader, instruction.I32GeU))
            0x50 -> Ok(#(reader, instruction.I64Eqz))
            0x51 -> Ok(#(reader, instruction.I64Eq))
            0x52 -> Ok(#(reader, instruction.I64Ne))
            0x53 -> Ok(#(reader, instruction.I64LtS))
            0x54 -> Ok(#(reader, instruction.I64LtU))
            0x55 -> Ok(#(reader, instruction.I64GtS))
            0x56 -> Ok(#(reader, instruction.I64GtU))
            0x57 -> Ok(#(reader, instruction.I64LeS))
            0x58 -> Ok(#(reader, instruction.I64LeU))
            0x59 -> Ok(#(reader, instruction.I64GeS))
            0x5a -> Ok(#(reader, instruction.I64GeU))
            0x5b -> Ok(#(reader, instruction.F32Eq))
            0x5c -> Ok(#(reader, instruction.F32Ne))
            0x5d -> Ok(#(reader, instruction.F32Lt))
            0x5e -> Ok(#(reader, instruction.F32Gt))
            0x5f -> Ok(#(reader, instruction.F32Le))
            0x60 -> Ok(#(reader, instruction.F32Ge))
            0x61 -> Ok(#(reader, instruction.F64Eq))
            0x62 -> Ok(#(reader, instruction.F64Ne))
            0x63 -> Ok(#(reader, instruction.F64Lt))
            0x64 -> Ok(#(reader, instruction.F64Gt))
            0x65 -> Ok(#(reader, instruction.F64Le))
            0x66 -> Ok(#(reader, instruction.F64Ge))
            0x67 -> Ok(#(reader, instruction.I32Clz))
            0x68 -> Ok(#(reader, instruction.I32Ctz))
            0x69 -> Ok(#(reader, instruction.I32Popcnt))
            0x6a -> Ok(#(reader, instruction.I32Add))
            0x6b -> Ok(#(reader, instruction.I32Sub))
            0x6c -> Ok(#(reader, instruction.I32Mul))
            0x6d -> Ok(#(reader, instruction.I32DivS))
            0x6e -> Ok(#(reader, instruction.I32DivU))
            0x6f -> Ok(#(reader, instruction.I32RemS))
            0x70 -> Ok(#(reader, instruction.I32RemU))
            0x71 -> Ok(#(reader, instruction.I32And))
            0x72 -> Ok(#(reader, instruction.I32Or))
            0x73 -> Ok(#(reader, instruction.I32Xor))
            0x74 -> Ok(#(reader, instruction.I32Shl))
            0x75 -> Ok(#(reader, instruction.I32ShrS))
            0x76 -> Ok(#(reader, instruction.I32ShrU))
            0x77 -> Ok(#(reader, instruction.I32Rotl))
            0x78 -> Ok(#(reader, instruction.I32Rotr))
            0x79 -> Ok(#(reader, instruction.I64Clz))
            0x7a -> Ok(#(reader, instruction.I64Ctz))
            0x7b -> Ok(#(reader, instruction.I64Popcnt))
            0x7c -> Ok(#(reader, instruction.I64Add))
            0x7d -> Ok(#(reader, instruction.I64Sub))
            0x7e -> Ok(#(reader, instruction.I64Mul))
            0x7f -> Ok(#(reader, instruction.I64DivS))
            0x80 -> Ok(#(reader, instruction.I64DivU))
            0x81 -> Ok(#(reader, instruction.I64RemS))
            0x82 -> Ok(#(reader, instruction.I64RemU))
            0x83 -> Ok(#(reader, instruction.I64And))
            0x84 -> Ok(#(reader, instruction.I64Or))
            0x85 -> Ok(#(reader, instruction.I64Xor))
            0x86 -> Ok(#(reader, instruction.I64Shl))
            0x87 -> Ok(#(reader, instruction.I64ShrS))
            0x88 -> Ok(#(reader, instruction.I64ShrU))
            0x89 -> Ok(#(reader, instruction.I64Rotl))
            0x8a -> Ok(#(reader, instruction.I64Rotr))
            0x8b -> Ok(#(reader, instruction.F32Abs))
            0x8c -> Ok(#(reader, instruction.F32Neg))
            0x8d -> Ok(#(reader, instruction.F32Ceil))
            0x8e -> Ok(#(reader, instruction.F32Floor))
            0x8f -> Ok(#(reader, instruction.F32Trunc))
            0x90 -> Ok(#(reader, instruction.F32Nearest))
            0x91 -> Ok(#(reader, instruction.F32Sqrt))
            0x92 -> Ok(#(reader, instruction.F32Add))
            0x93 -> Ok(#(reader, instruction.F32Sub))
            0x94 -> Ok(#(reader, instruction.F32Mul))
            0x95 -> Ok(#(reader, instruction.F32Div))
            0x96 -> Ok(#(reader, instruction.F32Min))
            0x97 -> Ok(#(reader, instruction.F32Max))
            0x98 -> Ok(#(reader, instruction.F32Copysign))
            0x99 -> Ok(#(reader, instruction.F64Abs))
            0x9a -> Ok(#(reader, instruction.F64Neg))
            0x9b -> Ok(#(reader, instruction.F64Ceil))
            0x9c -> Ok(#(reader, instruction.F64Floor))
            0x9d -> Ok(#(reader, instruction.F64Trunc))
            0x9e -> Ok(#(reader, instruction.F64Nearest))
            0x9f -> Ok(#(reader, instruction.F64Sqrt))
            0xa0 -> Ok(#(reader, instruction.F64Add))
            0xa1 -> Ok(#(reader, instruction.F64Sub))
            0xa2 -> Ok(#(reader, instruction.F64Mul))
            0xa3 -> Ok(#(reader, instruction.F64Div))
            0xa4 -> Ok(#(reader, instruction.F64Min))
            0xa5 -> Ok(#(reader, instruction.F64Max))
            0xa6 -> Ok(#(reader, instruction.F64Copysign))
            0xa7 -> Ok(#(reader, instruction.I32WrapI64))
            0xa8 -> Ok(#(reader, instruction.I32TruncF32S))
            0xa9 -> Ok(#(reader, instruction.I32TruncF32U))
            0xaa -> Ok(#(reader, instruction.I32TruncF64S))
            0xab -> Ok(#(reader, instruction.I32TruncF64U))
            0xac -> Ok(#(reader, instruction.I64ExtendI32S))
            0xad -> Ok(#(reader, instruction.I64ExtendI32U))
            0xae -> Ok(#(reader, instruction.I64TruncF32S))
            0xaf -> Ok(#(reader, instruction.I64TruncF32U))
            0xb0 -> Ok(#(reader, instruction.I64TruncF64S))
            0xb1 -> Ok(#(reader, instruction.I64TruncF64U))
            0xb2 -> Ok(#(reader, instruction.F32ConvertI32S))
            0xb3 -> Ok(#(reader, instruction.F32ConvertI32U))
            0xb4 -> Ok(#(reader, instruction.F32ConvertI64S))
            0xb5 -> Ok(#(reader, instruction.F32ConvertI64U))
            0xb6 -> Ok(#(reader, instruction.F32DemoteF64))
            0xb7 -> Ok(#(reader, instruction.F64ConvertI32S))
            0xb8 -> Ok(#(reader, instruction.F64ConvertI32U))
            0xb9 -> Ok(#(reader, instruction.F64ConvertI64S))
            0xba -> Ok(#(reader, instruction.F64ConvertI64U))
            0xbb -> Ok(#(reader, instruction.F64PromoteF32))
            0xbc -> Ok(#(reader, instruction.I32ReinterpretF32))
            0xbd -> Ok(#(reader, instruction.I64ReinterpretF64))
            0xbe -> Ok(#(reader, instruction.F32ReinterpretI32))
            0xbf -> Ok(#(reader, instruction.F64ReinterpretI64))
            0xc0 -> Ok(#(reader, instruction.I32Extend8S))
            0xc1 -> Ok(#(reader, instruction.I32Extend16S))
            0xc2 -> Ok(#(reader, instruction.I64Extend8S))
            0xc3 -> Ok(#(reader, instruction.I64Extend16S))
            0xc4 -> Ok(#(reader, instruction.I64Extend32S))
            0xfc ->
            {
                use #(reader, actual_opcode) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                case actual_opcode
                {
                    0x00 -> Ok(#(reader, instruction.I32TruncSatF32S))
                    0x01 -> Ok(#(reader, instruction.I32TruncSatF32U))
                    0x02 -> Ok(#(reader, instruction.I32TruncSatF64S))
                    0x03 -> Ok(#(reader, instruction.I32TruncSatF64U))
                    0x04 -> Ok(#(reader, instruction.I64TruncSatF32S))
                    0x05 -> Ok(#(reader, instruction.I64TruncSatF32U))
                    0x06 -> Ok(#(reader, instruction.I64TruncSatF64S))
                    0x07 -> Ok(#(reader, instruction.I64TruncSatF64U))
                    unknown -> Error("gwr/parser/instruction_parser.parse_instruction: unknown saturating truncation instruction opcode \"0x" <> int.to_base16(unknown) <> "\"")
                }
            }
            // End
            // https://webassembly.github.io/spec/core/binary/instructions.html#expressions
            0x0b -> Ok(#(reader, instruction.End))
            unknown -> Error("gwr/parser/instruction_parser.parse_instruction: unknown opcode \"0x" <> int.to_base16(unknown) <> "\"")
        }
    )

    Ok(#(reader, instruction))
}

pub fn parse_expression(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, instruction.Expression), String)
{
    use data <- result.try(byte_reader.get_remaining(from: reader))
    let data_length = bit_array.byte_size(data)

    use #(reader, expression) <- result.try(
        iterator.fold(
            from: Ok(#(reader, [])),
            over: iterator.range(1, data_length),
            with: fn (state, _) {
                
                use #(reader, current_expression) <- result.try(state)

                // If the last instruction was an End instruction then no further processing should be done at all
                use <- bool.guard(when: list.last(current_expression) == Ok(instruction.End), return: state)
                
                // If we reached the end of the data then the last instruction there must be an End instruction; otherwise we got an error 
                use <- bool.guard(when: !byte_reader.can_read(reader) && list.last(current_expression) != Ok(instruction.End), return: Error("gwr/parser/instruction_parser.parse_expression: an expression must terminate with a End instruction"))

                use #(reader, instruction) <- result.try(parse_instruction(from: reader))

                Ok(#(reader, list.append(current_expression, [instruction])))
            }
        )
    )

    Ok(#(reader, expression))
}

pub fn do_parse_instructions_until(reader: byte_reader.ByteReader, predicate: fn (instruction.Instruction) -> Bool, accumulator: List(instruction.Instruction)) -> Result(#(byte_reader.ByteReader, List(instruction.Instruction)), String)
{
    case byte_reader.can_read(reader)
    {
        True ->
        {
            use #(reader, instruction) <- result.try(parse_instruction(from: reader))
            case predicate(instruction)
            {
                True -> Ok(#(reader, list.append(accumulator, [instruction])))
                False -> do_parse_instructions_until(reader, predicate, list.append(accumulator, [instruction]))
            }
        }
        False -> Error("gwr/parser/instruction_parser.do_parse_instructions_until: reached the end of the data yet couldn't find the instruction matching the given predicate")
    }
}

pub fn parse_instructions_until(from reader: byte_reader.ByteReader, with predicate: fn (instruction.Instruction) -> Bool) -> Result(#(byte_reader.ByteReader, List(instruction.Instruction)), String)
{
    do_parse_instructions_until(reader, predicate, [])
}

pub fn parse_block_type(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, instruction.BlockType), String)
{
    // A structured instruction can consume input and produce output on the operand stack
    // according to its annotated block type. It is given either as a type index that refers
    // to a suitable function type, or as an optional value type inline, which is a shorthand
    // for the function type [] -> [valtype?]
    use #(_, first_byte) <- result.try(byte_reader.read(from: reader, take: 1))
    case types_parser.is_value_type(first_byte)
    {
        True ->
        {
            use #(reader, value_type) <- result.try(types_parser.parse_value_type(from: reader))
            Ok(#(reader, instruction.ValueTypeBlock(type_: option.Some(value_type))))
        }
        False ->
        {
            case first_byte
            {
                <<0x40>> -> Ok(#(byte_reader.advance(from: reader, up_to: 1), instruction.ValueTypeBlock(type_: option.None)))
                _ ->
                {
                    use #(reader, index) <- result.try(value_parser.parse_signed_leb128_integer(from: reader))
                    Ok(#(reader, instruction.TypeIndexBlock(index: index)))
                }
            }
        }
    }
}