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
const t = std.testing;

usingnamespace @import("ghost_party.zig");
usingnamespace @import("meta.zig");
usingnamespace @import("result.zig");
usingnamespace @import("string_parser.zig");

/// Constructs a parser from a struct with a single `fn parse(Input)Result(T)`
pub fn Parser(comptime P: type) type {
    assert(isParser(P));

    return struct {
        // Keep in sync with `meta.isParser`
        const Self = @This();
        pub const T = ParseResult(P).T;
        pub usingnamespace (P);

        pub fn Alt(comptime alt: type) type {
            return Parser(struct {
                pub fn parse(input: Input) Result(T) {
                    const r = Self.parse(input);
                    if (.Some == r) return r;
                    return alt.parse(input);
                }
            });
        }

        /// Functor `map` function. Constructs a parser that calls `map(T)U` to
        /// transform a parse `Result(T)` to a parse `Result(U)`.
        pub fn Map(comptime U: type, comptime map: anytype) type {
            assert(U == ReturnType(map));

            return Parser(struct {
                pub fn parse(input: Input) Result(U) {
                    switch (Self.parse(input)) {
                        .Some => |r| return Result(U).some(map(r.value), r.tail),
                        .None => |r| return Result(U).fail(r),
                    }
                }
            });
        }

        /// Monadic `bind`/`flatMap` function. Constructs a parser that calls
        /// `map(T)Result(U)` to transform a parse `Result(T)` to a parse `Result(U)`.
        pub fn Bind(comptime U: type, comptime map: anytype) type {
            assert(isParseFn(map));

            return Parser(struct {
                pub fn parse(input: Input) Result(U) {
                    switch (Self.parse(input)) {
                        .Some => |r| return map(r.value),
                        .None => |r| return Result(U).fail(r),
                    }
                }
            });
        }
    };
}

/// A parser that always fails
pub fn Fail(comptime T: type, comptime why: ?Reason) type {
    return Parser(struct {
        pub fn parse(input: Input) Result(T) {
            return Result(T).fail(why);
        }
    });
}

test "parse failure" {
    t.expect(.None == Fail(void, null).parse(""));
}

/// A parser that successfully matches nothing
pub const Nothing = Parser(struct {
    pub fn parse(input: Input) Result(void) {
        return Result(void).some({}, input);
    }
});

test "parse nothing" {
    const res = Nothing.parse(ghost);

    t.expectEqual({}, res.value().?);
    t.expectEqualSlices(u8, ghost, res.tail().?);
}

/// A parser that matches nothing if there is nothing left
pub const End = Parser(struct {
    pub fn parse(input: Input) Result(void) {
        if (input.len != 0) return Result(void).none();

        return Result(void).some({}, input);
    }
});

test "parse end of input" {
    t.expectEqual({}, End.parse("").value().?);
    t.expect(.None == End.parse("👻"));
}

pub fn Not(comptime parser: type) type {
    assert(isParser(parser));

    return Parser(struct {
        pub fn parse(input: Input) Result(void) {
            switch (parser.parse(input)) {
                .Some => return Result(void).none(),
                .None => return Result(void).some({}, input),
            }
        }
    });
}

test "non matching look-ahead" {
    t.expect(.None == Not(Char('👻')).parse(ghost_party));
    t.expect(.Some == Not(Char('🥳')).parse(ghost_party));
}

pub fn Optional(comptime parser: anytype) type {
    assert(isParser(parser));
    const T = parser.T;

    return Parser(struct {
        pub fn parse(input: Input) Result(?T) {
            switch (parser.parse(input)) {
                .Some => |r| return Result(?T).some(r.value, r.tail),
                .None => return Result(?T).some(null, input),
            }
        }
    });
}

test "optional" {
    const P = Optional(Char('👻'));

    t.expectEqualSlices(u8, ghost, P.parse(ghost_party).value().?.?);
    t.expect(null == P.parse(party_ghost).value().?);
}

test "alternatives" {
    const P = Char('🥳').Alt(Char('👻'));

    t.expectEqualSlices(u8, ghost, P.parse(ghost_party).value().?);
    t.expectEqualSlices(u8, party, P.parse(party_ghost).value().?);
}

test "compile" {
    t.refAllDecls(@This());
}
