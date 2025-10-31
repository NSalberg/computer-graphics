const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const std = @import("std");
const scene = @import("scene.zig");
const Image = @import("image.zig").Image;
const main = @import("main.zig");

const Progress = std.Progress;

var prng = std.Random.Xoshiro256.init(42);
const rand = prng.random();

pub const Camera = struct {
    pos: Vec3 = vec3.zero,
    fwd: Vec3 = Vec3{ 0, 0, -1 },
    up: Vec3 = Vec3{ 0, 1, 0 },
    right: Vec3 = Vec3{ -1, 0, 0 },
    fov_ha: f32 = 45,
    film_resolution: struct { u16, u16 } = .{ 640, 480 },
    samples_per_pixel: u32 = 25,
    max_depth: u16 = 5,

    inv_img_width: ?f32 = null,
    inv_img_height: ?f32 = null,
    f_half_w: ?f32 = null,
    f_half_h: ?f32 = null,
    d: ?f64 = null,

    pub fn init(self: *Camera) void {
        const img_width = self.film_resolution.@"0";
        const img_height = self.film_resolution.@"1";
        self.inv_img_width = 1.0 / @as(f32, @floatFromInt(img_width));
        self.inv_img_height = 1.0 / @as(f32, @floatFromInt(img_height));

        self.f_half_w = @floatFromInt(img_width / 2);
        self.f_half_h = @floatFromInt(img_height / 2);

        self.right = vec3.unit(vec3.cross(self.up, self.fwd));

        self.d = self.f_half_h.? / std.math.tan(self.fov_ha * (std.math.pi / 180.0));
    }

    pub fn getRay(self: Camera, i: u16, j: u16) main.Ray {
        const img_width = self.film_resolution.@"0";
        const img_height = self.film_resolution.@"1";

        const u_rand: f32 = rand.float(f32);
        const v_rand: f32 = rand.float(f32);
        const f_i: f32 = @floatFromInt(i);
        const f_j: f32 = @floatFromInt(j);

        const u: f32 = self.f_half_w.? - @as(f32, @floatFromInt(img_width)) * (f_i + u_rand) * self.inv_img_width.?;
        const v: f32 = self.f_half_h.? - @as(f32, @floatFromInt(img_height)) * (f_j + v_rand) * self.inv_img_height.?;

        const p: Vec3 = self.pos - @as(Vec3, @splat(self.d.?)) * self.fwd + @as(Vec3, @splat(u)) * self.right + @as(Vec3, @splat(v)) * self.up;
        const ray_dir: Vec3 = vec3.unit(p - self.pos);
        return main.Ray{ .origin = self.pos, .dir = ray_dir };
    }

    pub fn render(self: Camera, allocator: std.mem.Allocator, s: scene.Scene) !Image {
        const img_width = self.film_resolution.@"0";
        const img_height = self.film_resolution.@"1";
        var output_img = try Image.init(allocator, img_width, img_height);
        const samples_per_pix_inv: f64 = 1.0 / @as(f64, @floatFromInt(self.samples_per_pixel));

        // const root = Progress.start(.{ .refresh_rate_ns = 200 * std.time.ns_per_ms, .root_name = "Rendering Scene", .estimated_total_items = img_width });
        // const line = root.start("Rendering Line", img_width);
        for (0..img_width) |i| {
            // if (i % 10 == 0) line.setCompletedItems(i);
            for (0..img_height) |j| {
                var color = vec3.zero;
                for (0..self.samples_per_pixel) |_| {
                    const ray = self.getRay(@intCast(i), @intCast(j));
                    color += s.shadeRay(ray, self.max_depth);
                }
                color = color * vec3.splat(samples_per_pix_inv);

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
