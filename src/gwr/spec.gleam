import gleam/dict
import gleam/dynamic
import gleam/option

import ieee_float

/// ***************************************************************************
/// syntax/convention
/// ***************************************************************************

/// https://webassembly.github.io/spec/core/syntax/conventions.html#vectors
pub type Vector(a) = List(a)

/// ***************************************************************************
/// syntax/index
/// ***************************************************************************

pub type TypeIndex = Int
pub type FunctionIndex = Int
pub type TableIndex = Int
pub type MemoryIndex = Int
pub type GlobalIndex = Int
pub type ElementIndex = Int
pub type DataIndex = Int
pub type LocalIndex = Int
pub type LabelIndex = Int

/// ***************************************************************************
/// syntax/instruction
/// ***************************************************************************

/// https://webassembly.github.io/spec/core/syntax/instructions.html#control-instructions
pub type BlockType
{
    TypeIndexBlock(index: TypeIndex)
    ValueTypeBlock(type_: option.Option(ValueType))
}

pub type Instruction
{
    /// https://webassembly.github.io/spec/core/binary/instructions.html#control-instructions
    Unreachable
    NoOp
    Block(block_type: BlockType, instructions: List(Instruction))
    Loop(block_type: BlockType, instructions: List(Instruction))
    If(block_type: BlockType, instructions: List(Instruction), else_: option.Option(Instruction))
    Else(instructions: Expression)
    Br(index: LabelIndex)
    BrIf(index: LabelIndex)
    BrTable(label: LabelIndex)
    Return
    Call(index: FunctionIndex)
    CallIndirect(table: TableIndex, type_: TypeIndex)
    /// https://webassembly.github.io/spec/core/binary/instructions.html#variable-instructions
    LocalGet(index: LocalIndex)
    LocalSet(index: LocalIndex)
    LocalTee(index: LocalIndex)

    /// https://webassembly.github.io/spec/core/binary/instructions.html#numeric-instructions
    
    I32Const(value: Int)
    I64Const(value: Int)
    F32Const(value: ieee_float.IEEEFloat)
    F64Const(value: ieee_float.IEEEFloat)
    
    I32Eqz
    I32Eq
    I32Ne
    I32LtS
    I32LtU
    I32GtS
    I32GtU
    I32LeS
    I32LeU
    I32GeS
    I32GeU

    I64Eqz
    I64Eq
    I64Ne
    I64LtS
    I64LtU
    I64GtS
    I64GtU
    I64LeS
    I64LeU
    I64GeS
    I64GeU

    F32Eq
    F32Ne
    F32Lt
    F32Gt
    F32Le
    F32Ge

    F64Eq
    F64Ne
    F64Lt
    F64Gt
    F64Le
    F64Ge

    I32Clz
    I32Ctz
    I32Popcnt
    I32Add
    I32Sub
    I32Mul
    I32DivS
    I32DivU
    I32RemS
    I32RemU
    I32And
    I32Or
    I32Xor
    I32Shl
    I32ShrS
    I32ShrU
    I32Rotl
    I32Rotr

    I64Clz
    I64Ctz
    I64Popcnt
    I64Add
    I64Sub
    I64Mul
    I64DivS
    I64DivU
    I64RemS
    I64RemU
    I64And
    I64Or
    I64Xor
    I64Shl
    I64ShrS
    I64ShrU
    I64Rotl
    I64Rotr

    F32Abs
    F32Neg
    F32Ceil
    F32Floor
    F32Trunc
    F32Nearest
    F32Sqrt
    F32Add
    F32Sub
    F32Mul
    F32Div
    F32Min
    F32Max
    F32Copysign

    F64Abs
    F64Neg
    F64Ceil
    F64Floor
    F64Trunc
    F64Nearest
    F64Sqrt
    F64Add
    F64Sub
    F64Mul
    F64Div
    F64Min
    F64Max
    F64Copysign

    I32WrapI64
    I32TruncF32S
    I32TruncF32U
    I32TruncF64S
    I32TruncF64U
    I64ExtendI32S
    I64ExtendI32U
    I64TruncF32S
    I64TruncF32U
    I64TruncF64S
    I64TruncF64U
    F32ConvertI32S
    F32ConvertI32U
    F32ConvertI64S
    F32ConvertI64U
    F32DemoteF64
    F64ConvertI32S
    F64ConvertI32U
    F64ConvertI64S
    F64ConvertI64U
    F64PromoteF32
    I32ReinterpretF32
    I64ReinterpretF64
    F32ReinterpretI32
    F64ReinterpretI64

    I32Extend8S
    I32Extend16S
    I64Extend8S
    I64Extend16S
    I64Extend32S

    I32TruncSatF32S
    I32TruncSatF32U
    I32TruncSatF64S
    I32TruncSatF64U
    I64TruncSatF32S
    I64TruncSatF32U
    I64TruncSatF64S
    I64TruncSatF64U

    /// https://webassembly.github.io/spec/core/binary/instructions.html#expressions
    End
}

/// Function bodies, initialization values for globals, elements and offsets
/// of element segments, and offsets of data segments are given as expressions,
/// which are sequences of instructions terminated by an <end> marker.
/// 
/// https://webassembly.github.io/spec/core/syntax/instructions.html#expressions
pub type Expression = List(Instruction)

/// ***************************************************************************
/// syntax/module
/// ***************************************************************************

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
        types: Vector(FunctionType),
        functions: Vector(Function),
        tables: Vector(Table),
        memories: Vector(Memory),
        globals: Vector(Global),
        elements: Vector(ElementSegment),
        datas: Vector(DataSegment),
        start: option.Option(StartFunction),
        imports: Vector(Import),
        exports: Vector(Export)
    )
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#functions
pub type Function
{
    Function(type_: TypeIndex, locals: Vector(ValueType), body: Expression)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#tables
pub type Table
{
    Table(type_: TableType)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#memories
pub type Memory
{
    Memory(type_: MemoryType)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#globals
pub type Global
{
    Global(type_: GlobalType, init: Expression)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#element-segments
pub type ElementSegmentMode
{
    PassiveElementSegment
    ActiveElementSegment(table: TableIndex, offset: Expression)
    DeclarativeElementSegment
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#element-segments
pub type ElementSegment
{
    ElementSegment(type_: ReferenceType, init: Vector(Expression), mode: ElementSegmentMode)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#data-segments
pub type DataSegmentMode
{
    PassiveDataSegment
    ActiveDataSegment(memory: MemoryIndex, offset: Expression)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#data-segments
pub type DataSegment
{
    DataSegment(init: BitArray, mode: DataSegmentMode)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#start-function
pub type StartFunction
{
    StartFunction(function: FunctionIndex)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#imports
pub type ImportDescriptor
{
    FunctionImport(function: FunctionIndex)
    TableImport(table: TableType)
    MemoryImport(memory: MemoryType)
    GlobalImport(global: GlobalType)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#imports
pub type Import
{
    Import(module: Name, name: Name, descriptor: ImportDescriptor)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#exports
pub type ExportDescriptor
{
    FunctionExport(index: FunctionIndex)
    TableExport(index: TableIndex)
    MemoryExport(index: MemoryIndex)
    GlobalExport(index: GlobalIndex)
}

/// https://webassembly.github.io/spec/core/syntax/modules.html#exports
pub type Export
{
    Export(name: Name, descriptor: ExportDescriptor)
}

/// ***************************************************************************
/// syntax/types
/// ***************************************************************************

/// Number types classify numeric values.
/// 
/// https://webassembly.github.io/spec/core/syntax/html#number-types
pub type NumberType
{
    Integer32
    Integer64
    Float32
    Float64
}

/// Vector types classify vectors of numeric values processed by vector instructions (also known as SIMD instructions, single instruction multiple data).
/// 
/// https://webassembly.github.io/spec/core/syntax/html#vector-types
pub type VectorType
{
    Vector128
}

/// Reference types classify first-class references to objects in the runtime store.
/// 
/// https://webassembly.github.io/spec/core/syntax/html#reference-types
pub type ReferenceType
{
    FunctionReference
    ExternReference
}

/// Value types classify the individual values that WebAssembly code can compute
/// with and the values that a variable accepts. They are either number types,
/// vector types, or reference 
/// 
/// https://webassembly.github.io/spec/core/syntax/html#value-types
pub type ValueType
{
    Number(NumberType)
    Vector(VectorType)
    Reference(ReferenceType)
}

/// Result types classify the result of executing instructions or functions,
/// which is a sequence of values, written with brackets.
/// 
/// https://webassembly.github.io/spec/core/syntax/html#result-types
pub type ResultType = List(ValueType)

/// Function types classify the signature of functions, mapping a vector of parameters
/// to a vector of results. They are also used to classify the inputs and outputs of instructions.
/// 
/// https://webassembly.github.io/spec/core/syntax/html#function-types
pub type FunctionType
{
    FunctionType(parameters: List(ValueType), results: List(ValueType))
}

/// Limits classify the size range of resizeable storage associated with memory types and table 
/// 
/// https://webassembly.github.io/spec/core/syntax/html#limits
pub type Limits
{
    Limits(min: Int, max: option.Option(Int))
}

/// Memory types classify linear memories and their size range.
/// 
/// https://webassembly.github.io/spec/core/syntax/html#memory-types
pub type MemoryType = Limits

/// Table types classify tables over elements of reference type within a size range.
/// 
/// https://webassembly.github.io/spec/core/syntax/html#syntax-tabletype
pub type TableType
{
    TableType(limits: Limits, elements: ReferenceType)
}

pub type Mutability
{
    Constant
    Variable
}

/// Global types classify global variables, which hold a value and can either be mutable or immutable.
/// 
/// https://webassembly.github.io/spec/core/syntax/html#global-types
pub type GlobalType
{
    GlobalType(mutability: Mutability, value_type: ValueType)
}

/// External types classify imports and external values with their respective 
/// 
/// https://webassembly.github.io/spec/core/syntax/html#external-types
pub type ExternalType
{
    ExternalFunction(FunctionType)
    ExternalTable(TableType)
    ExternalMemory(MemoryType)
    ExternalGlobal(GlobalType)
}

/// ***************************************************************************
/// syntax/value
/// ***************************************************************************

/// Names are sequences of characters, which are scalar values as defined by Unicode (Section 2.4).
/// 
/// https://webassembly.github.io/spec/core/syntax/values.html#names
pub type Name = String

/// ***************************************************************************
/// execution/runtime
/// ***************************************************************************

pub const memory_page_size = 65_536

/// https://webassembly.github.io/spec/core/exec/numerics.html#boolean-interpretation
pub const true_ = Integer32Value(1)
pub const false_ = Integer32Value(0)

pub type ReferenceValueType
{
    NullReference
    ToFunctionAddress(Address)
    ToExternAddress(Address)
}

pub type FloatValue
{
    Finite(value: Float)
    Infinite(sign: Sign)
    NaN
}

pub type Sign
{
    Positive
    Negative
}

/// https://webassembly.github.io/spec/core/exec/runtime.html#values
pub type Value
{
    Integer32Value(value: Int)
    Integer64Value(value: Int)
    Float32Value(value: FloatValue)
    Float64Value(value: FloatValue)
    VectorValue(Int)
    ReferenceValue(ReferenceValueType)
}

pub const number_value_default_value = 0
pub const vector_value_default_value = 0
pub const reference_value_default_value = NullReference

/// A result is the outcome of a computation. It is either a sequence of values or a trap.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#results
pub type ExecutionResult
{
    Success(List(Value))
    Trap
}

/// Labels carry an argument arity <n> and their associated branch target, which is expressed
/// syntactically as an instruction sequence:
/// 
/// https://webassembly.github.io/spec/core/exec/runtime.html#labels
pub type Label
{
    Label(arity: Int, continuation: List(Instruction))
}

/// Activation frames carry the return arity <n> of the respective function, hold the values of
/// its locals (including arguments) in the order corresponding to their static local indices, and
/// a reference to the function’s own module instance:
/// 
/// https://webassembly.github.io/spec/core/exec/runtime.html#activation-frames
pub type Frame
{
    Frame(arity: Int, framestate: FrameState)
}

/// https://webassembly.github.io/spec/core/exec/runtime.html#activation-frames
pub type FrameState
{
    FrameState(locals: dict.Dict(Int, Value), module_instance: ModuleInstance)
}

/// https://webassembly.github.io/spec/core/exec/runtime.html#addresses
pub type Address
{
    FunctionAddress(Int)
    TableAddress(Int)
    MemoryAddress(Int)
    GlobalAddress(Int)
    ElementAddress(Int)
    DataAddress(Int)
    ExternAddress(Int)
}

/// A module instance is the runtime representation of a module. It is created by instantiating
/// a module, and collects runtime representations of all entities that are imported, defined,
/// or exported by the module.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#module-instances
pub type ModuleInstance
{
    ModuleInstance
    (
        types: List(FunctionType),
        function_addresses: dict.Dict(FunctionIndex, Address),
        table_addresses: List(Address),
        memory_addresses: List(Address),
        global_addresses: List(Address),
        element_addresses: List(Address),
        data_addresses: List(Address),
        exports: List(ExportInstance),
    )
}

/// A function instance is the runtime representation of a function. It effectively is a
/// closure of the original function over the runtime module instance of its originating
/// module. The module instance is used to resolve references to other definitions during
/// execution of the function.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#function-instances
pub type FunctionInstance
{
    WebAssemblyFunctionInstance(type_: FunctionType, module_instance: ModuleInstance, code: Function)
    HostFunctionInstance(type_: FunctionType, code: fn (List(dynamic.Dynamic)) -> List(dynamic.Dynamic))
}

/// A table instance is the runtime representation of a table. It records its type and
/// holds a vector of reference value.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#table-instances
pub type TableInstance
{
    TableInstance(type_: TableType, elements: List(Value))
}

/// A memory instance is the runtime representation of a linear memory. It records its
/// type and holds a vector of bytes.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#memory-instances
pub type MemoryInstance
{
    MemoryInstance(type_: MemoryType, data: BitArray)
}

/// A global instance is the runtime representation of a global variable. It records its
/// type and holds an individual value.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#global-instances
pub type GlobalInstance
{
    GlobalInstance(type_: GlobalType, value: Value)
}

/// An element instance is the runtime representation of an element segment. It holds a
/// vector of references and their common type.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#element-instances
pub type ElementInstance
{
    ElementInstance(type_: ReferenceType, element: List(Value))
}

/// An data instance is the runtime representation of a data segment. It holds a vector of bytes.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#data-instances
pub type DataInstance
{
    DataInstance(data: BitArray)
}

/// An export instance is the runtime representation of an export. It defines
/// the export’s name and the associated external value.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#export-instances
pub type ExportInstance
{
    ExportInstance(name: Name, value: ExternalValue)
}

/// An external value is the runtime representation of an entity that can be imported
/// or exported. It is an address denoting either a function instance, table instance,
/// memory instance, or global instances in the shared store.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#external-values
pub type ExternalValue
{
    FunctionExternalValue(Address)
    TableExternalValue(Address)
    MemoryExternalValue(Address)
    GlobalExternalValue(Address)
}

/// ***************************************************************************
/// execution/store
/// ***************************************************************************

/// The store represents all global state that can be manipulated by WebAssembly programs.
/// It consists of the runtime representation of all instances of functions, tables, memories,
/// and globals, element segments, and data segments that have been allocated during the
/// life time of the abstract machine.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#store
pub type Store
{
    Store
    (
        functions: dict.Dict(Address, FunctionInstance),
        tables: List(TableInstance),
        memories: List(MemoryInstance),
        globals: List(GlobalInstance),
        elements: List(ElementInstance),
        datas: List(DataInstance),
    )
}

/// ***************************************************************************
/// gwr/binary
/// ***************************************************************************

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
        module: Module
    )
}

/// Each section consists of
///     - a one-byte section id,
///     - the u32 size of the contents, in bytes,
///     - the actual contents, whose structure is dependent on the section id.
/// https://webassembly.github.io/spec/core/binary/module.html#sections
pub type Section
{
    Section(id: Int, length: Int, content: option.Option(SectionContent))
}

pub type SectionContent
{
    /// Custom sections have the id 0. They are intended to be used for debugging information
    /// or third-party extensions, and are ignored by the WebAssembly semantics. Their contents
    /// consist of a name further identifying the custom section, followed by an uninterpreted
    /// sequence of bytes for custom use.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#custom-section
    CustomSection(name: String, data: option.Option(BitArray))
    
    /// The type section has the id 1. It decodes into a vector of function types that represent
    /// the component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#type-section
    TypeSection(function_types: Vector(FunctionType))
    
    // @TODO
    ImportSection
    
    /// The function section has the id 3. It decodes into a vector of type indices that represent
    /// the <type> fields of the functions in the <funcs> component of a module. The <locals> and
    /// <body> fields of the respective functions are encoded separately in the code section.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#function-section
    FunctionSection(type_indices: Vector(Int))
    
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
    MemorySection(memories: Vector(Memory))
    
    /// The global section has the id 6. It decodes into a vector of globals that represent the <globals>
    /// component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/modules.html#global-section
    GlobalSection(globals: Vector(Global))
    
    /// The export section has the id 7. It decodes into a vector of exports that represent the exports
    /// component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/module.html#export-section
    ExportSection(exports: Vector(Export))
    
    /// The start section has the id 8. It decodes into an optional start function that represents the
    /// <start> component of a module.
    /// 
    /// https://webassembly.github.io/spec/core/binary/modules.html#start-section
    StartSection(start_function: StartFunction)
    
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
    FunctionCode(locals: Vector(LocalsDeclaration), body: Expression)
}

pub type LocalsDeclaration
{
    LocalsDeclaration(count: Int, type_: ValueType)
}