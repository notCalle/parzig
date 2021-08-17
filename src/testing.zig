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
const t = std.testing;

usingnamespace @import("result.zig");

pub fn expectNone(
    comptime P: type,
    bytes: []const u8,
) !void {
    try t.expect(.None == P.run(bytes, null));
}

pub fn expectSome(
    comptime P: type,
    bytes: []const u8,
) !void {
    try t.expect(.Some == P.run(bytes, null));
}

pub fn expectSomeEqual(
    value: anytype,
    comptime P: type,
    bytes: []const u8,
) !void {
    try t.expectEqual(@as(P.T, value), P.run(bytes, null).value().?);
}

pub fn expectSomeExactlyEqual(
    value: anytype,
    comptime P: type,
    bytes: []const u8,
) !void {
    try t.expect(@as(P.T, value) == P.run(bytes, null).value().?);
}

pub fn expectSomeEqualSlice(
    comptime T: type,
    value: anytype,
    comptime P: type,
    bytes: []const u8,
) !void {
    try t.expectEqualSlices(T, value, P.run(bytes, null).value().?);
}

pub fn expectSomeEqualSliceOpt(
    comptime T: type,
    value: anytype,
    comptime P: type,
    bytes: []const u8,
) !void {
    try t.expectEqualSlices(T, value, (P.run(bytes, null).value().?).?);
}

pub fn expectSomeTail(
    value: anytype,
    comptime P: type,
    bytes: []const u8,
) !void {
    try t.expectEqualSlices(u8, value, (P.run(bytes, null).tail().?).peek(null));
}
