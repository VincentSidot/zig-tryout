// main.zig - Entry point of the application

const std = @import("std");

const graph = @import("graph.zig");
const app = @import("app.zig");

pub fn main() !void {
    var processIterator = std.process.args();
    var isGraphMode: bool = false;

    while (processIterator.next()) |arg| {
        if (std.mem.eql(u8, arg, "graph")) {
            isGraphMode = true;
            break;
        }
    }

    if (isGraphMode) {
        try graph.run();
    } else {
        try app.run();
    }
}
