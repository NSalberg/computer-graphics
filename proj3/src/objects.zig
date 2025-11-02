const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const std = @import("std");
const aabb = @import("aabb.zig");
const main = @import("main.zig");

const assert = std.debug.assert;

pub const Object = union(enum) {
    sphere: Sphere,
    triangle: Triangle,
    normal_triangle: NormalTriangle,

    pub fn hit(object: Object, ray: main.Ray, ray_tmin: f64, ray_tmax: f64) ?main.HitRecord {
        return switch (object) {
            inline else => |obj| obj.hit(ray, ray_tmin, ray_tmax),
        };
    }

    pub fn boundingBox(self: Object) aabb.AxisAlignedBB {
        return switch (self) {
            inline else => |obj| return obj.boundingBox(),
        };
    }

    pub fn centroid(self: Object) Vec3 {
        return switch (self) {
            .sphere => |s| return s.center,
            .triangle => |t| return t.centroid,
            .normal_triangle => |t| return t.centroid,
        };
    }

    pub fn format(self: @This(), writer: anytype) !void {
        return switch (self) {
            inline else => |l| try writer.print("{f}", .{l}),
        };
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

    pub fn boundingBox(self: Sphere) aabb.AxisAlignedBB {
        const rvec = vec3.splat(self.radius);
        return .{ .min = self.center - rvec, .max = self.center + rvec };
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

pub const NormalTriangle = struct {
    v0: Vec3,
    v1: Vec3,
    v2: Vec3,
    centroid: Vec3,
    n0: Vec3,
    n1: Vec3,
    n2: Vec3,
    material_idx: u16,

    pub fn init(v0: Vec3, v1: Vec3, v2: Vec3, n0: Vec3, n1: Vec3, n2: Vec3, material_idx: u16) NormalTriangle {
        return .{
            .v0 = v0,
            .v1 = v1,
            .v2 = v2,
            .n0 = n0,
            .n1 = n1,
            .n2 = n2,
            .centroid = (v0 + v1 + v2) * vec3.splat(@as(f64, 1.0 / 3.0)),
            .material_idx = material_idx,
        };
    }

    pub fn hit(self: NormalTriangle, ray: main.Ray, ray_tmin: f64, ray_tmax: f64) ?main.HitRecord {
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

        const w = 1 - u - v;

        var normal = vec3.unit(vec3.splat(w) * self.n0 + vec3.splat(u) * self.n1 + vec3.splat(v) * self.n2);
        if (vec3.dot(normal, ray.dir) > 0) {
            normal = -normal;
        }

        return main.HitRecord{
            .distance = t,
            .material_idx = self.material_idx,
            .surface_normal = normal,
        };
    }

    pub fn boundingBox(self: NormalTriangle) aabb.AxisAlignedBB {
        const min_v = @min(@min(self.v0, self.v1), self.v2);
        const max_v = @max(@max(self.v0, self.v1), self.v2);

        const epsilon = vec3.splat(0.0001);
        return aabb.AxisAlignedBB{
            .min = min_v - epsilon,
            .max = max_v + epsilon,
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

    pub fn boundingBox(self: Triangle) aabb.AxisAlignedBB {
        const min_v = @min(@min(self.v0, self.v1), self.v2);
        const max_v = @max(@max(self.v0, self.v1), self.v2);

        const epsilon = vec3.splat(0.0001);
        return aabb.AxisAlignedBB{
            .min = min_v - epsilon,
            .max = max_v + epsilon,
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

test "Triangle.boundingBox " {
    const tri = Triangle.init(.{ -10.0, 3.0, -5.0 }, .{ 5.0, -2.0, 8.0 }, .{ 0.0, 0.0, 0.0 }, 0);
    const bb = tri.boundingBox();

    // std.debug.print("{}{}", .{ bb.min, bb.max });
    try std.testing.expectEqual(Vec3{ -10.0, -2.0, -5.0 }, bb.min);
    try std.testing.expectEqual(Vec3{ 5.0, 3.0, 8.0 }, bb.max);
}
