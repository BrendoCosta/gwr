import gleam/option.{type Option}

import gwr/syntax/convention
import gwr/syntax/instruction
import gwr/syntax/types
import gwr/syntax/module

/// https://webassembly.github.io/spec/core/binary/module.html#sections
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

pub type Binary
{
    Binary
    (
        version: Int,
        length: Int,
        module: module.Module
    )
}

/// Each section consists of
///     - a one-byte section id,
///     - the u32 size of the contents, in bytes,
///     - the actual contents, whose structure is dependent on the section id.
/// https://webassembly.github.io/spec/core/binary/module.html#sections
pub type Section
{
    Section(id: Int, length: Int, content: Option(SectionContent))
}

pub type SectionContent
{
    /// Custom sections have the id 0. They are intended to be used for debugging information
    /// or third-party extensions, and are ignored by the WebAssembly semantics. Their contents
    /// consist of a name further identifying the custom section, followed by an uninterpreted
    /// sequence of bytes for custom use.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#custom-section
    CustomSection(name: String, data: Option(BitArray))
    
    /// The type section has the id 1. It decodes into a vector of function types that represent
    /// the component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#type-section
    TypeSection(function_types: convention.Vector(types.FunctionType))
    
    // @TODO
    ImportSection
    
    /// The function section has the id 3. It decodes into a vector of type indices that represent
    /// the <type> fields of the functions in the <funcs> component of a module. The <locals> and
    /// <body> fields of the respective functions are encoded separately in the code section.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#function-section
    FunctionSection(type_indices: convention.Vector(Int))
    
    /// The table section has the id 4. It decodes into a vector of tables that represent the <table>
    /// component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/modules.html#table-section
    // @TODO
    TableSection
    
    /// The memory section has the id 5. It decodes into a vector of memories that represent the <mems>
    /// component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/modules.html#memory-section
    MemorySection(memories: convention.Vector(module.Memory))
    
    /// The global section has the id 6. It decodes into a vector of globals that represent the <globals>
    /// component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/modules.html#global-section
    GlobalSection(globals: convention.Vector(module.Global))
    
    /// The export section has the id 7. It decodes into a vector of exports that represent the exports
    /// component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#export-section
    ExportSection(exports: convention.Vector(module.Export))
    
    /// The start section has the id 8. It decodes into an optional start function that represents the
    /// <start> component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/modules.html#start-section
    StartSection(start_function: module.StartFunction)
    
    // @TODO
    ElementSection
    
    CodeSection(entries: List(Code))
    
    // @TODO
    DataSection
    
    // @TODO
    DataCountSection
}

// https://webassembly.github.io/spec/core/binary/module.html#code-section
pub type Code
{
    Code(size: Int, function_code: FunctionCode)
}

pub type FunctionCode
{
    FunctionCode(locals: convention.Vector(LocalsDeclaration), body: instruction.Expression)
}

pub type LocalsDeclaration
{
    LocalsDeclaration(count: Int, type_: types.ValueType)
}