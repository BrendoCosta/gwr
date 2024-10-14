import gleam/dict
import gleam/dynamic
import gleam/order
import gleam/result

import gwr/syntax/index
import gwr/syntax/module
import gwr/syntax/types
import gwr/syntax/value

import ieee_float

pub const memory_page_size = 65_536
pub const true_ = Integer32(1)
pub const false_ = Integer32(0)

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
    Integer32(value: Int)
    Integer64(value: Int)
    Float32(value: FloatValue)
    Float64(value: FloatValue)
    Vector(Int)
    Reference(ReferenceValueType)
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
        types: List(types.FunctionType),
        function_addresses: dict.Dict(index.FunctionIndex, Address),
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
    WebAssemblyFunctionInstance(type_: types.FunctionType, module_instance: ModuleInstance, code: module.Function)
    HostFunctionInstance(type_: types.FunctionType, code: fn (List(dynamic.Dynamic)) -> List(dynamic.Dynamic))
}

/// A table instance is the runtime representation of a table. It records its type and
/// holds a vector of reference value.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#table-instances
pub type TableInstance
{
    TableInstance(type_: types.TableType, elements: List(Value))
}

/// A memory instance is the runtime representation of a linear memory. It records its
/// type and holds a vector of bytes.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#memory-instances
pub type MemoryInstance
{
    MemoryInstance(type_: types.MemoryType, data: BitArray)
}

/// A global instance is the runtime representation of a global variable. It records its
/// type and holds an individual value.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#global-instances
pub type GlobalInstance
{
    GlobalInstance(type_: types.GlobalType, value: Value)
}

/// An element instance is the runtime representation of an element segment. It holds a
/// vector of references and their common type.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#element-instances
pub type ElementInstance
{
    ElementInstance(type_: types.ReferenceType, element: List(Value))
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
    ExportInstance(name: value.Name, value: ExternalValue)
}

/// An external value is the runtime representation of an entity that can be imported
/// or exported. It is an address denoting either a function instance, table instance,
/// memory instance, or global instances in the shared store.
///
/// https://webassembly.github.io/spec/core/exec/runtime.html#external-values
pub type ExternalValue
{
    Function(Address)
    Table(Address)
    Memory(Address)
    Global(Address)
}

pub fn ieee_float_to_builtin_float(value: ieee_float.IEEEFloat) -> Result(FloatValue, String)
{
    case ieee_float.is_finite(value)
    {
        True ->
        {
            use fin <- result.try(result.replace_error(ieee_float.to_finite(value), "gwr/execution/runtime.ieee_float_to_builtin_float: error converting value to finite"))
            Ok(Finite(fin))
        }
        False -> case ieee_float.is_nan(value)
        {
            True -> Ok(NaN)
            False -> case ieee_float.compare(value, ieee_float.positive_infinity())
            {
                Ok(order.Eq) -> Ok(Infinite(Positive))
                Ok(order.Lt) -> Ok(Infinite(Negative))
                _ -> Error("gwr/execution/runtime.ieee_float_to_builtin_float: unknown error")
            }
        }
    }
}

pub fn builtin_float_to_ieee_float(value: FloatValue) -> Result(ieee_float.IEEEFloat, String)
{
    case value
    {
        Finite(v) -> Ok(ieee_float.finite(v))
        Infinite(Positive) -> Ok(ieee_float.positive_infinity())
        Infinite(Negative) -> Ok(ieee_float.negative_infinity())
        NaN -> Ok(ieee_float.nan())
    }
}
