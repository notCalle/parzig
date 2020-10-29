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
const assert = std.debug.assert;
const mem = std.mem;
const t = std.testing;
const u = std.unicode;

usingnamespace @import("ghost_party.zig");
usingnamespace @import("meta.zig");
usingnamespace @import("parser.zig");
usingnamespace @import("result.zig");

const Str = []const u8;

/// Constructs a parser that returns `[]const u8` "String" slices
/// Because the string type matches the input type, the combinators
/// abuse the fact that adjacent slices can be merged.
pub fn StringParser(comptime P: type) type {
    assert(isParser(P));
    assert(ParseResult(P).T == Str);

    return struct {
        const Self = @This();

        pub usingnamespace (Parser(P));

        pub const Many = Repeat(0, null);
        pub const Many1 = Repeat(1, null);
        pub const Opt = Repeat(0, 1);

        pub fn Repeat(min: usize, max: ?usize) type {
            return StringParser(struct {
                pub fn parse(input: Input) Result(Str) {
                    var tail = input;
                    var len: usize = 0;
                    var n: usize = 0;
                    var res: Result(Str) = undefined;

                    while (max == null or n <= max.?) : (n += 1) {
                        switch (Self.parse(tail)) {
                            .None => |r| {
                                res = Result(Str).fail(r);
                                break;
                            },
                            .Some => |r| {
                                len += r.value.len;
                                tail = r.tail;
                            },
                        }
                    }
                    if (n >= min) {
                        res = Result(Str).some(input[0..len], tail);
                    }
                    return res;
                }
            });
        }

        pub fn Seq(comptime next: type) type {
            assert(isParser(next));
            assert(Self.T == next.T);

            return StringParser(struct {
                pub fn parse(input: Input) Result(Str) {
                    var len: usize = 0;
                    var tail = input;

                    switch (Self.parse(tail)) {
                        .None => |r| return Result(Str).fail(r),
                        .Some => |r| {
                            len += r.value.len;
                            tail = r.tail;
                        },
                    }
                    switch (next.parse(tail)) {
                        .None => |r| return Result(Str).fail(r),
                        .Some => |r| {
                            len += r.value.len;
                            tail = r.tail;
                        },
                    }
                    return Result(Str).some(input[0..len], tail);
                }
            });
        }
    };
}

pub fn String(comptime str: Str) type {
    return StringParser(struct {
        pub fn parse(input: Input) Result(Str) {
            if (!mem.startsWith(u8, input, str)) {
                return Result([]const u8).none();
            }

            return Result([]const u8).some(str, input[str.len..]);
        }
    });
}

test "parse string" {
    const P = String("👻🥳");
    t.expect(.Some == P.parse("👻🥳"));
    t.expect(.None == P.parse("👻👻"));
}

pub fn Char(comptime char: u21) type {
    return StringParser(struct {
        pub fn parse(input: Input) Result(Str) {
            return CharRange(char, char).parse(input);
        }
    });
}

test "parse code point" {
    const P = Char('👻');
    t.expectEqualSlices(u8, "👻", P.parse("👻").value().?);
    t.expect(.None == P.parse(""));
}

pub fn CharRange(comptime low: u21, high: u21) type {
    const low_len = u.utf8CodepointSequenceLength(low) catch unreachable;
    const none = Result(Str).none;

    return StringParser(struct {
        pub fn parse(input: Input) Result(Str) {
            if (input.len < 1) return none();

            const len = u.utf8ByteSequenceLength(input[0]) catch return none();
            const char = u.utf8Decode(input[0..len]) catch return none();

            if (low <= char and char <= high) {
                return Result(Str).some(input[0..len], input[len..]);
            }
            return none();
        }
    });
}

test "parse range of matching code points" {
    const P = CharRange('a', 'z');
    var c: u8 = 'a';

    while (c <= 'z') : (c += 1) {
        const s: [1]u8 = .{c};
        t.expect(.Some == P.parse(s[0..]));
    }
}

test "parse range of non-matching code points" {
    const P = CharRange('A', 'Z');
    var c: u8 = 'a';

    while (c <= 'z') : (c += 1) {
        const s: [1]u8 = .{c};
        t.expect(.None == P.parse(s[0..]));
    }
}

// MARK: StringParser Combinator Tests

test "parse a string of many" {
    const P = Char('👻').Many;
    const ghost_ghost = ghost ** 2;

    t.expectEqualSlices(u8, ghost_ghost, P.parse(ghost_ghost).value().?);
    t.expectEqualSlices(u8, ghost, P.parse(ghost_party).value().?);
    t.expectEqualSlices(u8, "", P.parse(party_ghost).value().?);
}

test "parse a string of at least one" {
    const P = Char('👻').Many1;
    const ghost_ghost = ghost ** 2;

    t.expectEqualSlices(u8, ghost_ghost, P.parse(ghost_ghost).value().?);
    t.expectEqualSlices(u8, ghost, P.parse(ghost_party).value().?);
    t.expect(.None == P.parse(party_ghost));
}

test "parse a sequence of strings" {
    const P = Char('👻').Seq(Char('🥳'));

    t.expectEqualSlices(u8, ghost_party, P.parse(ghost_party).value().?);
    t.expect(.None == P.parse(party_ghost));
}

test "parse intergers" {
    const Number = Char('-').Opt.Seq(CharRange('0', '9').Many1);
    const Int = Number.Map(i32, testStrToInt);

    t.expectEqual(@as(i32, -42), Int.parse("-42").value().?);
    t.expectEqual(@as(i32, 17), Int.parse("17").value().?);
    t.expect(.None == Int.parse("x"));
}
fn testStrToInt(str: []const u8) i32 {
    return std.fmt.parseInt(i32, str, 10) catch unreachable;
}
