const vec3 = @import("vec3.zig");
const main = @import("main.zig");
const Light = @import("lights.zig").Light;
const Camera = @import("camera.zig").Camera;
const Image = @import("image.zig").Image;
const Vec3 = vec3.Vec3;
const std = @import("std");
const assert = std.debug.assert;

pub const Object = union {
    sphere: Sphere,
};

pub const Scene = struct {
    camera: Camera = Camera{},
    // Camera properties

    output_image: [:0]const u8 = "raytraced.bmp",

    // Objects
    spheres: std.ArrayList(Sphere),

    background: Vec3 = Vec3{ 0, 0, 0 },

    lights: std.ArrayList(Light),

    materials: std.ArrayList(Material),

    pub fn render(self: Scene, alloc: std.mem.Allocator) !Image {
        return self.camera.render(alloc, self);
    }

    pub fn shadeRay(self: Scene, ray: main.Ray, bounces: u16) Vec3 {
        const hit_obj: ?main.HitRecord = self.hit(ray, 0, std.math.inf(f64));
        var color: Vec3 = self.background;

        if (hit_obj == null) {
            return color;
        }

        // we got a hit
        color = vec3.zero;
        for (self.lights.items) |light| {
            color += light.illuminate(ray, hit_obj.?, self);
            // Reflect
            if (bounces > 0) {
                const n = hit_obj.?.surface_normal;
                const reflection = vec3.reflect(ray.dir, n);
                // bounce_point + eps * normal
                const p = ray.eval(hit_obj.?.distance) + n * vec3.splat(0.001);

                const material = self.materials.items[hit_obj.?.material_idx];
                color += material.specular_color * self.shadeRay(.{ .dir = reflection, .point = p }, bounces - 1);
            }
        }
        return color;
    }
    // Trace a ray through the scene from t = [0 + eps, r)
    pub fn hit(self: Scene, ray: main.Ray, eps: f64, r: f64) ?main.HitRecord {
        const eps_ray: main.Ray = .{
            .dir = ray.dir,
            .point = ray.point + ray.dir * vec3.splat(eps),
        };

        var closest_dist = r;
        var closest_hit: ?main.HitRecord = null;
        for (self.spheres.items) |sphere| {
            const hit_record = sphere.hit(eps_ray, 0, r);

            if (hit_record != null and hit_record.?.distance < closest_dist) {
                closest_dist = hit_record.?.distance;
                closest_hit = hit_record.?;
            }
        }
        return closest_hit;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{f}\n", .{self.camera});

        for (self.spheres.items) |sphere| {
            try writer.print("{f}\n", .{sphere});
        }

        try writer.print("background: {d}, {d}, {d}\n", .{ self.background[0], self.background[1], self.background[2] });

        for (self.lights.items) |l| {
            try writer.print("{f}\n", .{l});
        }
    }
};

const pi_inv: f64 = 1.0 / std.math.pi;
pub const Material = struct {
    ambient_color: Vec3 = Vec3{ 0, 0, 0 },
    diffuse_color: Vec3 = Vec3{ 1, 1, 1 },
    specular_color: Vec3 = Vec3{ 0, 0, 0 },
    specular_coefficient: f64 = 5,
    transmissive_color: Vec3 = Vec3{ 0, 0, 0 },
    index_of_refraction: f64 = 1,

    pub fn evaluate(self: Material, l: Vec3, v: Vec3, n: Vec3) Vec3 {
        const h = vec3.unit(l + v);
        const diffuse = self.diffuse_color * vec3.splat(pi_inv);
        const specular = self.specular_color * vec3.splat(std.math.pow(f64, @max(0, vec3.dot(n, h)), self.specular_coefficient));
        return diffuse + specular;
    }

    pub fn format(
        self: @This(),
        writer: anytype,
    ) !void {
        try writer.print(
            "Material(" ++
                "  ambient = ({d}, {d}, {d}),\n" ++
                "  diffuse = ({d}, {d}, {d}),\n" ++
                "  specular = ({d}, {d}, {d}),\n" ++
                "  nspecular = {d},\n" ++
                "  transmissive = ({d}, {d}, {d}),\n" ++
                "  ior = {d}\n" ++
                ")",
            .{
                self.ambient_color[0],      self.ambient_color[1],      self.ambient_color[2],
                self.diffuse_color[0],      self.diffuse_color[1],      self.diffuse_color[2],
                self.specular_color[0],     self.specular_color[1],     self.specular_color[2],
                self.specular_coefficient,  self.transmissive_color[0], self.transmissive_color[1],
                self.transmissive_color[2], self.index_of_refraction,
            },
        );
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f64,
    // This might be better to store as a pointer / index into another array
    material_idx: u16,

    pub fn init(center: Vec3.Vec3, radius: f64) Sphere {
        assert(radius > 0);
        return .{
            .center = center,
            .radius = radius,
        };
    }

    pub fn hit(self: Sphere, ray: main.Ray, ray_tmin: f64, ray_tmax: f64) ?main.HitRecord {
        const dir = ray.dir;
        const obj_c: Vec3 = (ray.point - self.center);

        const a = vec3.magnitude2(dir);
        const b = 2 * vec3.dot(dir, obj_c);
        const c = vec3.magnitude2(obj_c) - self.radius * self.radius;
        const discr = b * b - 4 * a * c;
        if (discr < 0) {
            return null;
        } else {
            const sqrtd = std.math.sqrt(discr);
            const t0: f64 = (-b + sqrtd) / (2 * a);
            const t1: f64 = (-b - sqrtd) / (2 * a);

            var t: f64 = undefined;
            if (t0 > ray_tmin and t1 > ray_tmin) {
                t = @min(t0, t1);
            } else if (t0 > ray_tmin) {
                t = t0;
            } else if (t1 > ray_tmin) {
                t = t1;
            } else return null;

            if (t > ray_tmax) {
                return null;
            }

            const p = ray.eval(t);

            return main.HitRecord{
                .distance = t,
                .material_idx = self.material_idx,
                .surface_normal = vec3.unit(p - self.center),
            };
        }
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Sphere: {d}, {d}, {d}, {d}, matidx:{d}\n", .{
            self.center[0],
            self.center[1],
            self.center[2],
            self.radius,
            self.material_idx,
        });
    }
};
