import gleam/int
import gleam/result

import gwr/parser/binary_reader
import gwr/parser/instruction_parser
import gwr/parser/types_parser
import gwr/parser/value_parser

import gwr/syntax/module

pub const function_index_id = 0x00
pub const table_index_id    = 0x01
pub const memory_index_id   = 0x02
pub const global_index_id   = 0x03

pub fn parse_export(from reader: binary_reader.BinaryReader) -> Result(#(binary_reader.BinaryReader, module.Export), String)
{
    use #(reader, export_name) <- result.try(value_parser.parse_name(from: reader))

    use #(reader, export) <- result.try(
        case binary_reader.read(from: reader, take: 1)
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
            Ok(#(_, <<unknown>>)) -> Error("gwr/parser/module_parser.parse_export: unexpected export id \"" <> int.to_string(unknown) <> "\"")
            Error(reason) -> Error("gwr/parser/module_parser.parse_export: couldn't read export id: " <> reason)
            _ -> Error("gwr/parser/module_parser.parse_export: unknown error reading export id")
        }
    )
    
    Ok(#(reader, export))
}

pub fn parse_global(from reader: binary_reader.BinaryReader) -> Result(#(binary_reader.BinaryReader, module.Global), String)
{
    use #(reader, global_type) <- result.try(types_parser.parse_global_type(from: reader))
    use #(reader, expression) <- result.try(instruction_parser.parse_expression(from: reader))
    Ok(#(reader, module.Global(type_: global_type, init: expression)))
}

pub fn parse_memory(from reader: binary_reader.BinaryReader) -> Result(#(binary_reader.BinaryReader, module.Memory), String)
{
    use #(reader, limits) <- result.try(types_parser.parse_limits(from: reader))
    Ok(#(reader, module.Memory(type_: limits)))
}