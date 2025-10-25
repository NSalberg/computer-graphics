const std = @import("std");
const project_3a = @import("project_3a");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const assert = std.debug.assert;
const scene = @import("scene.zig");

const zstbi = @import("zstbi");
const Image = @import("image.zig").Image;

// bool raySphereIntersect(vec3 start, vec3 dir, vec3 center, float radius){
//   float a = dot(dir,dir); //TODO - Understand: What do we know about "a" if "dir" is normalized on creation?
//   vec3 toStart = (start - center);
//   float b = 2 * dot(dir,toStart);
//   float c = dot(toStart,toStart) - radius*radius;
//   float discr = b*b - 4*a*c;
//   if (discr < 0) return false;
//   else{
//     float t0 = (-b + sqrt(discr))/(2*a);
//     float t1 = (-b - sqrt(discr))/(2*a);
//     if (t0 > 0 || t1 > 0) return true;
//   }
//   return false;
// }
pub const Ray = struct {
    point: Vec3,
    dir: Vec3,

    /// point + t * dir
    pub fn eval(self: Ray, t: f64) Vec3 {
        return self.point + @as(Vec3, @splat(t)) * self.dir;
    }
};

pub const HitRecord = struct {
    material: scene.Material,
    distance: f64,
    surface_normal: Vec3,
};
// return HitRecord{ surface, t, surface_normal}
// start + dir could becombined into a ray struct
pub fn raySphereIntersect(ray: Ray, sphere: scene.Sphere) ?HitRecord {
    const start = ray.point;
    const dir = ray.dir;

    const a = vec3.dot(dir, dir);
    const to_start: Vec3 = (start - sphere.center);
    const b = 2 * vec3.dot(dir, to_start);
    const c = vec3.dot(to_start, to_start) - sphere.radius * sphere.radius;
    const discr = b * b - 4 * a * c;
    if (discr < 0) {
        return null;
    } else {
        const t0: f64 = (-b + std.math.sqrt(discr)) / (2 * a);
        const t1: f64 = (-b - std.math.sqrt(discr)) / (2 * a);

        var t: f64 = undefined;
        if (t0 > 0 and t1 > 0) {
            t = @min(t0, t1);
        } else if (t0 > 0) {
            t = t0;
        } else if (t1 > 0) {
            t = t1;
        } else return null;

        const p = ray.eval(t);
        return HitRecord{
            .distance = t,
            .material = sphere.material,
            .surface_normal = vec3.unit(p - sphere.center),
        };
    }
}

pub fn traceScene(allocator: std.mem.Allocator, the_scene: scene.Scene) !Image {
    const s = the_scene;
    const img_width = s.film_resolution.@"0";
    const img_height = s.film_resolution.@"1";
    var output_img = try Image.init(allocator, img_width, img_height);

    const half_w = img_width / 2;
    const half_h = img_height / 2;

    const inv_img_width = 1.0 / @as(f32, @floatFromInt(img_width));
    const f_half_w: f32 = @floatFromInt(half_w);

    const inv_img_height = 1.0 / @as(f32, @floatFromInt(img_height));
    const f_half_h: f32 = @floatFromInt(half_h);

    const d: f32 = f_half_h / std.math.tan(s.camera_fov_ha * (std.math.pi / 180.0));
    for (0..img_width) |i| {
        for (0..img_height) |j| {
            const f_i: f32 = @floatFromInt(i);
            const f_j: f32 = @floatFromInt(j);
            const u: f32 = f_half_w - @as(f32, @floatFromInt(img_width)) * (f_i + 0.5) * inv_img_width;
            const v: f32 = f_half_h - @as(f32, @floatFromInt(img_height)) * (f_j + 0.5) * inv_img_height;

            const p: Vec3 = s.camera_pos - @as(Vec3, @splat(d)) * s.camera_fwd + @as(Vec3, @splat(u)) * s.camera_right + @as(Vec3, @splat(v)) * s.camera_up;
            const ray_dir: Vec3 = vec3.unit(p - s.camera_pos);
            const ray = Ray{ .point = s.camera_pos, .dir = ray_dir };

            var color: Vec3 = s.background;
            var closest_dist = std.math.inf(f64);
            var closest_hit: HitRecord = undefined;
            for (s.spheres.items) |sphere| {
                const hit_record = raySphereIntersect(ray, sphere);

                if (hit_record != null) {
                    if (hit_record.?.distance < closest_dist) {
                        closest_dist = hit_record.?.distance;
                        closest_hit = hit_record.?;
                    }
                }
            }
            // we got a hit
            if (closest_dist != std.math.inf(f64)) {
                color = vec3.zero;
                for (s.lights.items) |light| {
                    color += light.illuminate(ray, closest_hit);
                }
            }

            output_img.setPixel(@intCast(i), @intCast(j), color);
        }
    }
    return output_img;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();
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
    const scene_ = try scene.parseSceneFile(alloc, &file_reader.interface);
    std.debug.print("{f}\n", .{scene_});

    zstbi.init(alloc);
    // this crashes so i guess we'll just leak some memory
    // defer zstbi.deinit();

    var timer = try std.time.Timer.start();
    var output_img = try traceScene(alloc, scene_);
    std.debug.print("Rendering took {d:.6} s\n", .{@as(f64, @floatFromInt(timer.lap())) / 1e9});

    std.debug.print("output: {s}\n", .{scene_.output_image});
    try output_img.write(scene_.output_image, alloc);

    // auto t_start = std::chrono::high_resolution_clock::now();
    // for (int i = 0; i < img_width; i++){
    //   for (int j = 0; j < img_height; j++){
    //     //TODO - Understand: In what way does this assumes the basis is orthonormal?
    //   }
    // }
    // auto t_end = std::chrono::high_resolution_clock::now();
    // printf("Rendering took %.2f ms\n",std::chrono::duration<double, std::milli>(t_end-t_start).count());
    //
}
