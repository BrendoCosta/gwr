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
            // Variable Instructions
            // https://webassembly.github.io/spec/core/binary/instructions.html#variable-instructions
            0x20 ->
            {
                use #(reader, local_index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, instruction.LocalGet(index: local_index)))
            }
            // Numeric Instructions
            // https://webassembly.github.io/spec/core/binary/instructions.html#numeric-instructions
            0x6a -> Ok(#(reader, instruction.I32Add))
            0x41 ->
            {
                use #(reader, value) <- result.try(value_parser.parse_uninterpreted_leb128_integer(from: reader))
                Ok(#(reader, instruction.I32Const(value: value)))
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
    //use #(reader, flag) <- result.try(byte_reader.read(from: reader, take: 1))
    use data <- result.try(byte_reader.get_remaining(from: reader))
    case data
    {
        <<0x40>> -> Ok(#(byte_reader.advance(from: reader, up_to: 1), instruction.EmptyBlock))
        _ -> case types_parser.parse_value_type(from: reader)
        {
            Ok(#(reader, value_type)) -> Ok(#(reader, instruction.ValueTypeBlock(type_: value_type)))
            _ ->
            {
                use #(reader, index) <- result.try(value_parser.parse_signed_leb128_integer(from: reader))
                Ok(#(reader, instruction.TypeIndexBlock(index: index)))
            }
        }
    }
}