(module
    (func $fib (export "fib") (param $value i32) (result i32)
        local.get $value
        i32.const 0
        i32.le_s
        if
            i32.const 0
            return
        end

        local.get $value
        i32.const 2
        i32.le_s
        if
            i32.const 1
            return
        end

        local.get $value
        i32.const 1
        i32.sub
        call $fib
        
        local.get $value
        i32.const 2
        i32.sub
        call $fib
        
        i32.add
        
        return
    )
)