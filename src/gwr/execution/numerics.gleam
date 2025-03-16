import gleam/int
import gleam/result

import gwr/execution/trap

fn two_power_n(n: Int) -> Int
{
    int.bitwise_shift_left(1, n)
}

fn two_power_n_minus_one(n: Int) -> Int
{
    int.bitwise_shift_left(1, n - 1)
}

/// https://webassembly.github.io/spec/core/exec/numerics.html#sign-interpretation
pub fn interpret_as_signed(n: Int, i: Int) -> Int
{
    case 0 <= i && i < two_power_n_minus_one(n)
    {
        True -> i
        _ -> i - two_power_n(n)
    }
}

/// https://webassembly.github.io/spec/core/exec/numerics.html#boolean-interpretation
pub fn interpret_as_bool(c: Bool) -> Int
{
    case c
    {
        True -> 1
        _ -> 0
    }
}

/// Return the result of adding i_1 and i_2 modulo 2^N.
/// 
/// \begin{array}{@{}lcll}{\mathrm{iadd}}_N(i_1, i_2) &=& (i_1 + i_2) \mathbin{\mathrm{mod}} 2^N\end{array}
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html#xref-exec-numerics-op-iadd-mathrm-iadd-n-i-1-i-2
pub fn iadd(n: Int, i_1: Int, i_2: Int) -> Int
{
    { i_1 + i_2 } % two_power_n(n)
}

/// Return the result of subtracting i_2 from i_1 modulo 2^N.
/// 
/// \begin{array}{@{}lcll}{\mathrm{isub}}_N(i_1, i_2) &=& (i_1 - i_2 + 2^N) \mathbin{\mathrm{mod}} 2^N\end{array}
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html#xref-exec-numerics-op-isub-mathrm-isub-n-i-1-i-2
pub fn isub(n: Int, i_1: Int, i_2: Int) -> Int
{
    { i_1 - i_2 + two_power_n(n) } % two_power_n(n)
}

/// Return the result of multiplying i_2 and i_1 modulo 2^N.
/// 
/// \begin{array}{@{}lcll}{\mathrm{imul}}_N(i_1, i_2) &=& (i_1 \cdot i_2) \mathbin{\mathrm{mod}} 2^N\end{array}
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html#xref-exec-numerics-op-imul-mathrm-imul-n-i-1-i-2
pub fn imul(n: Int, i_1: Int, i_2: Int) -> Int
{
    { i_1 * i_2 } % two_power_n(n)
}

/// https://webassembly.github.io/spec/core/exec/numerics.html#xref-exec-numerics-op-idiv-u-mathrm-idiv-u-n-i-1-i-2
pub fn idiv_u(i_1: Int, i_2: Int) -> Result(Int, trap.Trap)
{
    case i_2
    {
        // If i_2 is 0, then the result is undefined.
        0 -> trap.make(trap.DivisionByZero)
             |> trap.to_error()
        _ ->
        {
            // Else, return the result of dividing i_1 by i_2, truncated toward zero.
            result.replace_error(int.divide(i_1, i_2), trap.make(trap.DivisionByZero))
        }
    }
}

/// https://webassembly.github.io/spec/core/exec/numerics.html#xref-exec-numerics-op-idiv-s-mathrm-idiv-s-n-i-1-i-2
pub fn idiv_s(n: Int, i_1: Int, i_2: Int) -> Result(Int, trap.Trap)
{
    // Let j_1 be the signed interpretation of i_1.
    let j_1 = interpret_as_signed(n, i_1)
    // Let j_2 be the signed interpretation of i_2.
    let j_2 = interpret_as_signed(n, i_2)
    let two_power_n_minus_one = two_power_n_minus_one(n)
    case j_2
    {
        // If j_2 is 0, then the result is undefined.
        0 -> trap.make(trap.DivisionByZero)
             |> trap.to_error()
        _ -> case j_1 / j_2
        {
            // Else if j_1 divided by j_2 is 2^{N-1}, then the result is undefined.
            x if x == two_power_n_minus_one -> trap.make(trap.Overflow)
                                               |> trap.to_error()
            _ ->
            {
                // Else, return the result of dividing j_1 by j_2, truncated toward zero.
                result.replace_error(int.divide(i_1, i_2), trap.make(trap.DivisionByZero))
            }
        }
    }
}

/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-irem-u-mathrm-irem-u-n-i-1-i-2
pub fn irem_u(i_1: Int, i_2: Int) -> Result(Int, trap.Trap)
{
    case i_2
    {
        // If i_2 is 0, then the result is undefined.
        0 -> trap.make(trap.DivisionByZero)
             |> trap.to_error()
        _ ->
        {
            // Else, return the remainder of dividing i_1 by i_2.
            result.replace_error(int.remainder(i_1, i_2), trap.make(trap.DivisionByZero))
        }
    }
}

/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-irem-s-mathrm-irem-s-n-i-1-i-2
pub fn irem_s(n: Int, i_1: Int, i_2: Int) -> Result(Int, trap.Trap)
{
    // 1. Let j_1 be the signed interpretation of i_1.
    let j_1 = interpret_as_signed(n, i_1)
    // 2. Let j_2 be the signed interpretation of i_2.
    let j_2 = interpret_as_signed(n, i_2)
    case i_2
    {
        // If i_2 is 0, then the result is undefined.
        0 -> trap.make(trap.DivisionByZero)
             |> trap.to_error()
        _ ->
        {
            // Else, return the remainder of dividing j_1 by j_2, with the sign of the dividend j_1.
            result.replace_error(int.remainder(j_1, j_2), trap.make(trap.DivisionByZero))
        }
    }
}

/// Return the bitwise negation of i.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-inot-mathrm-inot-n-i
pub fn inot(n: Int, i: Int) -> Int
{
    int.bitwise_exclusive_or(i, two_power_n_minus_one(n))
}

/// Return the bitwise conjunction of i_1 and i_2.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-iand-mathrm-iand-n-i-1-i-2
pub fn iand(i_1: Int, i_2: Int) -> Int
{
    int.bitwise_and(i_1, i_2)
}

/// Return the bitwise conjunction of i_1 and the bitwise negation of i_2.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-iandnot-mathrm-iandnot-n-i-1-i-2
pub fn iandnot(n: Int, i_1: Int, i_2: Int) -> Int
{
    iand(i_1, inot(n, i_2))
}

/// Return the bitwise disjunction of i_1 and i_2.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ior-mathrm-ior-n-i-1-i-2
pub fn ior(i_1: Int, i_2: Int) -> Int
{
    int.bitwise_or(i_1, i_2)
}

/// Return the bitwise exclusive disjunction of i_1 and i_2.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ixor-mathrm-ixor-n-i-1-i-2
pub fn ixor(i_1: Int, i_2: Int) -> Int
{
    int.bitwise_exclusive_or(i_1, i_2)
}

// ishl
// ishr_u
// ishr_s
// irotl
// irotr

fn iclz_32(i: Int) -> Int
{
    case i
    {
        0 -> 32
        _ ->
        {
            let n = 0
            let #(n, i) = case i <= 0x0000ffff
            {
                True -> #(n + 16, int.bitwise_shift_left(i, 16) |> int.bitwise_and(0xffffffff))
                False -> #(n, i)
            }
            let #(n, i) = case i <= 0x00ffffff
            {
                True -> #(n + 8, int.bitwise_shift_left(i, 8) |> int.bitwise_and(0xffffffff))
                False -> #(n, i)
            }
            let #(n, i) = case i <= 0x0fffffff
            {
                True -> #(n + 4, int.bitwise_shift_left(i, 4) |> int.bitwise_and(0xffffffff))
                False -> #(n, i)
            }
            let #(n, i) = case i <= 0x3fffffff
            {
                True -> #(n + 2, int.bitwise_shift_left(i, 2) |> int.bitwise_and(0xffffffff))
                False -> #(n, i)
            }
            let n = case i <= 0x7fffffff
            {
                True -> n + 1
                False -> n
            }
            n
        }
    }
}

fn iclz_64(i: Int) -> Int
{
    case i
    {
        0 -> 64
        _ ->
        {
            let low = int.bitwise_and(i, 0x00000000ffffffff)
            let high = int.bitwise_shift_right(i, 32)
            case high
            {
                0 -> 32 + iclz_32(low)
                _ -> iclz_32(high)
            }
        }
    }
}

/// Return the count of leading zero bits in i; all bits are considered leading zeros if i is 0.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-iclz-mathrm-iclz-n-i
pub fn iclz(n: Int, i: Int) -> Result(Int, trap.Trap)
{
    case n
    {
        32 -> Ok(iclz_32(i))
        64 -> Ok(iclz_64(i))
        _ -> trap.make(trap.BadArgument)
             |> trap.add_message("The iclz operation is currently implemented only for 32 and 64-bit integers")
             |> trap.to_error()
    }
}

fn ictz_32(i: Int) -> Int
{
    case i
    {
        0 -> 32
        _ ->
        {
            let n = 0
            let #(n, i) = case int.bitwise_and(i, 0x0000ffff)
            {
                0 -> #(n + 16, int.bitwise_shift_right(i, 16))
                _ -> #(n, i)
            }
            let #(n, i) = case int.bitwise_and(i, 0x000000ff)
            {
                0 -> #(n + 8, int.bitwise_shift_right(i, 8))
                _ -> #(n, i)
            }
            let #(n, i) = case int.bitwise_and(i, 0x0000000f)
            {
                0 -> #(n + 4, int.bitwise_shift_right(i, 4))
                _ -> #(n, i)
            }
            let #(n, i) = case int.bitwise_and(i, 0x00000003)
            {
                0 -> #(n + 2, int.bitwise_shift_right(i, 2))
                _ -> #(n, i)
            }
            let n = case int.bitwise_and(i, 0x00000001)
            {
                0 -> n + 1
                _ -> n
            }
            n
        }
    }
}

fn ictz_64(i: Int) -> Int
{
    case i
    {
        0 -> 64
        _ ->
        {
            let low = int.bitwise_and(i, 0x00000000ffffffff)
            let high = int.bitwise_shift_right(i, 32)
            case low
            {
                0 -> 32 + ictz_32(high)
                _ -> ictz_32(low)
            }
        }
    }
}

/// Return the count of trailing zero bits in i; all bits are considered trailing zeros if i is 0.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ictz-mathrm-ictz-n-i
pub fn ictz(n: Int, i: Int) -> Result(Int, trap.Trap)
{
    case n
    {
        32 -> Ok(ictz_32(i))
        64 -> Ok(ictz_64(i))
        _ -> trap.make(trap.BadArgument)
             |> trap.add_message("The ictz operation is currently implemented only for 32 and 64-bit integers")
             |> trap.to_error()
    }
}

fn ipopcnt_32(i: Int) -> Int
{
    case i
    {
        0 -> 0
        _ ->
        {
            let i = int.bitwise_and(i, 0x55555555) + int.bitwise_and(int.bitwise_shift_right(i, 1), 0x55555555)
            let i = int.bitwise_and(i, 0x33333333) + int.bitwise_and(int.bitwise_shift_right(i, 2), 0x33333333)
            let i = int.bitwise_and(i, 0x0f0f0f0f) + int.bitwise_and(int.bitwise_shift_right(i, 4), 0x0f0f0f0f)
            let i = int.bitwise_and(i, 0x00ff00ff) + int.bitwise_and(int.bitwise_shift_right(i, 8), 0x00ff00ff)
            let i = int.bitwise_and(i, 0x0000ffff) + int.bitwise_and(int.bitwise_shift_right(i, 16), 0x0000ffff)
            i
        }
    }
}

fn ipopcnt_64(i: Int) -> Int
{
    case i
    {
        0 -> 0
        _ ->
        {
            let low_cnt = ipopcnt_32(i)
            let high_cnt = ipopcnt_32(int.bitwise_shift_right(i, 32))
            low_cnt + high_cnt
        }
    }
}

/// Return the count of non-zero bits in i.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ipopcnt-mathrm-ipopcnt-n-i
pub fn ipopcnt(n: Int, i: Int) -> Result(Int, trap.Trap)
{
    case n
    {
        32 -> Ok(ipopcnt_32(i))
        64 -> Ok(ipopcnt_64(i))
        _ -> trap.make(trap.BadArgument)
             |> trap.add_message("The ipopcnt operation is currently implemented only for 32 and 64-bit integers")
             |> trap.to_error()
    }
}

/// Return 1 if i is zero, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ieqz-mathrm-ieqz-n-i
pub fn ieqz(i: Int) -> Int
{
    case i
    {
        0 -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 equals i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ieq-mathrm-ieq-n-i-1-i-2
pub fn ieq(i_1: Int, i_2: Int) -> Int
{
    case i_1 == i_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 does not equal i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ine-mathrm-ine-n-i-1-i-2
pub fn ine(i_1: Int, i_2: Int) -> Int
{
    case i_1 != i_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is less than i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ilt-u-mathrm-ilt-u-n-i-1-i-2
pub fn ilt_u(i_1: Int, i_2: Int) -> Int
{
    case i_1 < i_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is less than i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ilt-s-mathrm-ilt-s-n-i-1-i-2
pub fn ilt_s(n: Int, i_1: Int, i_2: Int) -> Int
{
    // 1. Let j_1 be the signed interpretation of i_1.
    let j_1 = interpret_as_signed(n, i_1)
    // 2. Let j_2 be the signed interpretation of i_2.
    let j_2 = interpret_as_signed(n, i_2)
    // 3. Return 1 if j_1 is less than j_2, 0 otherwise.
    case j_1 < j_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is greater than i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-igt-u-mathrm-igt-u-n-i-1-i-2
pub fn igt_u(i_1: Int, i_2: Int) -> Int
{
    case i_1 > i_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is greater than i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-igt-s-mathrm-igt-s-n-i-1-i-2
pub fn igt_s(n: Int, i_1: Int, i_2: Int) -> Int
{
    // 1. Let j_1 be the signed interpretation of i_1.
    let j_1 = interpret_as_signed(n, i_1)
    // 2. Let j_2 be the signed interpretation of i_2.
    let j_2 = interpret_as_signed(n, i_2)
    // 3. Return 1 if j_1 is greater than j_2, 0 otherwise.
    case j_1 > j_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is less than or equal to i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ile-u-mathrm-ile-u-n-i-1-i-2
pub fn ile_u(i_1: Int, i_2: Int) -> Int
{
    case i_1 <= i_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is less than or equal to i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ile-s-mathrm-ile-s-n-i-1-i-2
pub fn ile_s(n: Int, i_1: Int, i_2: Int) -> Int
{
    // 1. Let j_1 be the signed interpretation of i_1.
    let j_1 = interpret_as_signed(n, i_1)
    // 2. Let j_2 be the signed interpretation of i_2.
    let j_2 = interpret_as_signed(n, i_2)
    // 3. Return 1 if j_1 is less than or equal to j_2, 0 otherwise.
    case j_1 <= j_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is greater than or equal to i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ige-u-mathrm-ige-u-n-i-1-i-2
pub fn ige_u(i_1: Int, i_2: Int) -> Int
{
    case i_1 >= i_2
    {
        True -> 1
        _ -> 0
    }
}

/// Return 1 if i_1 is greater than or equal to i_2, 0 otherwise.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ige-s-mathrm-ige-s-n-i-1-i-2
pub fn ige_s(n: Int, i_1: Int, i_2: Int) -> Int
{
    // 1. Let j_1 be the signed interpretation of i_1.
    let j_1 = interpret_as_signed(n, i_1)
    // 2. Let j_2 be the signed interpretation of i_2.
    let j_2 = interpret_as_signed(n, i_2)
    // 3. Return 1 if j_1 is greater than or equal to j_2, 0 otherwise.
    case j_1 >= j_2
    {
        True -> 1
        _ -> 0
    }
}

// iextendM_s

/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ibitselect-mathrm-ibitselect-n-i-1-i-2-i-3
pub fn ibitselect(i_1: Int, i_2: Int, i_3: Int) -> Int
{
    // 1. Let j_1 be the bitwise conjunction of i_1 and i_3.
    let j_1 = int.bitwise_and(i_1, i_3)
    // 2. Let j_3 be the bitwise negation of i_3.
    let j_3 = int.bitwise_not(i_3)
    // 3. Let j_2 be the bitwise conjunction of i_2 and j_3.
    let j_2 = int.bitwise_and(i_2, j_3)
    // 4. Return the bitwise disjunction of j_1 and j_2.
    int.bitwise_or(j_1, j_2)
}

/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-iabs-mathrm-iabs-n-i
pub fn iabs(n: Int, i: Int) -> Int
{
    // 1. Let j be the signed interpretation of i.
    let j = interpret_as_signed(n, i)
    // 2. If j is greater than or equal to 0, then return i.
    case j >= 0
    {
        True -> i
        _ ->
        {
            // 3. Else return the negation of j, modulo 2^N.
            int.negate(j) % two_power_n(n)
        }
    }
}

/// Return the result of negating i, modulo 2^N.
/// 
/// https://webassembly.github.io/spec/core/exec/numerics.html?highlight=test#xref-exec-numerics-op-ineg-mathrm-ineg-n-i
pub fn ineg(n: Int, i: Int) -> Int
{
    { two_power_n(n) - i } % two_power_n(n)
}

