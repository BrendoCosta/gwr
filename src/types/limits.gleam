import gleam/bit_array
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/result

import util
import types/vector as vector

// https://webassembly.github.io/spec/core/binary/types.html#limits
pub type Limits
{
    Limits(min: Int, max: Option(Int))
}

pub fn from_raw_data(at position: Int, from raw_data: BitArray) -> Result(#(Limits, Int), String)
{
    // From the spec: "limits are encoded with a preceding flag indicating whether a maximum is present."
    use has_max <- result.try(
        case bit_array.slice(at: position, from: raw_data, take: 1)
        {
            Ok(<<0x00>>) -> Ok(False)
            Ok(<<0x01>>) -> Ok(True)
            Ok(_) | Error(_) -> Error("limits::from_raw_data: can't get has_max flag")
        }
    )

    use #(min, min_word_size) <- result.try(util.decode_u32leb128(at: position + 1, from: raw_data))
    let bytes_read = 1 + min_word_size
    
    use maybe_max <- result.try(
        case has_max
        {
            True ->
            {
                use mx <- result.try(util.decode_u32leb128(at: position + min_word_size + 1, from: raw_data))
                Ok(Some(mx))
            }
            False ->
            {
                Ok(None)
            }
        }
    )

    let bytes_read = case maybe_max
    {
        Some(#(_, max_word_size)) -> bytes_read + max_word_size
        None -> bytes_read
    }

    case maybe_max
    {
        Some(#(max, _)) -> Ok(#(Limits(min: min, max: Some(max)), bytes_read))
        None -> Ok(#(Limits(min: min, max: None), bytes_read))
    }
}

pub fn do_from_vector(at position_accumulator: Int, from vec: vector.Vector, to result_accumulator: List(Limits)) -> Result(#(List(Limits), Int), String)
{
    case position_accumulator < vec.length
    {
        True ->
        {
            case from_raw_data(at: position_accumulator, from: vec.data)
            {
                Ok(limit) ->
                {
                    let result_accumulator = list.append(result_accumulator, [limit.0])
                    do_from_vector(at: position_accumulator + limit.1, from: vec, to: result_accumulator)
                }
                Error(reason) -> Error(reason)
            }
        }
        False -> Ok(#(result_accumulator, position_accumulator))
    }
}

pub fn from_vector(from vec: vector.Vector)
{
    do_from_vector(at: 0, from: vec, to: [])
}