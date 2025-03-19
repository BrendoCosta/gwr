import gleam/option

import gwr/execution/debug

pub opaque type Trap
{
    Trap(kind: Kind, message: option.Option(String), stacktrace: List(debug.Stacktrace))
}

pub type Kind
{
    Unknown
    BadArgument
    IndexOutOfBounds
    // Numeric traps
    DivisionByZero
    Overflow
}

pub fn make(kind: Kind) -> Trap
{
    Trap(kind:, message: option.None, stacktrace: debug.get_stacktrace())
}

pub fn add_message(trap: Trap, message: String) -> Trap
{
    Trap(..trap, message: option.Some(message)) 
}

pub fn to_error(trap: Trap) -> Result(a, Trap)
{
    Error(trap)
}

pub fn kind(trap: Trap) -> Kind
{
    trap.kind
}