const std = @import("std");
const project_3a = @import("project_3a");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const assert = std.debug.assert;
const scene = @import("scene.zig");
const scene_parser = @import("scene_parser.zig");

const zstbi = @import("zstbi");
const Image = @import("image.zig").Image;

pub const Ray = struct {
    origin: Vec3,
    dir: Vec3,

    /// point + t * dir
    pub fn eval(self: Ray, t: f64) Vec3 {
        return self.origin + @as(Vec3, @splat(t)) * self.dir;
    }
};

pub const HitRecord = struct {
    material_idx: u16,
    distance: f64,
    surface_normal: Vec3,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(alloc);

    var args = try std.process.argsWithAllocator(alloc);
    _ = args.skip();

    const file_name = args.next();
    if (file_name == null) {
        std.debug.print("Please provide a file argument", .{});
    }
    std.debug.print("{s}\n", .{file_name.?});

    const cur_dir = std.fs.cwd();
    var file = try cur_dir.openFile(file_name.?, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const scene_ = try scene_parser.parseSceneFile(alloc, &file_reader.interface);
    // std.debug.print("{f}\n", .{scene_});

    zstbi.init(alloc);
    // this crashes so i guess we'll just leak some memory
    // defer zstbi.deinit();

    var timer = try std.time.Timer.start();
    var output_img = try scene_.render(arena.allocator());

    // std.debug.print("Sizeof spherep{}\n", .{@sizeOf(SphereP)});
    // std.debug.print("Sizeof sphere{}\n", .{@sizeOf(scene.Sphere)});
    std.debug.print("Rendering took {d:.6} s\n", .{@as(f64, @floatFromInt(timer.lap())) / 1e9});

    std.debug.print("output: {s}\n", .{scene_.output_image});
    try output_img.write(scene_.output_image, alloc);
}
