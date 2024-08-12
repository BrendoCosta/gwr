
import gleam/bit_array
import gleam/result

import types/vector as vector

// Names are encoded as a vector of bytes containing the Unicode (Section 3.9) UTF-8 encoding of the name’s character sequence.
// https://webassembly.github.io/spec/core/binary/values.html#binary-name
pub type Name
{
    Name(vector: vector.Vector)
}

pub fn from_raw_data(at position: Int, from raw_data: BitArray) -> Result(Name, String)
{
    use vec <- result.try(vector.from_raw_data(at: position, from: raw_data))
    Ok(Name(vector: vec))
}

pub fn to_string(name: Name) -> Result(String, String)
{
    case bit_array.to_string(name.vector.data)
    {
        Ok(str) -> Ok(str)
        Error(_) -> Error("name::show: invalid UTF-8 vector data")
    }
}

pub fn length(of name: Name) -> Int
{
    name.vector.length
}
