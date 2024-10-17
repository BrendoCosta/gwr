;; wat2wasm ./test/assets/wat/misc/fibonacci.wat -o ./test/assets/wat/misc/fibonacci.wasm
(module
    (func $fibonacci (export "fibonacci") (param $value i32) (result i32)
        (if (result i32)
            (i32.le_s (local.get $value) (i32.const 0))
            (then
                (return (i32.const 0))
            )
            (else
                (if (result i32)
                    (i32.eq (local.get $value) (i32.const 1))
                    (then
                        (return (i32.const 1))
                    )
                    (else
                        (return
                            (i32.add
                                (call $fibonacci (i32.sub (local.get $value) (i32.const 1)))
                                (call $fibonacci (i32.sub (local.get $value) (i32.const 2)))
                            )
                        )
                    )
                )
            )
        )
    )
)