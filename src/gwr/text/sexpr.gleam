import gleam/bool
import gleam/bit_array
import gleam/list
import gleam/result

import gwr/parser/byte_reader

pub type SExpr
{
    Atom(String)
    Expression(List(SExpr))
}

pub fn parse(input: String) -> Result(List(SExpr), String)
{
    use #(_, res) <- result.try(do_parse(byte_reader.create(from: bit_array.from_string(input)), []))
    Ok(res)
}

// Important:
// In this function the stack grows to the left
pub fn do_parse(reader: byte_reader.ByteReader, stack_accumulator: List(SExpr)) -> Result(#(byte_reader.ByteReader, List(SExpr)), String)
{
    use <- bool.guard(when: !byte_reader.can_read(reader), return: Ok(#(reader, stack_accumulator)))
    use next_data <- result.try(byte_reader.peek(reader))
    use next_character <- result.try(bit_array.to_string(next_data) |> result.replace_error("Couldn't convert the character to String"))
    case next_character
    {
        "(" -> do_parse(byte_reader.advance(reader, 1), stack_accumulator |> list.prepend(Expression([]))) // Push an empty expression to the stack
        ")" ->
        {
            // Find the last empty expression previously pushed to the stack when the "(" character was parsed
            // #(children, [Expression([]), ..., ..., Expression([]) = root])
            let #(children, remaining) = list.split_while(list: stack_accumulator, satisfying: fn (x) { case x { Expression([]) -> False _ -> True } })
            // Drops the last empty expression from the remaining list and replace it with the expression holding its children
            do_parse(byte_reader.advance(reader, 1), remaining |> list.drop(up_to: 1) |> list.prepend(Expression(children |> list.reverse())))
        }
        " " -> do_parse(byte_reader.advance(reader, 1), stack_accumulator) // Whitespaces should be ignored
        _ ->
        {
            // Treat every other character as an atom and push it to the stack
            use #(reader, atom) <- result.try(parse_atom(reader))
            do_parse(reader, stack_accumulator |> list.prepend(atom))
        }
    }
}

fn parse_atom(reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, SExpr), String)
{
    use #(reader, data) <- result.try(byte_reader.read_while(from: reader, with: fn (data) {
        case bit_array.to_string(data)
        {
            Ok(" ") | Ok("(") | Ok(")") -> False
            _ -> True
        }
    }))
    use atom <- result.try(bit_array.to_string(data) |> result.replace_error("Couldn't convert the Atom characters to String"))
    Ok(#(reader, Atom(atom)))
}
