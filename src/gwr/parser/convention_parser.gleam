import gleam/bool
import gleam/list
import gleam/result
import gleam/yielder

import gwr/parser/byte_reader
import gwr/parser/value_parser

import gwr/syntax/convention

pub fn parse_vector(
    from reader: byte_reader.ByteReader,
    with parse_element: fn(byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, a), String)
) -> Result(#(byte_reader.ByteReader, convention.Vector(a)), String)
{
    use #(reader, vector_length) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))

    // If we got a empty vector, then no parsing should be done at all
    use <- bool.guard(when: vector_length == 0, return: Ok(#(reader, [])))

    use #(reader, objects_list) <- result.try(
        yielder.try_fold(
            over: yielder.range(from: 0, to: vector_length - 1),
            from: #(reader, []),
            with: fn (state, _index)
            {
                let #(reader, objects_list) = state
                use <- bool.guard(when: !byte_reader.can_read(reader), return: Ok(state))
                use #(reader, object) <- result.try(parse_element(reader))
                Ok(#(reader, list.append(objects_list, [object])))
            }
        )
    )

    Ok(#(reader, objects_list))
}