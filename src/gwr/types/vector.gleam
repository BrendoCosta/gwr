import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/result

import gwr/util

// Vectors are encoded with their u32 length followed by the encoding of their element sequence.
// https://webassembly.github.io/spec/core/binary/conventions.html#binary-vec
pub type Vector
{
    Vector(length: Int, data: BitArray)
}

pub fn from_raw_data(at position: Int, from raw_data: BitArray) -> Result(Vector, String)
{
    use #(vector_length, vector_length_word_size) <- result.try(util.decode_u32leb128(at: position, from: raw_data))
    
    use <- bool.guard(
        when: position + vector_length_word_size + vector_length > bit_array.byte_size(raw_data),
        return: Error("vector::from_raw_data: unexpected end of the vector's data. Expected = " <> int.to_string(vector_length) <> " bytes but got = " <> int.to_string(bit_array.byte_size(raw_data) - vector_length_word_size - position) <> " bytes")
    )

    case bit_array.slice(at: position + vector_length_word_size, from: raw_data, take: vector_length)
    {
        Ok(vector_data) ->
        {
            Ok(Vector(length: vector_length, data: vector_data))
        }
        Error(_) -> Error("vector::from_raw_data: can't slice vector data")
    }
}