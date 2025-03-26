(module
    ;; if ($a == 0)
    ;;     return $accumulator
    ;; else
    ;;     return recursion_test($a - 1, $accumulator + 2)
    (func $recursion_test (export "recursion_test") (param $a i32) (param $accumulator i32) (result i32)
        local.get $a
        i32.const 0
            i32.eq
        if (result i32)
            local.get $accumulator
                return
        else
            local.get $a
            i32.const 1
                i32.sub
            local.get $accumulator
            i32.const 2
                i32.add
            call $recursion_test
                return
        end
    )
)