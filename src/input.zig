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

const Input = @This();

pub const Position = struct {
    index: usize = 0,
    label: ?[]const u8 = null,
    line: usize = 1,
    col: usize = 1,

    pub fn format(
        self: Position,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        _ = writer;
        std.fmt.format("{}:{}:{}", .{
            self.label orelse "(null)",
            self.line,
            self.col,
        });
    }
};

buffer: []const u8,
pos: Position = Position{},

pub fn init(bytes: []const u8, name: ?[]const u8) Input {
    return .{ .buffer = bytes, .pos = .{ .label = name } };
}

///
/// Returns the slice between two inputs
///
/// Arguments:
///     `self: Self` - lagging input
///     `tail: Self` - leading input
///
/// Returns:
///     `[self.index..tail.index]const u8`
///
pub fn diff(self: Input, tail: Input) []const u8 {
    return self.buffer[self.pos.index..tail.pos.index];
}

///
/// Returns the length of the remaining input
///
/// Arguments:
///     `self: Self`
///
/// Returns:
///     `usize`
///
pub fn len(self: Input) usize {
    return self.buffer.len - self.pos.index;
}

///
/// Returns a slice with the remaining input
///
/// Arguments:
///     `self: Self`
///     `length: ?usize` - optional max length
///
/// Returns:
///     `[index..]const u8`
///
pub fn peek(self: Input, length: ?usize) []const u8 {
    const here = self.pos.index;
    const end = self.buffer.len;
    const there = if (length) |l| std.math.min(end, here + l) else end;

    return self.buffer[here..there];
}

test "peek at the tail" {
    const input = Input.init("hello", null);

    try t.expectEqualSlices(u8, "hello", input.peek(null));
}

///
/// Returns an input with the index moved forward
///
/// Arguments:
///     `self: Self`    - input
///     `length: usize` - length of the slice that was taken
///
pub fn take(self: Input, length: usize) Input {
    const here = self.pos.index;
    const next = std.math.min(self.buffer.len, here + length);
    var new = self;

    var i = here;
    while (i < next) : (i += 1) {
        // TODO:
        // Do we need anything else than LF and CR+LF line ends?
        //
        switch (self.buffer[i]) {
            '\n' => {
                new.pos.line += 1;
                new.pos.col = 1;
            },
            '\r' => {},
            else => new.pos.col += 1,
        }
    }
    new.pos.index = i;
    return new;
}

test "take nothing" {
    const input0 = Input.init("hello, world\n", null);
    const input1 = input0.take(0);

    try t.expectEqualSlices(u8, input0.peek(null), input1.peek(null));
}

test "take everything" {
    const input0 = Input.init("hello, world\n", null);
    const input1 = input0.take(std.math.maxInt(usize));

    try t.expectEqualSlices(u8, "", input1.peek(null));
}
