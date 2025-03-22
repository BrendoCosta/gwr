(module
    (func $recursion_test (export "recursion_test") (param $a i32) (param $accumulator i32) (result i32)
        (if (result i32)
            (i32.eq (local.get $a) (i32.const 0))
            (then
                (return (local.get $accumulator))
            )
            (else
                (call $recursion_test
                    (i32.sub (local.get $a) (i32.const 1))
                    (i32.add (local.get $accumulator) (i32.const 2))
                )
            )
        )
    )
)