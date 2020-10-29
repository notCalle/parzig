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

pub fn StringParser(comptime P: type) type {
    assert(isParser(P));
    assert(ParseResult(P).T == Str);

    return Parser(struct {
        const T = []const u8;

        usingnamespace (P);
    });
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
