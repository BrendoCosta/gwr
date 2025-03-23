import gleam/int
import gleam/option.{None, Some}
import gleam/result

import gwr/parser/byte_reader
import gwr/parser/convention_parser
import gwr/parser/parsing_error
import gwr/parser/value_parser

import gwr/syntax/types

pub fn parse_value_type(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, types.ValueType), parsing_error.ParsingError)
{
    use #(reader, value_type_id) <- result.try(
        case byte_reader.read(from: reader, take: 1)
        {
            Ok(#(reader, <<value_type_id>>)) -> Ok(#(reader, value_type_id))
            Error(reason) -> Error(reason)
            _ -> parsing_error.new()
                 |> parsing_error.add_message("gwr/parser/types_parser.parse_value_type: unknown error reading value type id")
                 |> parsing_error.to_error()
        }
    )
    
    use value_type <- result.try(
        case value_type_id
        {
            0x7f -> Ok(types.Number(types.Integer32))
            0x7e -> Ok(types.Number(types.Integer64))
            0x7d -> Ok(types.Number(types.Float32))
            0x7c -> Ok(types.Number(types.Float64))
            0x7b -> Ok(types.Vector(types.Vector128))
            0x70 -> Ok(types.Reference(types.FunctionReference))
            0x6f -> Ok(types.Reference(types.ExternReference))
            unknown -> parsing_error.new()
                       |> parsing_error.add_message("gwr/parser/types_parser.parse_value_type: unknown value type \"" <> int.to_string(unknown) <> "\"")
                       |> parsing_error.to_error()
        }
    )

    Ok(#(reader, value_type))
}

pub fn is_value_type(data: BitArray) -> Bool
{
    case data
    {
        <<0x7f>> | <<0x7e>> | <<0x7d>> | <<0x7c>> | <<0x7b>> | <<0x70>> | <<0x6f>> -> True
        _ -> False
    }
}

pub fn parse_limits(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, types.Limits), parsing_error.ParsingError)
{
    // From the spec: "limits are encoded with a preceding flag indicating whether a maximum is present."
    use #(reader, has_max) <- result.try(
        case byte_reader.read(from: reader, take: 1)
        {
            Ok(#(reader, <<0x00>>)) -> Ok(#(reader, False))
            Ok(#(reader, <<0x01>>)) -> Ok(#(reader, True))
            Ok(#(_, <<unknown>>)) -> parsing_error.new()
                                     |> parsing_error.add_message("gwr/parser/types_parser.parse_limits: unexpected flag value \"" <> int.to_string(unknown) <> "\"")
                                     |> parsing_error.to_error()
            Error(reason) -> Error(reason)
            _ -> parsing_error.new()
                 |> parsing_error.add_message("gwr/parser/types_parser.parse_limits: unknown error reading flag value")
                 |> parsing_error.to_error()
        }
    )

    use #(reader, min) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
    use #(reader, max) <- result.try(
        case has_max
        {
            True ->
            {
                use #(reader, max) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, Some(max)))
            }
            False -> Ok(#(reader, None))
        }
    )
    
    Ok(#(reader, types.Limits(min: min, max: max)))
}

/// Decodes a bit array into a FunctionType. The FunctionType bit array begins with 0x60 byte id
/// and follows with 2 vectors, each containing an arbitrary amount of 1-byte ValueType(s).
/// The first vector represents the list of parameter types of the function, while the second vector represents
/// the list of result types returned by the function.
pub fn parse_function_type(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, types.FunctionType), parsing_error.ParsingError)
{
    use #(reader, function_type) <- result.try(
        case byte_reader.read(from: reader, take: 1)
        {
            Ok(#(reader, <<0x60>>)) ->
            {
                use #(reader, parameters_vec) <- result.try(convention_parser.parse_vector(from: reader, with: parse_value_type))
                use #(reader, results_vec) <- result.try(convention_parser.parse_vector(from: reader, with: parse_value_type))
                Ok(#(reader, types.FunctionType(parameters: parameters_vec, results: results_vec)))
            }
            Ok(#(_, <<unkown>>)) -> parsing_error.new()
                                    |> parsing_error.add_message("gwr/parser/types_parser.parse_function_type: unexpected function type id \"" <> int.to_string(unkown) <> "\"")
                                    |> parsing_error.to_error()
            Error(reason) -> Error(reason)
            _ -> parsing_error.new()
                 |> parsing_error.add_message("gwr/parser/types_parser.parse_function_type: unknown error reading function type id")
                 |> parsing_error.to_error()
        }
    )

    Ok(#(reader, function_type))
}

pub fn parse_global_type(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, types.GlobalType), parsing_error.ParsingError)
{
    use #(reader, value_type) <- result.try(parse_value_type(from: reader))
    use #(reader, mutability) <- result.try(
        case byte_reader.read(from: reader, take: 1)
        {
            Ok(#(reader, <<0x00>>)) -> Ok(#(reader, types.Constant))
            Ok(#(reader, <<0x01>>)) -> Ok(#(reader, types.Variable))
            Ok(#(_, <<unkown>>)) -> parsing_error.new()
                                    |> parsing_error.add_message("gwr/parser/types_parser.parse_global_type: unexpected mutability flag value \"" <> int.to_string(unkown) <> "\"")
                                    |> parsing_error.to_error()
            Error(reason) -> Error(reason)
            _ -> parsing_error.new()
                 |> parsing_error.add_message("gwr/parser/types_parser.parse_global_type: unknown error reading mutability flag value")
                 |> parsing_error.to_error()
        }
    )
    Ok(#(reader, types.GlobalType(value_type: value_type, mutability: mutability)))
}