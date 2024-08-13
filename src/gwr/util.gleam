import gleam/bit_array
import gleam/int
import gleam/result

import gleb128

pub fn decode_u32leb128(at position: Int, from data: BitArray) -> Result(#(Int, Int), String)
{
    let u32leb128_max_length = 5 // ceil(32 / 7) bytes
    let bytes_to_take = int.min(u32leb128_max_length, bit_array.byte_size(data) - position)
    case bit_array.slice(at: position, from: data, take: bytes_to_take)
    {
        Ok(u32leb128_raw_data) ->
        {
            use section_length <- result.try(gleb128.decode_unsigned(u32leb128_raw_data))
            Ok(section_length)
        }
        Error(_) -> Error("util::decode_u32leb128: can't get section length raw data")
    }
}