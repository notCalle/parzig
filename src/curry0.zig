///
/// Returns the curried function type for a function type
///
/// Arguments:
///     `Fn: comptime fn (...) R` n-ary function type
///
/// Returns:
///     `fn (A0) (fn (A1) ... R)...)
///
pub fn Curry(comptime Fn: type) type {
    const Args = FunctionArgs(Fn);
    const Ret = ReturnType(Fn);

    switch (Args.len) {
        0 => return fn () Ret,
        1 => return fn (Args[0]) Ret,
        2 => return fn (Args[0]) (fn (Args[1]) Ret),
        3 => return fn (Args[0]) (fn (Args[1]) (fn (Args[2]) Ret)),
        4 => return fn (Args[0]) (fn (Args[1]) (fn (Args[2]) (fn (Args[3]) Ret))),
        5 => return fn (Args[0]) (fn (Args[1]) (fn (Args[2]) (fn (Args[3]) (fn (Args[4]) Ret)))),
        6 => return fn (Args[0]) (fn (Args[1]) (fn (Args[2]) (fn (Args[3]) (fn (Args[4]) (fn (Args[5]) Ret))))),
        7 => return fn (Args[0]) (fn (Args[1]) (fn (Args[2]) (fn (Args[3]) (fn (Args[4]) (fn (Args[5]) (fn (Args[6]) Ret)))))),

        else => @compileError("'" ++ @typeName(Fn) ++ "' is more than 7-ary"),
    }
}

test "Curry nullary function type" {
    t.expectEqual(
        fn () i32,
        Curry(fn () i32),
    );
}

test "Curry unary function type" {
    t.expectEqual(
        fn (i32) i32,
        Curry(fn (i32) i32),
    );
}

test "Curry binary function type" {
    t.expectEqual(
        fn (i32) (fn (i32) i32),
        Curry(fn (i32, i32) i32),
    );
}

test "Curry heptary function type" {
    t.expectEqual(
        fn (i32) (fn (i32) (fn (i32) (fn (i32) (fn (i32) (fn (i32) (fn (i32) i32)))))),
        Curry(fn (i32, i32, i32, i32, i32, i32, i32) i32),
    );
}
