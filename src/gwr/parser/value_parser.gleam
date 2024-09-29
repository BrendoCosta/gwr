import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/result

import gwr/parser/byte_reader
import gwr/syntax/value

import gleb128
import ieee_float

pub fn parse_unsigned_leb128_integer(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, Int), String)
{
    use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
    use #(result, bytes_read) <- result.try(gleb128.fast_decode_unsigned(remaining_data))
    let reader = byte_reader.advance(reader, bytes_read)
    Ok(#(reader, result))
}

pub fn parse_signed_leb128_integer(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, Int), String)
{
    use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
    use #(result, bytes_read) <- result.try(gleb128.fast_decode_signed(remaining_data))
    let reader = byte_reader.advance(reader, bytes_read)
    Ok(#(reader, result))
}

pub fn parse_uninterpreted_leb128_integer(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, Int), String)
{
    parse_signed_leb128_integer(from: reader)
}

pub fn parse_le32_float(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, ieee_float.IEEEFloat), String)
{
    use #(reader, data) <- result.try(byte_reader.read(from: reader, take: 4))
    Ok(#(reader, ieee_float.from_bytes_32_le(data)))
}

pub fn parse_le64_float(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, ieee_float.IEEEFloat), String)
{
    use #(reader, data) <- result.try(byte_reader.read(from: reader, take: 8))
    Ok(#(reader, ieee_float.from_bytes_64_le(data)))
}

pub fn parse_name(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, value.Name), String)
{
    use #(reader, name_length) <- result.try(parse_unsigned_leb128_integer(from: reader))

    use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
    let remaining_data_length = bit_array.byte_size(remaining_data)
    
    use <- bool.guard(
        when: name_length > remaining_data_length,
        return: Error("gwr/parser/value_parser.parse_name: unexpected end of the name's data. Expected = " <> int.to_string(name_length) <> " bytes but got = " <> int.to_string(remaining_data_length) <> " bytes")
    )

    use #(reader, result) <- result.try(
        case byte_reader.read(from: reader, take: name_length)
        {
            Ok(#(reader, name_data)) ->
            {
                case bit_array.to_string(name_data)
                {
                    Ok(name_string) -> Ok(#(reader, name_string))
                    Error(_) -> Error("gwr/parser/value_parser.parse_name: invalid UTF-8 name data")
                }
            }
            Error(reason) -> Error("gwr/parser/value_parser.parse_name: couldn't parse name: " <> reason)
        }
    )

    Ok(#(reader, result))
}