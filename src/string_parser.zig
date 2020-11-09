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
const mem = std.mem;
const u = std.unicode;

const t = @import("testing.zig");
const Input = @import("input.zig");

usingnamespace @import("ghost_party.zig");
usingnamespace @import("meta.zig");
usingnamespace @import("parser.zig");
usingnamespace @import("result.zig");

const Str = []const u8;

/// Constructs a parser that returns `[]const u8` "String" slices
/// Because the string type matches the input type, the combinators
/// abuse the fact that adjacent slices can be merged.
pub fn StringParser(comptime P: type) type {
    return struct {
        pub usingnamespace Parser(P);

        pub const Many = Repeat(0, null);
        pub const Many1 = Repeat(1, null);
        pub const Opt = Repeat(0, 1);

        pub fn Repeat(min: usize, max: ?usize) type {
            return StringParser(struct {
                pub fn parse(input: Input) Result(Str) {
                    var tail = input;
                    var n: usize = 0;
                    var res: Result(Str) = undefined;

                    while (max == null or n <= max.?) : (n += 1) {
                        switch (P.parse(tail)) {
                            .None => |r| {
                                res = Result(Str).fail(r);
                                break;
                            },
                            .Some => |r| {
                                tail = r.tail;
                            },
                        }
                    }
                    if (n >= min) {
                        res = Result(Str).some(input.diff(tail), tail);
                    }
                    return res;
                }
            });
        }

        pub fn Plus(comptime next: type) type {
            return StringParser(struct {
                pub fn parse(input: Input) Result(Str) {
                    var tail = input;

                    switch (P.parse(tail)) {
                        .None => |r| return Result(Str).fail(r),
                        .Some => |r| {
                            tail = r.tail;
                        },
                    }
                    switch (next.parse(tail)) {
                        .None => |r| return Result(Str).fail(r),
                        .Some => |r| {
                            tail = r.tail;
                        },
                    }
                    return Result(Str).some(input.diff(tail), tail);
                }
            });
        }
    };
}

pub fn String(comptime str: Str) type {
    return StringParser(struct {
        pub fn parse(input: Input) Result(Str) {
            if (!mem.eql(u8, input.peek(str.len), str)) {
                return Result([]const u8).none();
            }

            return Result([]const u8).some(str, input.take(str.len));
        }
    });
}

test "parse string" {
    try t.expectSome(String("👻🥳"), "👻🥳");
    try t.expectNone(String("👻🥳"), "👻👻");
}

pub fn Char(comptime char: u21) type {
    return StringParser(struct {
        pub fn parse(input: Input) Result(Str) {
            return CharRange(char, char).parse(input);
        }
    });
}

test "parse code point" {
    try t.expectSomeEqualSlice(u8, "👻", Char('👻'), "👻");
    try t.expectNone(Char('👻'), "");
}

pub fn CharRange(comptime low: u21, high: u21) type {
    const none = Result(Str).none;

    return StringParser(struct {
        pub fn parse(input: Input) Result(Str) {
            if (input.len() < 1) return none();

            const len = u.utf8ByteSequenceLength(input.peek(1)[0]) catch return none();
            const char = u.utf8Decode(input.peek(len)) catch return none();

            if (low <= char and char <= high) {
                return Result(Str).some(input.peek(len), input.take(len));
            }
            return none();
        }
    });
}

test "parse range of matching code points" {
    var c: u8 = 'a';

    while (c <= 'z') : (c += 1) {
        const s: [1]u8 = .{c};
        try t.expectSomeEqualSlice(u8, s[0..], CharRange('a', 'z'), s[0..]);
    }
}

test "parse range of non-matching code points" {
    var c: u8 = 'a';

    while (c <= 'z') : (c += 1) {
        const s: [1]u8 = .{c};
        try t.expectNone(CharRange('A', 'Z'), s[0..]);
    }
}

// MARK: StringParser Combinator Tests

test "parse a string of many" {
    const ghost_ghost = ghost ** 2;

    try t.expectSomeEqualSlice(u8, ghost_ghost, Char('👻').Many, ghost_ghost);
    try t.expectSomeEqualSlice(u8, ghost, Char('👻').Many, ghost_party);
    try t.expectSomeEqualSlice(u8, "", Char('👻').Many, party_ghost);
}

test "parse a string of at least one" {
    const ghost_ghost = ghost ** 2;

    try t.expectSomeEqualSlice(u8, ghost_ghost, Char('👻').Many1, ghost_ghost);
    try t.expectSomeEqualSlice(u8, ghost, Char('👻').Many1, ghost_party);
    try t.expectNone(Char('👻').Many1, party_ghost);
}

test "parse a sequence of strings" {
    try t.expectSomeEqualSlice(u8, ghost_party, Char('👻').Plus(Char('🥳')), ghost_party);
    try t.expectNone(Char('👻').Plus(Char('🥳')), party_ghost);
}

test "parse intergers" {
    const Number = Char('-').Opt.Plus(CharRange('0', '9').Many1);
    const Int = Number.Map(testStrToInt);

    try t.expectSomeExactlyEqual(-42, Int, "-42");
    try t.expectSomeExactlyEqual(17, Int, "17");
    try t.expectNone(Int, "x");
}
fn testStrToInt(str: []const u8) i32 {
    return std.fmt.parseInt(i32, str, 10) catch unreachable;
}
