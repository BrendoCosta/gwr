#![no_std]

#[panic_handler]
pub fn panic(_info: &core::panic::PanicInfo) -> !
{
    loop {}
}

#[unsafe(no_mangle)]
pub extern fn fib(value: i32) -> i32
{
    match value
    {
        v if v <= 0 => 0,
        v if v == 1 => 1,
        _ => fib(value - 1) + fib(value - 2)
    }
}