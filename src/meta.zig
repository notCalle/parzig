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
const TypeInfo = std.builtin.TypeInfo;
const t = std.testing;

fn Function(comptime Fn: type) TypeInfo.Fn {
    switch (@typeInfo(Fn)) {
        .Fn, .BoundFn => |F| return F,
        else => @compileError("'" ++ @typeName(Fn) ++ "' is not a function type"),
    }
}

pub fn ReturnType(comptime Fn: type) type {
    if (Function(Fn).return_type) |rt| {
        return rt;
    } else {
        @compileError("'" ++ @typeName(Fn) ++ "' has no return type");
    }
}

test "Function returning void" {
    try t.expectEqual(void, ReturnType(fn () void));
}

test "Function returning function" {
    try t.expectEqual(fn (i32) i32, ReturnType(fn (i32, i32) (fn (i32) i32)));
}

///
/// Creates an array slice with the argument types for a function type
///
/// Arguments:
///     `Fn: comptime fn (...)`
///
/// Returns:
///     `[]type` of argument types for the given function type
///
pub fn FunctionArgs(comptime Fn: type) []type {
    const ArgsTuple = std.meta.ArgsTuple(Fn);
    const args: ArgsTuple = undefined;
    var Args: [args.len]type = undefined;

    inline for (args) |arg, i| {
        Args[i] = @TypeOf(args[i]);
    }
    return Args[0..];
}

/// Returns the `Result(T)` for a given `Parser`
pub fn ParseResult(comptime P: type) type {
    return ReturnType(@TypeOf(@field(P, "parse")));
}
