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

//!
//! Parser Combinator Library
//!
//! Parsers are constructed by calling `Parser()` with a struct containing a
//! function `parse([]const u8) Result(T)`. The returned parser is augmented
//! with parser combinators that allows construction of more complex parsers.
//!
//! The parser is run by passing some `input` to its `.parse()` function.
//!
//! `.Alt(Parser)`: Constructs a parser that first tries `Self` and if that
//! fails, an alternative parser is run.
//!
//! ```
//! const PartyOrGhost = Char('🥳').Alt(Char('👻'));
//! ```

pub usingnamespace @import("src/parser.zig");
pub usingnamespace @import("src/result.zig");
pub usingnamespace @import("src/string_parser.zig");
