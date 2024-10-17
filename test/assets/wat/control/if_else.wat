;; wat2wasm ./test/assets/control/if_else.wat -o ./test/assets/control/if_else.wasm
(module
    (func $if_else_test (export "if_else_test") (param $a i32) (result i32)
        local.get $a
        i32.eqz
        (if (result i32)
            (then
                i32.const 10
            )
            (else
                i32.const 20
            )
        )
        i32.const 100
        i32.add
    )
)