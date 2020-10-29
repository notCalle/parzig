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

pub const Input = []const u8;

pub const Reason = struct {};

/// Constructs a `Result(T)` type for a parser of `T`, wrapping either
/// `.Some` successfull parse result, or a reason for `.None`.
pub fn Result(comptime _T: type) type {
    return union(enum) {
        // Keep in sync with `meta.isResult`
        const Self = @This();

        /// The type of parse result values wrapped by this `Result(T)`
        pub const T = _T;

        Some: struct { value: T, tail: Input },
        None: ?Reason,

        /// Returns `.Some` successful parse result
        pub fn some(result: T, remaining: Input) Self {
            return .{
                .Some = .{
                    .value = result,
                    .tail = remaining,
                },
            };
        }

        /// Returns `.None` without any explanation for a parse failure
        pub fn none() Self {
            return .{ .None = null };
        }

        /// Returns `.None` with a reason, explaining the parse failure
        pub fn fail(why: ?Reason) Self {
            return .{ .None = why };
        }

        /// Unwraps `.Some` parsed value, returning null if there was `.None`
        pub fn value(self: Self) ?T {
            switch (self) {
                .Some => |r| return r.value,
                .None => return null,
            }
        }

        /// Unwraps `.Some` tail of input, returning null if there was `.None`
        pub fn tail(self: Self) ?Input {
            switch (self) {
                .Some => |r| return r.tail,
                .None => return null,
            }
        }
    };
}
