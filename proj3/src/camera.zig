const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const std = @import("std");
const scene = @import("scene.zig");
const Image = @import("image.zig").Image;
const main = @import("main.zig");

pub const Camera = struct {
    pos: Vec3 = vec3.zero,
    fwd: Vec3 = Vec3{ 0, 0, -1 },
    up: Vec3 = Vec3{ 0, 1, 0 },
    right: Vec3 = Vec3{ -1, 0, 0 },
    fov_ha: f32 = 45,
    film_resolution: struct { u16, u16 } = .{ 640, 480 },
    samples_per_pixel: u32 = 1,
    max_depth: u16 = 5,

    pub fn render(self: Camera, allocator: std.mem.Allocator, s: scene.Scene) !Image {
        const img_width = self.film_resolution.@"0";
        const img_height = self.film_resolution.@"1";
        var output_img = try Image.init(allocator, img_width, img_height);

        const inv_img_width = 1.0 / @as(f32, @floatFromInt(img_width));
        const f_half_w: f32 = @floatFromInt(img_width / 2);

        const inv_img_height = 1.0 / @as(f32, @floatFromInt(img_height));
        const f_half_h: f32 = @floatFromInt(img_height / 2);

        const d: f32 = f_half_h / std.math.tan(self.fov_ha * (std.math.pi / 180.0));
        for (0..img_width) |i| {
            for (0..img_height) |j| {
                const f_i: f32 = @floatFromInt(i);
                const f_j: f32 = @floatFromInt(j);
                const u: f32 = f_half_w - @as(f32, @floatFromInt(img_width)) * (f_i + 0.5) * inv_img_width;
                const v: f32 = f_half_h - @as(f32, @floatFromInt(img_height)) * (f_j + 0.5) * inv_img_height;

                const p: Vec3 = self.pos - @as(Vec3, @splat(d)) * self.fwd + @as(Vec3, @splat(u)) * self.right + @as(Vec3, @splat(v)) * self.up;
                const ray_dir: Vec3 = vec3.unit(p - self.pos);
                const ray = main.Ray{ .point = self.pos, .dir = ray_dir };

                const color = s.shadeRay(ray, self.max_depth);

                output_img.setPixel(@intCast(i), @intCast(j), color);
            }
        }
        return output_img;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Orthogonal Camera Basis:\n", .{});
        try writer.print("fwd: {d}, {d}, {d}\n", .{ self.fwd[0], self.fwd[1], self.fwd[2] });
        try writer.print("right: {d}, {d}, {d}\n", .{ self.right[0], self.right[1], self.right[2] });
        try writer.print("up: {d}, {d}, {d}\n", .{ self.up[0], self.up[1], self.up[2] });

        try writer.print("max_depth: {}\n", .{self.max_depth});
        try writer.print("samples_per_pixel: {}\n", .{self.samples_per_pixel});
    }
};
