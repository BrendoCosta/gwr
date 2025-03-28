import gleam/int
import gleam/result

import gwr/parser/byte_reader
import gwr/parser/instruction_parser
import gwr/parser/parsing_error
import gwr/parser/types_parser
import gwr/parser/value_parser

import gwr/syntax/module

pub const function_index_id = 0x00
pub const table_index_id    = 0x01
pub const memory_index_id   = 0x02
pub const global_index_id   = 0x03

pub fn parse_export(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, module.Export), parsing_error.ParsingError)
{
    use #(reader, export_name) <- result.try(value_parser.parse_name(from: reader))

    use #(reader, export) <- result.try(
        case byte_reader.read(from: reader, take: 1)
        {
            Ok(#(reader, <<id>>)) if id == function_index_id ->
            {
                use #(reader, index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, module.Export(name: export_name, descriptor: module.FunctionExport(index))))
            }
            Ok(#(reader, <<id>>)) if id == table_index_id ->
            {
                use #(reader, index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, module.Export(name: export_name, descriptor: module.TableExport(index))))
            }
            Ok(#(reader, <<id>>)) if id == memory_index_id ->
            {
                use #(reader, index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, module.Export(name: export_name, descriptor: module.MemoryExport(index))))
            }
            Ok(#(reader, <<id>>)) if id == global_index_id ->
            {
                use #(reader, index) <- result.try(value_parser.parse_unsigned_leb128_integer(from: reader))
                Ok(#(reader, module.Export(name: export_name, descriptor: module.GlobalExport(index))))
            }
            Ok(#(_, <<unknown>>)) -> parsing_error.new()
                                     |> parsing_error.add_message("gwr/parser/module_parser.parse_export: unexpected export id \"" <> int.to_string(unknown) <> "\"")
                                     |> parsing_error.to_error()
            Error(reason) -> Error(reason)
            _ -> parsing_error.new()
                 |> parsing_error.add_message("gwr/parser/module_parser.parse_export: unknown error reading export id")
                 |> parsing_error.to_error()
        }
    )
    
    Ok(#(reader, export))
}

pub fn parse_global(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, module.Global), parsing_error.ParsingError)
{
    use #(reader, global_type) <- result.try(types_parser.parse_global_type(from: reader))
    use #(reader, expression) <- result.try(instruction_parser.parse_expression(from: reader))
    Ok(#(reader, module.Global(type_: global_type, init: expression)))
}

pub fn parse_memory(from reader: byte_reader.ByteReader) -> Result(#(byte_reader.ByteReader, module.Memory), parsing_error.ParsingError)
{
    use #(reader, limits) <- result.try(types_parser.parse_limits(from: reader))
    Ok(#(reader, module.Memory(type_: limits)))
}