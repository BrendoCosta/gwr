(module
    (type $t0 (func (param i32 i32) (result i32)))
    (func $sum (export "sum") (type $t0) (param $p0 i32) (param $p1 i32) (result i32)
        (i32.add (local.get $p0) (local.get $p1))
    )
)