import gleeunit
import gleeunit/should

import gwr/module

pub fn main()
{
    gleeunit.main()
}

pub fn try_detect_signature_test()
{
    module.try_detect_signature(<<0x00, 0x61, 0x73, 0x6d>>)
    |> should.be_true
}

pub fn get_module_version_test()
{
    module.get_module_version(<<0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00>>)
    |> should.be_ok
    |> should.equal(1)
}

pub fn get_module_version_should_fail_parse_module_version_test()
{
    module.get_module_version(<<0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00>>)
    |> should.be_error
    |> should.equal("module::get_module_version: can't get module version raw data")
}

pub fn get_module_version_should_fail_invalid_module_test()
{
    module.get_module_version(<<0x00, 0x61, 0x73, 0x6d>>)
    |> should.be_error
    |> should.equal("module::get_module_version: can't get module version raw data")
}

pub fn from_raw_data_test()
{
    module.from_raw_data(<<0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00>>)
    |> should.be_ok
    |> should.equal(module.Module(version: 1))
}