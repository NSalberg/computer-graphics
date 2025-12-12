const std = @import("std");
const cimgui = @import("cimgui_zig");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("finalproject", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const logging = b.option(bool, "toolbox-logging", "toolbox logging") orelse false;
    const cimgui_dep = b.dependency("cimgui_zig", .{
        .target = target,
        .optimize = optimize,
        .platform = cimgui.Platform.SDL3,
        .renderer = cimgui.Renderer.OpenGL3,
        .@"toolbox-logging" = logging,
    });

    const cimgui_lib = cimgui_dep.artifact("cimgui");

    const exe = b.addExecutable(.{
        .name = "finalproject",
        .root_module = std.Build.Module.create(b, .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "finalproject", .module = mod },
            },
        }),
    });

    const gl_mod = cimgui_lib.root_module.import_table.get("gl").?;
    exe.root_module.addImport("gl", gl_mod);
    _ = cimgui_lib.root_module.import_table.swapRemove("gl");

    mod.addImport("gl", gl_mod);
    _ = cimgui_lib.root_module.import_table.swapRemove("gl");

    const zlm = b.dependency("zlm", .{
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("zlm", zlm.module("zlm"));

    exe.linkLibrary(cimgui_lib);
    mod.linkLibrary(cimgui_lib);
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
