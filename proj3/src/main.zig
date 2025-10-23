const std = @import("std");
const project_3a = @import("project_3a");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const assert = std.debug.assert;
const scene = @import("scene.zig");

// const scene = struct {};

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();
    var args = try std.process.argsWithAllocator(alloc);
    _ = args.skip();

    const file_name = args.next();
    if (file_name == null) {
        std.debug.print("Please provide a file argument", .{});
    }

    const cur_dir = std.fs.cwd();
    std.debug.print("{s}\n", .{file_name.?});
    var file = try cur_dir.openFile(file_name.?, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const scene_ = try scene.parseSceneFile(alloc, &file_reader.interface);
    std.debug.print("{f}\n", .{scene_});

    try project_3a.bufferedPrint();
}
