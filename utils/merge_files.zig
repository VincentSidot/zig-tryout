// merge_files.zig - Merges all source files into a single file for easier distribution
const std = @import("std");

const a = std.heap.smp_allocator;

const str = []const u8;
const StringArray = std.ArrayList(str);

const DEFAULT_PATH = "output.zig.merged";

fn listDirectory(path: str, arrayList: *StringArray) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true, .access_sub_paths = false });
    defer dir.close();

    var dirIterator = dir.iterate();

    while (try dirIterator.next()) |entry| {
        if (entry.kind == .file) {
            const pathLen = path.len + 1 + entry.name.len; // +1 for "/"

            var buffer = try a.alloc(u8, pathLen);
            errdefer a.free(buffer);

            @memcpy(buffer[0..path.len], path);
            buffer[path.len] = '/';
            @memcpy(buffer[path.len + 1 ..], entry.name);

            try arrayList.append(a, buffer);
        }
    }
}

const String = std.ArrayList(u8);

fn appendFileContent(path: []const u8, output: *String) !void {
    var file = try std.fs.cwd().openFile(
        path,
        .{
            .mode = .read_only,
        },
    );
    defer file.close();

    // Append simple header
    try output.appendSlice(a, "// Begin file: ");
    try output.appendSlice(a, path);
    try output.appendSlice(a, "\n");

    // Read file content
    const fileSize = try file.getEndPos();
    var buffer = try a.alloc(u8, fileSize);
    defer a.free(buffer);

    const bytesRead = try file.readAll(buffer);
    try output.appendSlice(a, buffer[0..bytesRead]);
}

fn writeContent(path: []const u8, content: []const u8) !void {
    var isExclusive = true;
    if (std.mem.eql(u8, path, DEFAULT_PATH)) {
        isExclusive = false; // Allow overwriting default path
    }

    var file = try std.fs.cwd().createFile(
        path,
        .{
            .read = false,
            .exclusive = isExclusive,
        },
    );
    defer file.close();

    try file.writeAll(content);
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next(); // Skip program name
    const outputPath = args.next() orelse DEFAULT_PATH;

    std.debug.print("Merging source files into: {s}\n", .{outputPath});

    var fileList = StringArray.empty;

    defer {
        for (fileList.items) |file| {
            a.free(file); // Free each allocated file path
        }

        fileList.deinit(a);
    }

    try listDirectory("src", &fileList);

    var outputContent = String.empty;
    defer outputContent.deinit(a);

    for (fileList.items) |file| {
        std.debug.print("Reading file: {s}\n", .{file});
        try appendFileContent(file, &outputContent);
        try outputContent.appendSlice(a, "\n\n");
    }

    try writeContent(outputPath, outputContent.items);
}
