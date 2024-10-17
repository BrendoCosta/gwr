// rustc --crate-type cdylib --target wasm32-unknown-unknown -C debuginfo=none -C panic=abort -C strip=symbols -C opt-level=3 ./test/assets/rust/misc/fibonacci.rs -o ./test/assets/rust/misc/fibonacci.wasm

#![no_std]

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> !
{
    loop {}
}

#[no_mangle]
pub extern fn fibonacci(value: i32) -> i32
{
    if value <= 0
    {
        return 0;
    }
    else
    {
        if value == 1
        {
            return 1;
        }
        else
        {
            return fibonacci(value - 1) + fibonacci(value - 2);
        }
    }
}