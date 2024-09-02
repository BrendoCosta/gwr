import gleam/option.{type Option}

/// Number types classify numeric values.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#number-types
pub type NumberType
{
    Integer32
    Integer64
    Float32
    Float64
}

/// Vector types classify vectors of numeric values processed by vector instructions (also known as SIMD instructions, single instruction multiple data).
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#vector-types
pub type VectorType
{
    Vector128
}

/// Reference types classify first-class references to objects in the runtime store.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#reference-types
pub type ReferenceType
{
    FunctionReference
    ExternReference
}

/// Value types classify the individual values that WebAssembly code can compute
/// with and the values that a variable accepts. They are either number types,
/// vector types, or reference types.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#value-types
pub type ValueType
{
    Number(NumberType)
    Vector(VectorType)
    Reference(ReferenceType)
}

/// Result types classify the result of executing instructions or functions,
/// which is a sequence of values, written with brackets.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#result-types
pub type ResultType = List(ValueType)

/// Function types classify the signature of functions, mapping a vector of parameters
/// to a vector of results. They are also used to classify the inputs and outputs of instructions.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#function-types
pub type FunctionType
{
    FunctionType(parameters: List(ValueType), results: List(ValueType))
}

/// Limits classify the size range of resizeable storage associated with memory types and table types.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#limits
pub type Limits
{
    Limits(min: Int, max: Option(Int))
}

/// Memory types classify linear memories and their size range.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#memory-types
pub type MemoryType = Limits

/// Table types classify tables over elements of reference type within a size range.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#syntax-tabletype
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
/// https://webassembly.github.io/spec/core/syntax/types.html#global-types
pub type GlobalType
{
    GlobalType(mutability: Mutability, value_type: ValueType)
}

/// External types classify imports and external values with their respective types.
/// 
/// https://webassembly.github.io/spec/core/syntax/types.html#external-types
pub type ExternalType
{
    Function(FunctionType)
    Table(TableType)
    Memory(MemoryType)
    Global(GlobalType)
}