const std = @import("std");

pub fn build(b: *std.Build) void {
    const paths = b.addOptions();
    {
        const home = std.posix.getenv("HOME") orelse @panic("no home environment variable!");
        const zigup_install_dir = b.option([]const u8, "zigup-install-dir", "Directory in which zigup installs its zigs") orelse b.pathJoin(&.{ home, "/.zigup" });
        const multizig = b.option([]const u8, "multizig-dir", "The directory in which multizig stores its binaries and the zig link") orelse b.pathJoin(&.{ home, "/.multizig" });
        const zig_bin = b.option([]const u8, "zig_bin", "The path to the zig link that get passed to zigup to manage") orelse b.pathJoin(&.{ multizig, "/zig" });
        const zigup_bin = b.option([]const u8, "zigup_bin", "The path to the zigup binary") orelse b.pathJoin(&.{ multizig, "/zigup" });

        paths.addOption([]const u8, "zigup_install_dir", zigup_install_dir);
        paths.addOption([]const u8, "zig_link_path", zig_bin);
        paths.addOption([]const u8, "zigup_bin", zigup_bin);
    }
    const target = b.standardTargetOptions(.{});
    b.release_mode = .fast;
    const opt = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = opt,
        .use_llvm = if (opt == .Debug) false else null,
    });
    exe.root_module.addOptions("paths", paths);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
