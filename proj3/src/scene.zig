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
    triangel: Triangle,
};

pub const Triangle = struct {
    v0: Vec3,
    v1: Vec3,
    v2: Vec3,
    centroid: Vec3,
    material_idx: u16,

    pub fn init(v0: Vec3, v1: Vec3, v2: Vec3, material_idx: u16) Triangle {
        return .{
            .v0 = v0,
            .v1 = v1,
            .v2 = v2,
            .centroid = (v0 + v1 + v2) * vec3.splat(@as(f64, 1.0 / 3.0)),
            .material_idx = material_idx,
        };
    }

    pub fn hit(self: Triangle, ray: main.Ray, ray_tmin: f64, ray_tmax: f64) ?main.HitRecord {
        const e1 = self.v1 - self.v0;
        const e2 = self.v2 - self.v0;
        const ray_cross_e2 = vec3.cross(ray.dir, e2);
        const det = vec3.dot(e1, ray_cross_e2);
        if (det > -std.math.floatEps(f64) and det < std.math.floatEps(f64)) {
            return null;
        }
        const inv_det = 1.0 / det;
        const s = ray.origin - self.v0;
        const u = inv_det * vec3.dot(s, ray_cross_e2);

        if (u < 0.0 or u > 1.0) {
            return null;
        }

        const s_cross_e1 = vec3.cross(s, e1);
        const v = inv_det * vec3.dot(ray.dir, s_cross_e1);
        if (v < 0 or u + v > 1) {
            return null;
        }

        const t = inv_det * vec3.dot(e2, s_cross_e1);

        if (t < ray_tmin or t > ray_tmax) {
            return null;
        }

        // Account for normals not facing the camera
        var normal = vec3.unit(vec3.cross(e1, e2));
        if (vec3.dot(normal, ray.dir) > 0) {
            normal = -normal;
        }

        return main.HitRecord{
            .distance = t,
            .material_idx = self.material_idx,
            .surface_normal = normal,
        };
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("triangle: {d}, {d}, {d}, {d}\n", .{
            self.v0,
            self.v1,
            self.v2,
            self.centroid,
        });
    }
};

pub const Scene = struct {
    camera: Camera = Camera{},
    // Camera properties

    output_image: [:0]const u8 = "raytraced.bmp",

    // Objects
    spheres: std.ArrayList(Sphere),
    triangles: std.ArrayList(Triangle),

    background: Vec3 = Vec3{ 0, 0, 0 },

    lights: std.ArrayList(Light),

    materials: std.ArrayList(Material),

    vertices: std.ArrayList(Vec3),
    normals: std.ArrayList(Vec3),

    pub fn render(self: Scene, alloc: std.mem.Allocator) !Image {
        return self.camera.render(alloc, self);
    }

    pub fn shadeRay(self: *const Scene, ray: main.Ray, bounces: u16) Vec3 {
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
        }
        if (bounces > 0) {
            // Reflect
            const n = hit_obj.?.surface_normal;
            const material = self.materials.items[hit_obj.?.material_idx];

            const p = ray.eval(hit_obj.?.distance);
            if (vec3.magnitude2(material.specular_color) > 0.001) {
                const reflection = vec3.reflect(ray.dir, n);
                // bounce_point + eps * normal

                const bounce_color = material.specular_color * self.shadeRay(.{ .dir = reflection, .origin = p + n * vec3.splat(0.001) }, bounces - 1);
                color += bounce_color;
            }

            if (vec3.magnitude2(material.transmissive_color) > 0.001) {
                const entering = vec3.dot(ray.dir, n) < 0;
                const etai_over_etat = if (entering)
                    1.0 / material.index_of_refraction // air -> material
                else
                    material.index_of_refraction; // material -> air

                const normal = if (entering) n else -n;

                const refraction = vec3.refract(ray.dir, normal, etai_over_etat);
                const bounce_color = material.transmissive_color * self.shadeRay(.{ .dir = refraction, .origin = p + refraction * vec3.splat(0.001) }, bounces - 1);
                color += bounce_color;
            }
        }
        return color;
    }
    // Trace a ray through the scene from t = [0 + eps, r)
    pub fn hit(self: Scene, ray: main.Ray, eps: f64, r: f64) ?main.HitRecord {
        const eps_ray: main.Ray = .{
            .dir = ray.dir,
            .origin = ray.origin + ray.dir * vec3.splat(eps),
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

        for (self.triangles.items) |tri| {
            const hit_record = tri.hit(eps_ray, 0, r);

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

        for (self.triangles.items) |tri| {
            try writer.print("{f}\n", .{tri});
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
        const obj_c: Vec3 = (ray.origin - self.center);

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
