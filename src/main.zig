const std = @import("std");
const mem = std.mem;

const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

// looks first for the zig version in env `ZIGV=`
// then looks up the tree for `.zig-version`
// lastly just uses the default from zigup
pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var arg_list = [_][:0]const u8 {""} ** 512;

    if (std.os.argv.len > 1 and mem.eql(u8, mem.span(std.os.argv[1]), "up")) {
        const bin = multizig ++ "/zigup";
        // Pass our custom directories as argments
        arg_list[0] = bin;
        arg_list[1] = "--install-dir";
        arg_list[2] = zigup_install_dir;
        arg_list[3] = "--path-link";
        arg_list[4] = zig_link_path;
        var arg_list_len: usize = 5;

        {
            var args = std.process.args();
            defer args.deinit();
            _ = args.skip();
            _ = args.skip();
            while (args.next()) |arg| : (arg_list_len+=1) {
                arg_list[arg_list_len] = arg;
            }
        }

        // Lie to `zigup` so it doesn't complain about its zig not being in the path
        var env_map = try std.process.getEnvMap(alloc);
        defer env_map.deinit();
        try env_map.put("PATH", multizig);

        return std.process.execve(alloc, arg_list[0..arg_list_len], &env_map);
    }

    const bin = try getZigVersion();
    var args = std.process.args();
    defer args.deinit();
    _ = args.skip();
    arg_list[0] = bin;
    var arg_list_len: usize = 1;
    while (args.next()) |arg| : (arg_list_len += 1) {
        arg_list[arg_list_len] = arg;
    }
    return std.process.execv(alloc, arg_list[0..arg_list_len]);
}

const home = "/home/falch";
const zigup_install_dir = home ++ "/.zigup";
const multizig = home ++ "/.multizig";
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
        const path = mem.trim(u8, contents, "\n\t \x00");

        var stream = std.io.fixedBufferStream(&zig_version_buffer);
        try std.fmt.format(stream.writer(), zigup_install_dir ++ "/{s}/files/zig\x00", .{path});

        return @ptrCast([:0]const u8, stream.getWritten());
    }
    return zig_link_path;
}

fn isRoot(dir: std.fs.Dir) !bool {
    var out_buffer: [2048]u8 = undefined;
    const path = try dir.realpath(".", &out_buffer);
    return mem.eql(u8, path, "/");
}
