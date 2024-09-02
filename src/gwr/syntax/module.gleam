import gleam/option.{type Option}

import gwr/syntax/convention
import gwr/syntax/instruction
import gwr/syntax/index
import gwr/syntax/types
import gwr/syntax/value

/// WebAssembly programs are organized into modules, which are the unit of deployment,
/// loading, and compilation. A module collects definitions for types, functions, tables,
/// memories, and globals. In addition, it can declare imports and exports and provide
/// initialization in the form of data and element segments, or a start function.
/// 
/// https://webassembly.github.io/spec/core/syntax/modules.html#modules
pub type Module
{
    Module
    (
        types: convention.Vector(types.FunctionType),
        functions: convention.Vector(Function),
        tables: convention.Vector(Table),
        memories: convention.Vector(Memory),
        globals: convention.Vector(Global),
        elements: convention.Vector(ElementSegment),
        datas: convention.Vector(DataSegment),
        start: Option(StartFunction),
        imports: convention.Vector(Import),
        exports: convention.Vector(Export)
    )
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#functions
pub type Function
{
    Function(type_: index.TypeIndex, locals: convention.Vector(types.ValueType), body: instruction.Expression)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#tables
pub type Table
{
    Table(type_: types.TableType)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#memories
pub type Memory
{
    Memory(type_: types.MemoryType)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#globals
pub type Global
{
    Global(type_: types.GlobalType, init: instruction.Expression)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#element-segments
pub type ElementSegmentMode
{
    PassiveElementSegment
    ActiveElementSegment(table: index.TableIndex, offset: instruction.Expression)
    DeclarativeElementSegment
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#element-segments
pub type ElementSegment
{
    ElementSegment(type_: types.ReferenceType, init: convention.Vector(instruction.Expression), mode: ElementSegmentMode)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#data-segments
pub type DataSegmentMode
{
    PassiveDataSegment
    ActiveDataSegment(memory: index.MemoryIndex, offset: instruction.Expression)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#data-segments
pub type DataSegment
{
    DataSegment(init: BitArray, mode: DataSegmentMode)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#start-function
pub type StartFunction
{
    StartFunction(function: index.FunctionIndex)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#imports
pub type ImportDescriptor
{
    FunctionImport(function: index.FunctionIndex)
    TableImport(table: types.TableType)
    MemoryImport(memory: types.MemoryType)
    GlobalImport(global: types.GlobalType)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#imports
pub type Import
{
    Import(module: value.Name, name: value.Name, descriptor: ImportDescriptor)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#exports
pub type ExportDescriptor
{
    FunctionExport(index: index.FunctionIndex)
    TableExport(index: index.TableIndex)
    MemoryExport(index: index.MemoryIndex)
    GlobalExport(index: index.GlobalIndex)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#exports
pub type Export
{
    Export(name: value.Name, descriptor: ExportDescriptor)
}