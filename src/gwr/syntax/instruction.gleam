import gleam/option.{type Option}

import gwr/syntax/index
import gwr/syntax/types

/// https://webassembly.github.io/spec/core/syntax/instructions.html#control-instructions
pub type BlockType
{
    EmptyBlock
    TypeIndexBlock(index: index.TypeIndex)
    ValueTypeBlock(type_: types.ValueType)
}

pub type Instruction
{
    /// https://webassembly.github.io/spec/core/binary/instructions.html#control-instructions
    Unreachable
    NoOp
    Block(block_type: BlockType, instructions: List(Instruction))
    Loop(block_type: BlockType, instructions: List(Instruction))
    If(block_type: BlockType, instructions: List(Instruction), else_: Option(Instruction))
    Else(instructions: Expression)
    Br(index: index.LabelIndex)
    BrIf(label: index.LabelIndex)
    BrTable(label: index.LabelIndex)
    Return
    Call(function: index.FunctionIndex)
    CallIndirect(table: index.TableIndex, type_: index.TypeIndex)
    /// https://webassembly.github.io/spec/core/binary/instructions.html#variable-instructions
    LocalGet(index: index.LocalIndex)

    /// https://webassembly.github.io/spec/core/binary/instructions.html#numeric-instructions
    
    I32Const(value: Int)
    I64Const(value: Int)
    F32Const(value: Float)
    F64Const(value: Float)
    
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
    F32Gt
    F32Le
    F32Ge

    F64Eq
    F64Ne
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