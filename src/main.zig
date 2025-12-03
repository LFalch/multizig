const std = @import("std");
const paths = @import("paths");
const mem = std.mem;
const heap = std.heap;

const is_debug = @import("builtin").mode == .Debug;

// looks first for the zig version in env `ZIGV=`
// then looks up the tree for `.zig-version`
// lastly just uses the default from zigup
pub fn main() !void {
    var dbga = if (is_debug) heap.DebugAllocator(.{}).init else {};
    defer if (is_debug) {
        _ = dbga.deinit();
    };
    const alloc = if (is_debug) dbga.allocator() else heap.smp_allocator;

    var arg_list_buf: [512][]const u8 = undefined;
    var arg_list = std.ArrayList([]const u8).initBuffer(&arg_list_buf);

    if (std.os.argv.len > 1 and mem.eql(u8, mem.span(std.os.argv[1]), "up")) {
        // Pass our custom directories as argments
        try arg_list.appendBounded(paths.zigup_bin);
        try arg_list.appendBounded("--install-dir");
        try arg_list.appendBounded(paths.zigup_install_dir);
        try arg_list.appendBounded("--path-link");
        try arg_list.appendBounded(paths.zig_link_path);

        {
            var args = std.process.args();
            defer args.deinit();
            _ = args.skip();
            _ = args.skip();
            while (args.next()) |arg| {
                try arg_list.appendBounded(arg);
            }
        }

        return std.process.execv(alloc, arg_list.items);
    }

    const bin = try getZigVersion();
    {
        var args = std.process.args();
        defer args.deinit();
        _ = args.skip();
        try arg_list.appendBounded(bin);
        while (args.next()) |arg|
            try arg_list.appendBounded(arg);
    }
    return std.process.execv(alloc, arg_list.items);
}

var zig_version_buffer: [2048]u8 = undefined;

fn getZigVersion() ![]const u8 {
    if (std.posix.getenv("ZIGV")) |zigv| {
        var stream = std.io.fixedBufferStream(&zig_version_buffer);
        try std.fmt.format(stream.writer(), paths.zigup_install_dir ++ "/{s}/files/zig\x00", .{zigv});

        return stream.getWritten();
    }

    var dir = try std.fs.cwd().openDir(".", .{});
    defer dir.close();
    while (!try isRoot(dir)) {
        var buffer: [2048]u8 = undefined;
        const contents = dir.readFile(".zig-version", &buffer) catch |e| switch (e) {
            error.FileNotFound => {
                var oldDir = dir;
                defer oldDir.close();

                dir = try oldDir.openDir("..", .{});
                continue;
            },
            else => return e,
        };
        const path = mem.trim(u8, contents, "\n\t \x00");

        var stream = std.io.fixedBufferStream(&zig_version_buffer);
        try std.fmt.format(stream.writer(), paths.zigup_install_dir ++ "/{s}/files/zig\x00", .{path});

        return stream.getWritten();
    }
    return paths.zig_link_path;
}

fn isRoot(dir: std.fs.Dir) !bool {
    var out_buffer: [2048]u8 = undefined;
    const path = try dir.realpath(".", &out_buffer);
    return mem.eql(u8, path, "/");
}
