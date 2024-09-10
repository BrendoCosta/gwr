import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/iterator
import gleam/list
import gleam/result

import gwr/syntax/instruction
import gwr/parser/byte_reader
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