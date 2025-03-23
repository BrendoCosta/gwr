import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/result

import gwr/parser/byte_reader
import gwr/parser/parsing_error
import gwr/syntax/value

import gleb128
import ieee_float

pub fn parse_unsigned_leb128_integer(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, Int), parsing_error.ParsingError)
{
    use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
    use #(result, bytes_read) <- result.try(
        gleb128.decode_unsigned(remaining_data)
        |> result.replace_error(
            parsing_error.new()
            |> parsing_error.add_message("Couldn't decode LEB128 data")
        )
    )
    let reader = byte_reader.advance(reader, bytes_read)
    Ok(#(reader, result))
}

pub fn parse_signed_leb128_integer(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, Int), parsing_error.ParsingError)
{
    use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
    use #(result, bytes_read) <- result.try(
        gleb128.decode_signed(remaining_data)
        |> result.replace_error(
            parsing_error.new()
            |> parsing_error.add_message("Couldn't decode LEB128 data")
        )
    )
    let reader = byte_reader.advance(reader, bytes_read)
    Ok(#(reader, result))
}

pub fn parse_uninterpreted_leb128_integer(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, Int), parsing_error.ParsingError)
{
    parse_signed_leb128_integer(from: reader)
}

pub fn parse_le32_float(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, ieee_float.IEEEFloat), parsing_error.ParsingError)
{
    use #(reader, data) <- result.try(byte_reader.read(from: reader, take: 4))
    Ok(#(reader, ieee_float.from_bytes_32_le(data)))
}

pub fn parse_le64_float(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, ieee_float.IEEEFloat), parsing_error.ParsingError)
{
    use #(reader, data) <- result.try(byte_reader.read(from: reader, take: 8))
    Ok(#(reader, ieee_float.from_bytes_64_le(data)))
}

pub fn parse_name(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, value.Name), parsing_error.ParsingError)
{
    use #(reader, name_length) <- result.try(parse_unsigned_leb128_integer(from: reader))

    use remaining_data <- result.try(byte_reader.get_remaining(from: reader))
    let remaining_data_length = bit_array.byte_size(remaining_data)
    
    use <- bool.guard(
        when: name_length > remaining_data_length,
        return: parsing_error.new()
                |> parsing_error.add_message("Unexpected end of the name's data. Expected = " <> int.to_string(name_length) <> " bytes but got = " <> int.to_string(remaining_data_length) <> " bytes")
                |> parsing_error.to_error()
    )

    use #(reader, name_data) <- result.try(byte_reader.read(from: reader, take: name_length))
    use result <- result.try(
        bit_array.to_string(name_data)
        |> result.replace_error(
            parsing_error.new()
            |> parsing_error.add_message("Invalid UTF-8 name data")
        )
    )
    Ok(#(reader, result))
}