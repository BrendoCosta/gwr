import gleam/bit_array
import gleam/result

import gleb128

pub type Module
{
    Module
    (
        version: Int
    )
}

pub fn try_detect_signature(raw_data: BitArray) -> Bool
{
    case bit_array.slice(at: 0, from: raw_data, take: 4)
    {
        Ok(<<0x00, 0x61, 0x73, 0x6d>>) -> True
        _ -> False
    }
}

pub fn get_module_version(raw_data: BitArray) -> Result(Int, String)
{
    case bit_array.slice(at: 4, from: raw_data, take: 4)
    {
        Ok(version_raw_data) ->
        {
            use version <- result.try(gleb128.decode_unsigned(version_raw_data))
            Ok(version.0)
        }
        _ -> Error("module::get_module_version: can't get module version raw data")
    }
}

pub fn from_raw_data(raw_data: BitArray) -> Result(Module, String)
{
    case try_detect_signature(raw_data)
    {
        True ->
        {
            use version <- result.try(get_module_version(raw_data))
            Ok(Module(version: version))
        }
        False -> Error("Can't detect module signature")
    }
}