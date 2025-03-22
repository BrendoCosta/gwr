(module
    (func $sum (param $a i32) (param $b i32) (result i32)
        local.get $a
        local.get $b
        i32.add
    )
    (func $call_test (export "call_test") (param $a i32) (param $b i32) (result i32)
        local.get $a
        local.get $b
        call $sum
    )
)