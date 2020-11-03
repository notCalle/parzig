// SPDX-License-Identifier: MIT
//
// Copyright (c) 2020 Calle Englund
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

const std = @import("std");
const t = std.testing;
const ArgsTuple = std.meta.ArgsTuple;
const zeroInit = std.mem.zeroInit;

usingnamespace @import("meta.zig");

// TODO: Investigate if a more direct approach works in current zig compiler
//
// Ideally the type constructor would just create the curried function type
// Curry(fn (A0, A1, ...) R) -> fn (A1) (fn (A2) ... R) ...)
//
// And curry() would just return the curried function returning ... function.

///
/// Returns an instance of the curried representation of a function
///
/// When called with a n-ary function `f`, it returns a structure that
/// collects the arguments with each successive call to `.apply()`. When
/// called with the final argument, the original function is called and
/// its result is returned.
///
/// ```
/// var add = curry(struct{pub fn f(a: i32, b: i32) i32 {return a+b;}});
/// add.apply(1);
/// expectEqual(@as(i32, 3), add.apply(2));
/// ```
///
/// Arguments:
///     `f: fn(...) R`
///
/// Returns:
///     `Curry(fn (...) R, 0)`
///
pub fn curry(comptime f: anytype) Curry(@TypeOf(f), 0) {
    return Curry(@TypeOf(f), 0).init(f);
}

///
/// Type constructor for curried functions
///
/// Arguments:
///     `Fn`: type signature of function to be curried
///     `index`: next argument index
///
/// Returns:
///     `struct{}`
///
pub fn Curry(comptime Fn: type, comptime index: usize) type {
    const Args = FunctionArgs(Fn);

    return struct {
        const Self = @This();
        const i = index;

        f: Fn,
        args: ArgsTuple(Fn),

        ///
        /// Constructs a curried function instance
        ///
        /// Arguments:
        ///     `f: Fn` function to be curried
        ///
        /// Returns:
        ///     `Curry(Fn, 0)` unapplied instance
        ///
        pub fn init(comptime f: Fn) Self {
            return Self{ .f = f, .args = zeroInit(ArgsTuple(Fn), .{}) };
        }

        pub usingnamespace switch (Args.len - index) {
            0 => struct {
                pub const Ret = ReturnType(Fn);

                ///
                /// Nullary function application
                ///
                /// Returns the result of calling the wrapped function with
                /// the collected arguments.
                ///
                /// Arguments: none
                ///
                /// Returns:
                ///     result of wrapped function
                ///
                pub fn apply(self: Self) Ret {
                    return @call(.{}, self.f, self.args);
                }
            },
            1 => struct {
                pub const Ret = ReturnType(Fn);

                ///
                /// Unary function application
                ///
                /// Collects the final argument to wrapped function, and
                /// returns the result of calling the function with the
                /// collected arguments.
                ///
                /// Arguments:
                ///     `arg: FnArgs[index]` final argument to function
                ///
                /// Returns:
                ///     retult of wrapped function
                ///
                pub fn apply(self: Self, arg: Args[index]) Ret {
                    var new = self;
                    new.args[Self.i] = arg;
                    return @call(.{}, self.f, new.args);
                }
            },
            else => struct {
                pub const Ret = Curry(Fn, index + 1);

                ///
                /// N-ary function application
                ///
                /// Collects the next argument to wrapped function
                ///
                /// Arguments:
                ///     `arg: FnArgs[index]` next argument to function
                ///
                /// Returns:
                ///     `Curry(Fn, index + 1)`
                ///
                pub fn apply(self: Self, arg: Args[index]) Ret {
                    var new = @bitCast(Ret, self);

                    new.args[index] = arg;
                    return new;
                }
            },
        };
    };
}

test "curry nullary function" {
    const f = curry(testFn0);
    try t.expectEqual(@as(i32, 0), f.apply());
}
fn testFn0() i32 {
    return 0;
}

test "curry unary function" {
    const f = curry(testFn1);
    try t.expectEqual(@as(i32, 1), f.apply(1));
}
fn testFn1(a: i32) i32 {
    return a;
}

test "curry binary function" {
    const f = curry(testFn2);
    try t.expectEqual(@as(i32, 3), f.apply(1).apply(2));
}
fn testFn2(a: i32, b: i32) i32 {
    return a + b;
}

test "curry ternary function" {
    const f = curry(testFn3);
    try t.expectEqual(@as(i32, 6), f.apply(1).apply(2).apply(3));
}
fn testFn3(a: i32, b: i32, c: i32) i32 {
    return a + b + c;
}
