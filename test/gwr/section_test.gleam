import gleeunit
import gleeunit/should

import gleam/bytes_builder
import gleam/option.{Some, None}

import gwr/section
import gwr/types/limits.{Limits}

pub fn main()
{
    gleeunit.main()
}

pub fn parse_raw_section___custom___test()
{
    section.parse_raw_section(
        at: 0,
        from: <<
            0x00,                   // Section type = "Custom" (0x00)
            0x03,                   // U32 LEB128 section length = 3
            0x0a, 0x0b, 0x0c        // Section content
        >>
    )
    |> should.be_ok
    |> should.equal(section.RawSection(type_id: 0x00, length: 3, content: Some(<<0x0a, 0x0b, 0x0c>>)))

    section.parse_raw_section(
        at: 0,
        from: bytes_builder.from_bit_array(
            <<
                0x00,                   // Section type = "Custom" (0x00)
                0xff, 0x01,             // U32 LEB128 section length = 255
            >>
        )
        |> bytes_builder.append(<<0x00:size(255 * 8)>>) // Section content
        |> bytes_builder.to_bit_array
    )
    |> should.be_ok
    |> should.equal(section.RawSection(type_id: 0x00, length: 255, content: Some(<<0x00:size(255 * 8)>>)))

    section.parse_raw_section(
        at: 0,
        from: bytes_builder.from_bit_array(
            <<
                0x01,                   // Section type = "Type" (0x01)
                0xff, 0x01,             // U32 LEB128 section length = 255
            >>
        )
        |> bytes_builder.append(<<0x00:size(255 * 8)>>) // Section content
        |> bytes_builder.to_bit_array
    )
    |> should.be_ok
    |> should.equal(section.RawSection(type_id: 0x01, length: 255, content: Some(<<0x00:size(255 * 8)>>)))

    section.parse_raw_section(
        at: 0,
        from: bytes_builder.from_bit_array(
            <<
                0x0a,                   // Section type = "Code" (0x0a)
                0x80, 0x89, 0x7a,       // U32 LEB128 section length = 2000000
            >>
        )
        |> bytes_builder.append(<<0xff:size(2000000 * 8)>>) // Section content
        |> bytes_builder.to_bit_array
    )
    |> should.be_ok
    |> should.equal(section.RawSection(type_id: 0x0a, length: 2000000, content: Some(<<0xff:size(2000000 * 8)>>)))

    section.parse_raw_section(
        at: 0,
        from: <<
            0x0b,                   // Section type = "Data" (0x0b)
            0x00,                   // U32 LEB128 section length = 0
        >>
    )
    |> should.be_ok
    |> should.equal(section.RawSection(type_id: 0x0b, length: 0, content: None))
}

pub fn parse_raw_section___unexpected_end___test()
{
    section.parse_raw_section(
        at: 0,
        from: <<
            0x00,                           // Section type = "Custom" (0x00)
            0x09,                           // U32 LEB128 section length = 9
            0x04, 0x74, 0x65, 0x73, 0x74,   // A name with length = 4 and content = "test"
            0x0a, 0x0b, 0x0c                // 3 bytes (1 missing)
        >>
    )
    |> should.be_error
    |> should.equal("section::parse_raw_section: unexpected end of the section's content segment")
}

pub fn decode_section___custom___test()
{
    section.decode_section(
        at: 0,
        from: <<
            0x00,                           // Section type = "Custom" (0x00)
            0x09,                           // U32 LEB128 section length = 9
            0x04, 0x74, 0x65, 0x73, 0x74,   // A name with length = 4 and content = "test"
            0x0a, 0x0b, 0x0c, 0x0d
        >>
    )
    |> should.be_ok
    |> should.equal(section.Custom(length: 9, name: "test", data: Some(<<0x0a, 0x0b, 0x0c, 0x0d>>)))
}

pub fn decode_memory_section_test()
{
    section.decode_section(
        at: 0,
        from: <<
            0x05,                       // Section type = "Memory" (0x05)
            0x07,                       // U32 LEB128 section length = 7
            0x06,                       // A vector with length = 6 and content =
                                        // [
                0x00, 0x03,             //      Limits(min: 3, max: None),
                0x01, 0x20, 0x80, 0x02  //      Limits(min: 32, max: Some(256))
                                        // ]
        >>
    )
    |> should.be_ok
    |> should.equal(section.Memory(length: 7, memories: [Limits(min: 3, max: None), Limits(min: 32, max: Some(256))]))
}

//pub fn decode_section_type_type_test()
//{
//    section.decode_section_type(<<0x01>>)
//    |> should.be_ok
//    |> should.equal(section.Type)
//}
//
//pub fn decode_section_type_import_test()
//{
//    section.decode_section_type(<<0x02>>)
//    |> should.be_ok
//    |> should.equal(section.Import)
//}
//
//pub fn decode_section_type_function_test()
//{
//    section.decode_section_type(<<0x03>>)
//    |> should.be_ok
//    |> should.equal(section.Function)
//}
//
//pub fn decode_section_type_table_test()
//{
//    section.decode_section_type(<<0x04>>)
//    |> should.be_ok
//    |> should.equal(section.Table)
//}
//
//pub fn decode_section_type_memory_test()
//{
//    section.decode_section_type(<<0x05>>)
//    |> should.be_ok
//    |> should.equal(section.Memory)
//}
//
//pub fn decode_section_type_global_test()
//{
//    section.decode_section_type(<<0x06>>)
//    |> should.be_ok
//    |> should.equal(section.Global)
//}
//
//pub fn decode_section_type_export_test()
//{
//    section.decode_section_type(<<0x07>>)
//    |> should.be_ok
//    |> should.equal(section.Export)
//}
//
//pub fn decode_section_type_start_test()
//{
//    section.decode_section_type(<<0x08>>)
//    |> should.be_ok
//    |> should.equal(section.Start)
//}
//
//pub fn decode_section_type_element_test()
//{
//    section.decode_section_type(<<0x09>>)
//    |> should.be_ok
//    |> should.equal(section.Element)
//}
//
//pub fn decode_section_type_code_test()
//{
//    section.decode_section_type(<<0x0a>>)
//    |> should.be_ok
//    |> should.equal(section.Code)
//}
//
//pub fn decode_section_type_data_test()
//{
//    section.decode_section_type(<<0x0b>>)
//    |> should.be_ok
//    |> should.equal(section.Data)
//}
//
//pub fn decode_section_type_datacount_test()
//{
//    section.decode_section_type(<<0x0c>>)
//    |> should.be_ok
//    |> should.equal(section.DataCount)
//}
//
//pub fn decode_section_type_unknown_test()
//{
//    section.decode_section_type(<<0x0d>>)
//    |> should.be_error
//    |> should.equal("decode_section_type: unknown section type \"13\"")
//}
//
//pub fn decode_section_type_empty_test()
//{
//    section.decode_section_type(<<>>)
//    |> should.be_error
//    |> should.equal("decode_section_type: can't get section type raw data")
//}
//
//pub fn from_raw_data_custom_test()
//{
//    section.from_raw_data(
//        at: 0,
//        from: <<
//            0x00,                   // Section type = "Custom" (0x00)
//            0x80, 0x02, 0x00, 0x00, // U32 LEB128 section length = 256
//        >>
//    )
//    |> should.be_ok
//    |> should.equal(section.Section(length: 256, inner_type: section.Custom(data: [])))
//}
//
//pub fn from_raw_data_type_test()
//{
//    <<
//        0x01,                   // Section type = "Type" (0x01)
//        0xd8, 0xa0, 0xd0, 0x07, // U32 LEB128 section length = 15994968
//    >>
//    |> section.from_raw_data
//    |> should.be_ok
//    |> should.equal(section.Section(length: 15994968, inner_type: section.Type))
//}