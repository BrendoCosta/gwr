import gleam/bool
import gleam/iterator
import gleam/list
import gleam/result

import gwr/parser/binary_reader
import gwr/parser/value_parser

import gwr/syntax/convention

pub fn parse_vector(
    from reader: binary_reader.BinaryReader,
    with parse_element: fn(binary_reader.BinaryReader) -> Result(#(binary_reader.BinaryReader, a), String)
) -> Result(#(binary_reader.BinaryReader, convention.Vector(a)), String)
{
    use #(reader, vector_length) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))

    // If we got a empty vector, then no parsing should be done at all
    use <- bool.guard(when: vector_length == 0, return: Ok(#(reader, [])))

    use #(reader, objects_list) <- result.try(
        iterator.try_fold(
            over: iterator.range(from: 0, to: vector_length - 1),
            from: #(reader, []),
            with: fn (state, _index)
            {
                let #(reader, objects_list) = state
                use <- bool.guard(when: !binary_reader.can_read(reader), return: Ok(state))
                use #(reader, object) <- result.try(parse_element(reader))
                Ok(#(reader, list.append(objects_list, [object])))
            }
        )
    )

    Ok(#(reader, objects_list))
}