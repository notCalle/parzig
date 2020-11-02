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

usingnamespace @import("ghost_party.zig");
usingnamespace @import("meta.zig");
usingnamespace @import("result.zig");
usingnamespace @import("string_parser.zig");

///
/// Base type constructor for ParZig parsers
///
/// Constructs a parser from a partial parser.
///
/// Arguments:
///     `P`: parser type struct
///     `P.T`: value type of parse results
///     `P.parse`: parser function `Input -> Result(T)`
///
/// Returns:
///     `Parser{ .T = P.T }
///
pub fn Parser(comptime P: type) type {
    return struct {
        // Keep in sync with `meta.isParser`
        const Self = @This();

        /// Value type of parse results
        pub const T = ParseResult(P).T;

        pub usingnamespace (P);

        ///
        /// Functor `map` combinator
        ///
        /// Constructs a parser that calls a function `f` to transform a parse
        /// `Result(T)` to a parse `Result(U)`.
        ///
        /// Arguments:
        ///     `f`: transform function `Self.T -> U`
        ///
        /// Returns:
        ///     `Parser{ .T = U }`
        ///
        pub fn Map(comptime U: type, comptime map: anytype) type {
            return Parser(struct {
                pub fn parse(input: Input) Result(U) {
                    switch (Self.parse(input)) {
                        .Some => |r| return Result(U).some(map(r.value), r.tail),
                        .None => |r| return Result(U).fail(r),
                    }
                }
            });
        }

        ///
        /// Alternative sequence combinator `<|>`
        ///
        /// Constructs a parser that runs two parsers and returns the leftmost
        /// successful result, or the rightmost failure reason.
        ///
        /// Arguments:
        ///     `R`: right side parser
        ///
        /// Conditions:
        ///     `Self.T == R.T`
        ///
        /// Returns:
        ///     `Result(T)`
        ///
        pub fn Alt(comptime R: type) type {
            return Parser(struct {
                pub fn parse(input: Input) Result(T) {
                    const r = Self.parse(input);
                    if (.Some == r) return r;
                    return R.parse(input);
                }
            });
        }

        ///
        /// Left sequence combinator `<*`
        ///
        /// Constructs a parser that runs two parsers, returning the left
        /// result when both are successful. If either parser fails, the
        /// leftmost failure is returned.
        ///
        /// Arguments:
        ///     `R`: right side parser
        ///
        /// Returns:
        ///     `Parser{.T = Self.T}`
        ///
        pub fn SeqL(comptime R: type) type {
            return Parser(struct {
                pub fn parse(input: Input) Result(T) {
                    switch (Self.parse(input)) {
                        .None => |r| return Result(T).fail(r),
                        .Some => |left| //
                        switch (R.parse(left.tail)) {
                            .None => |r| return Result(T).fail(r),
                            .Some => //
                            return Result(T).some(left.value, left.tail),
                        },
                    }
                }
            });
        }

        ///
        /// Right sequence combinator `*>`
        ///
        /// Constructs a parser that runs two parsers, returning the right
        /// result when both are successful. If either parser fails, the
        /// leftmost failure is returned, wrapped as the right result.
        ///
        /// Arguments:
        ///     `R`: right side parser
        ///
        /// Returns:
        ///     `Parser{.T = R.T}`
        ///
        pub fn SeqR(comptime R: type) type {
            const U = R.T;

            return Parser(struct {
                pub fn parse(input: Input) Result(U) {
                    switch (Self.parse(input)) {
                        .None => |r| return Result(U).fail(r),
                        .Some => |left| //
                        switch (R.parse(left.tail)) {
                            .None => |r| return Result(U).fail(r),
                            .Some => |right| //
                            return Result(U).some(right.value, right.tail),
                        },
                    }
                }
            });
        }

        ///
        /// Monadic `bind` combinator `>>=`
        ///
        /// Constructs a parser that calls a function `f` to transform a parse
        /// `Result(T)` to a parse `Result(U)`.
        ///
        /// Arguments:
        ///     `U`: result value type
        ///     `f`: transform function `Self.T -> Result(U)`
        ///
        /// Returns:
        ///     `Parser{ .T = U }`
        ///
        pub fn Bind(comptime U: type, comptime f: anytype) type {
            return Self.Map(Result(U), f).Join;
        }

        ///
        /// Monadic `join` combinator
        ///
        /// Constructs a parser that unwraps a nested result type
        /// `Result(Result(U))`, to `Result(U)`.
        ///
        /// Arguments: none
        ///
        /// Conditions:
        ///     `Self{.T = Result(U)}`
        ///
        /// Returns:
        ///     `Parser{ .T = U }`
        ///
        pub const Join = Parser(struct {
            pub fn parse(input: Input) Result(U) {
                switch (Self.parse(input)) {
                    .None => |r| return Result(U).fail(r),
                    .Some => |r| return r,
                }
            }
        });
    };
}

///
/// Monadic `pure` constructor
///
/// Constructs a parser that returns a constant successful result.
///
/// Arguments:
///     `v`: parse result value
///
/// Returns:
///     `Parser{ .T = @TypeOf(v) }`
///
pub fn Pure(comptime v: anytype) type {
    const T = @TypeOf(v);

    return Parser(struct {
        pub fn parse(input: Input) Result(T) {
            return Result(T).some(v, input);
        }
    });
}

///
/// Constant failure reason constructor
///
/// Constructs a parser that always fails with the given reason.
///
/// Arguments:
///     `T`: parse result value type
///     `why`: opptional reason for failure
///
/// Returns:
///     `Parser{ .T = T }`
///
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

///
/// Singleton parser that successfully matches nothing
///
pub const Nothing = Pure({});

test "parse nothing" {
    const res = Nothing.parse(ghost);

    t.expectEqual({}, res.value().?);
    t.expectEqualSlices(u8, ghost, res.tail().?);
}

///
/// Singleton parser that only matches the end of input
///
pub const End = Parser(struct {
    pub fn parse(input: Input) Result(void) {
        if (input.len != 0) return Result(void).none();

        return Result(void).some({}, input);
    }
});

test "parse end of input" {
    t.expectEqual(Result(void).some({}, ""), End.parse(""));
    t.expect(.None == End.parse("👻"));
}

///
/// Look-ahead non-matching constructor
///
/// Constructs a parser that never consumes input, and negates the result of
/// the given parser. When it is successful, this parser returns a failed
/// result without reason, and when it fails, this parser returns a successful
/// void result.
///
/// Arguments:
///     `P`: the parser to be negated
///
/// Returns:
///     `Parser{ .T = void }`
///
pub fn Not(comptime P: type) type {
    return Parser(struct {
        pub fn parse(input: Input) Result(void) {
            switch (P.parse(input)) {
                .Some => return Result(void).none(),
                .None => return Result(void).some({}, input),
            }
        }
    });
}

test "non matching look-ahead" {
    t.expect(.None == Not(Char('👻')).parse(ghost_party));

    t.expectEqual(
        Result(void).some({}, ghost_party),
        Not(Char('🥳')).parse(ghost_party),
    );
}

///
/// Look-ahead constructor
///
/// Constructs a parser that never consumes input, and maps any successful
/// result of the given parser to void.
///
/// Arguments:
///     `P`: the parser to be tested
///
/// Returns:
///     `Parser{ .T = void }`
///
pub fn Try(comptime P: type) type {
    return Parser(struct {
        pub fn parse(input: Input) Result(void) {
            switch (P.parse(input)) {
                .None => |r| return Result(void).fail(r),
                .Some => return Result(void).some({}, input),
            }
        }
    });
}

test "matching look-ahead" {
    t.expect(.None == Try(Char('🥳')).parse(ghost_party));

    t.expectEqual(
        Result(void).some({}, ghost_party),
        Try(Char('👻')).parse(ghost_party),
    );
}

///
/// Optional parser constructor
///
/// Constructs a parser that maps the result value type of the given parser
/// to an optional, and maps any failures to a successful `null` result.
///
/// Arguments:
///     `P`: parser to be made optional
///
/// Returns:
///     `Parser { .T = ?P.T }`
///
pub fn Optional(comptime P: anytype) type {
    const T = P.T;

    return Parser(struct {
        pub fn parse(input: Input) Result(?T) {
            switch (P.parse(input)) {
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

//------------------------------------------------------------------------------
//
//  MARK: Tests for Parser combinators
//
//------------------------------------------------------------------------------

test "alternatives" {
    const P = Char('🥳').Alt(Char('👻'));

    t.expectEqualSlices(u8, ghost, P.parse(ghost_party).value().?);
    t.expectEqualSlices(u8, party, P.parse(party_ghost).value().?);
}

test "sequence left" {
    const P = Char('🥳').SeqL(Char('👻'));
    const res = P.parse(party_ghost).value().?;

    t.expectEqualSlices(u8, party, res);
    t.expect(.None == P.parse(ghost_party));
}

test "sequence right" {
    const P = Char('🥳').SeqR(Char('👻'));
    const res = P.parse(party_ghost).value().?;

    t.expectEqualSlices(u8, ghost, res);
    t.expect(.None == P.parse(ghost_party));
}

test "compile" {
    t.refAllDecls(@This());
}
