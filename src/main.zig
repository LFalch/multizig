const std = @import("std");
const mem = std.mem;

const Allocator = mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

// looks first for the zig version in env `ZIGV=`
// then looks up the tree for `.zig-version`
// lastly just uses the default from zigup
pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const bin = try getZigVersion();
    var args = std.process.args();
    defer args.deinit();
    var passing_args = std.ArrayList([:0]const u8).init(alloc);
    defer passing_args.deinit();
    _ = args.skip();
    try passing_args.append(bin);
    while (args.next()) |arg| {
        try passing_args.append(arg);
    }
    return std.process.execv(alloc, passing_args.items);
}

const zigup_install_dir = "/home/falch/.zigup";
const multizig = "/home/falch/.multizig";
const zig_link_path = multizig ++ "/zig";

var zig_version_buffer: [2048]u8 = undefined;

fn getZigVersion() ![:0]const u8 {
    if (std.os.getenv("ZIGV")) |zigv| {
        var stream = std.io.fixedBufferStream(&zig_version_buffer);
        try std.fmt.format(stream.writer(), zigup_install_dir ++ "/{s}/files/zig\x00", .{zigv});

        return @ptrCast([:0]const u8, stream.getWritten());
    }

    var dir = try std.fs.cwd().openDir(".", .{});
    defer dir.close();
    while (!try isRoot(dir)) {
        var buffer: [2048]u8 = undefined;
        var contents = dir.readFile(".zig-version", &buffer) catch |e| switch (e) {
            error.FileNotFound => {
                var oldDir = dir;
                defer oldDir.close();

                dir = try oldDir.openDir("..", .{});
                continue;
            },
            else => return e,
        };
        const path = std.mem.trim(u8, contents, "\n\t \x00");

        var stream = std.io.fixedBufferStream(&zig_version_buffer);
        try std.fmt.format(stream.writer(), zigup_install_dir ++ "/{s}/files/zig\x00", .{path});

        return @ptrCast([:0]const u8, stream.getWritten());
    }
    return zig_link_path;
}

fn isRoot(dir: std.fs.Dir) !bool {
    var out_buffer: [2048]u8 = undefined;
    const path = try dir.realpath(".", &out_buffer);
    return std.mem.eql(u8, path, "/");
}
