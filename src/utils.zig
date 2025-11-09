// utils.zig - Utility functions and helpers

const std = @import("std");

pub const Utils = struct {
    pub const print = std.debug.print;

    pub inline fn println(comptime fmt: []const u8, args: anytype) void {
        print(fmt ++ "\n", args);
    }
};
