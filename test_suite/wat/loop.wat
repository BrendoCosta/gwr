(module
    (func $loop_test (export "loop_test") (result i32)
        (local $i i32)
        (loop $test_loop
            local.get $i
            i32.const 1
            i32.add
            
            local.set $i
            
            local.get $i
            i32.const 10
            i32.lt_s

            br_if $test_loop
        )
        local.get $i
    )
)