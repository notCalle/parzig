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
const t = @import("testing.zig");

const Input = @import("input.zig");

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
        /// Value type of parse results
        pub const T = ParseResult(P).T;

        pub usingnamespace P;

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
        pub fn Map(comptime f: anytype) type {
            const U = ReturnType(@TypeOf(f));

            return Parser(struct {
                pub fn parse(input: Input) Result(U) {
                    switch (P.parse(input)) {
                        .Some => |r| return Result(U).some(f(r.value), r.tail),
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
                    const r = P.parse(input);
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
                    switch (P.parse(input)) {
                        .None => |r| return Result(T).fail(r),
                        .Some => |left| //
                        switch (R.parse(left.tail)) {
                            .None => |r| return Result(T).fail(r),
                            .Some => //
                            return Result(T){ .Some = left },
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
                    switch (P.parse(input)) {
                        .None => |r| return Result(U).fail(r),
                        .Some => |left| //
                        switch (R.parse(left.tail)) {
                            .None => |r| return Result(U).fail(r),
                            .Some => |right| //
                            return Result(U){ .Some = right },
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
        pub fn Bind(comptime f: anytype) type {
            return P.Map(f).Join;
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
            const U = ResultType(T);

            pub fn parse(input: Input) Result(U) {
                switch (P.parse(input)) {
                    .None => |r| return Result(U).fail(r),
                    .Some => |r| return r,
                }
            }
        });

        ///
        /// Parser runner
        ///
        /// Arguments:
        ///     `bytes: []const u8` - input buffer to parse
        ///     `label: ?[]const u8` - optional label (e.g. file name)
        ///
        /// Returns:
        ///     `Result(Self.T)`
        ///
        pub fn run(
            bytes: []const u8,
            label: ?[]const u8,
        ) Result(T) {
            return P.parse(Input.init(bytes, label));
        }
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
            _ = input;
            return Result(T).fail(why);
        }
    });
}

test "parse failure" {
    try t.expectNone(Fail(void, null), "");
}

///
/// Singleton parser that successfully matches nothing
///
pub const Nothing = Pure({});

test "parse nothing" {
    try t.expectSomeExactlyEqual({}, Nothing, ghost);
    try t.expectSomeTail(ghost, Nothing, ghost);
}

///
/// Singleton parser that only matches the end of input
///
pub const End = Parser(struct {
    pub fn parse(input: Input) Result(void) {
        if (input.len() != 0) return Result(void).none();

        return Result(void).some({}, input);
    }
});

test "parse end of input" {
    try t.expectSomeEqual({}, End, "");
    try t.expectNone(End, "👻");
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
    try t.expectNone(Not(Char('👻')), ghost_party);

    try t.expectSomeEqual({}, Not(Char('🥳')), ghost_party);
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
    try t.expectNone(Try(Char('🥳')), ghost_party);

    try t.expectSomeEqual({}, Try(Char('👻')), ghost_party);
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
    try t.expectSomeEqualSliceOpt(u8, ghost, Optional(Char('👻')), ghost_party);
    try t.expectSomeEqual(null, Optional(Char('👻')), party_ghost);
}

//------------------------------------------------------------------------------
//
//  MARK: Tests for Parser combinators
//
//------------------------------------------------------------------------------

test "alternatives" {
    try t.expectSomeEqualSlice(u8, ghost, Char('🥳').Alt(Char('👻')), ghost_party);
    try t.expectSomeEqualSlice(u8, party, Char('🥳').Alt(Char('👻')), party_ghost);
}

test "sequence left" {
    try t.expectSomeEqualSlice(u8, party, Char('🥳').SeqL(Char('👻')), party_ghost);
    try t.expectNone(Char('🥳').SeqL(Char('👻')), ghost_party);
}

test "sequence right" {
    try t.expectSomeEqualSlice(u8, ghost, Char('🥳').SeqR(Char('👻')), party_ghost);
    try t.expectNone(Char('🥳').SeqR(Char('👻')), ghost_party);
}

test "compile" {
    std.testing.refAllDecls(@This());
}
