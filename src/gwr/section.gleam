import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/option.{type Option, Some, None}
import gleam/result

import gwr/util
import gwr/types/limits.{type Limits}
import gwr/types/name
import gwr/types/vector

// Each section consists of
//     - a one-byte section id,
//     - the u32 size of the contents, in bytes,
//     - the actual contents, whose structure is dependent on the section id.

// https://webassembly.github.io/spec/core/binary/modules.html#sections
pub type RawSection
{
    RawSection(type_id: Int, length: Int, content: Option(BitArray))
}

pub type Section
{
    // Custom sections have the id 0. They are intended to be used for debugging information or third-party extensions, and are ignored by the WebAssembly semantics.
    // Their contents consist of a name further identifying the custom section, followed by an uninterpreted sequence of bytes for custom use.
    Custom(length: Int, name: String, data: Option(BitArray))
    Type(length: Int)
    Import(length: Int)
    Function(length: Int)
    Table(length: Int)
    Memory(length: Int, memories: List(Limits))
    Global(length: Int)
    Export(length: Int)
    Start(length: Int)
    Element(length: Int)
    Code(length: Int)
    Data(length: Int)
    DataCount(length: Int)
}

// https://webassembly.github.io/spec/core/binary/modules.html#sections
pub const     custom_section_id = 0x00
pub const       type_section_id = 0x01
pub const     import_section_id = 0x02
pub const   function_section_id = 0x03
pub const      table_section_id = 0x04
pub const     memory_section_id = 0x05
pub const     global_section_id = 0x06
pub const     export_section_id = 0x07
pub const      start_section_id = 0x08
pub const    element_section_id = 0x09
pub const       code_section_id = 0x0a
pub const       data_section_id = 0x0b
pub const data_count_section_id = 0x0c

pub fn parse_raw_section(at position: Int, from raw_data: BitArray) -> Result(RawSection, String)
{
    use section_type_id <- result.try(
        case bit_array.slice(at: position, from: raw_data, take: 1)
        {
            Ok(section_type_id_raw_data) -> case section_type_id_raw_data
            {
                <<section_type_id_decoded>> -> Ok(section_type_id_decoded)
                _ -> Error("section::parse_raw_section: can't decode section type id raw data into an integer")
            }
            Error(_) -> Error("section::parse_raw_section: can't get section type id raw data")
        }
    )

    use #(section_length, section_length_word_size) <- result.try(util.decode_u32leb128(at: position + 1, from: raw_data))

    let section_raw_content = case section_length > 0
    {
        True ->
        {
            use <- bool.guard(
                when: position + 1 + section_length_word_size + section_length > bit_array.byte_size(raw_data),
                return: Error("section::parse_raw_section: unexpected end of the section's content segment")
            )
            case bit_array.slice(at: position + 1 + section_length_word_size, from: raw_data, take: section_length)
            {
                Ok(content) -> Ok(Some(content))
                Error(_) -> Error("section::parse_raw_section: can't get the section's content segment")
            }
        }
        False -> Ok(None)
    }

    use section_raw_content <- result.try(
        case section_raw_content
        {
            Ok(v) -> Ok(v)
            Error(reason) -> Error(reason)
        }
    )

    Ok(RawSection(type_id: section_type_id, length: section_length, content: section_raw_content))
}

pub fn decode_section(at position: Int, from raw_data: BitArray) -> Result(Section, String)
{
    use parsed_raw_section <- result.try(parse_raw_section(at: position, from: raw_data))
    case parsed_raw_section.type_id
    {
        n if n == custom_section_id     -> decode_custom_section(parsed_raw_section)
        //n if n == type_section_id       -> Ok(Type)
        //n if n == import_section_id     -> Ok(Import)
        //n if n == function_section_id   -> Ok(Function)
        //n if n == table_section_id      -> Ok(Table)
        n if n == memory_section_id     -> decode_memory_section(parsed_raw_section)
        //n if n == global_section_id     -> Ok(Global)
        //n if n == export_section_id     -> Ok(Export)
        //n if n == start_section_id      -> Ok(Start)
        //n if n == element_section_id    -> Ok(Element)
        //n if n == code_section_id       -> Ok(Code)
        //n if n == data_section_id       -> Ok(Data)
        //n if n == data_count_section_id -> Ok(DataCount)
        _                               -> Error("section::decode_section: unknown section type id \"" <> int.to_string(parsed_raw_section.type_id) <> "\"")
    }
}

pub fn decode_custom_section(raw_section: RawSection) -> Result(Section, String)
{
    case raw_section.content
    {
        Some(content) ->
        {
            use custom_section_name <- result.try(name.from_raw_data(at: 0, from: content))
            use name_string <- result.try(name.to_string(custom_section_name))
            let name_length = name.length(custom_section_name)
            let content_length = bit_array.byte_size(content)

            case bit_array.slice(at: name_length + 1, from: content, take: content_length - name_length - 1)
            {
                Ok(custom_data) -> Ok(Custom(length: raw_section.length, name: name_string, data: Some(custom_data)))
                Error(_) -> Error("section::decode_custom_section: can't get custom data")
            }
        }
        None -> Error("section::decode_custom_section: empty section content")
    }
}

pub fn decode_memory_section(raw_section: RawSection) -> Result(Section, String)
{
    case raw_section.content
    {
        Some(content) ->
        {
            use raw_vec <- result.try(vector.from_raw_data(at: 0, from: content))
            use mem_vec <- result.try(limits.from_vector(raw_vec))
            Ok(Memory(length: raw_section.length, memories: mem_vec.0))
        }
        None -> Error("section::decode_memory_section: empty section content")
    }
}

pub fn from_raw_data(at position: Int, from raw_data: BitArray) -> Result(Section, String)
{
    use sec <- result.try(decode_section(at: position, from: raw_data))
    Ok(sec)
}