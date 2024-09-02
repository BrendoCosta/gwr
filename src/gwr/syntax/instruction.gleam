import gwr/syntax/index

pub type Instruction
{
    /// https://webassembly.github.io/spec/core/binary/instructions.html#control-instructions
    Unreachable
    NoOp
    /// https://webassembly.github.io/spec/core/binary/instructions.html#variable-instructions
    LocalGet(index: index.LocalIndex)
    /// https://webassembly.github.io/spec/core/binary/instructions.html#numeric-instructions
    I32Add
    I32Const(value: Int)
    /// https://webassembly.github.io/spec/core/binary/instructions.html#expressions
    End
}

/// Function bodies, initialization values for globals, elements and offsets
/// of element segments, and offsets of data segments are given as expressions,
/// which are sequences of instructions terminated by an <end> marker.
/// 
/// https://webassembly.github.io/spec/core/syntax/instructions.html#expressions
pub type Expression = List(Instruction)