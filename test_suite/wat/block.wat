(module
    (func $block_test (export "block_test") (param $a i32) (param $b i32) (result i32)
        (block $test_block (result i32)
            local.get $a
            local.get $b
            i32.add
        )
        i32.const 2
        i32.add
    )
)