// root.zig - Root module of the Zig project (unused file)

const std = @import("std");

test {
    std.testing.refAllDecls(@import("math.zig"));
}
