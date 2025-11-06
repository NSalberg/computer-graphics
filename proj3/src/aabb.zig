const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const main = @import("main.zig");
const std = @import("std");
const expect = std.testing.expect;

pub const Interval = struct {
    min: f64,
    max: f64,

    pub fn expand(self: Interval, delta: f64) Interval {
        const padding = delta / 2;
        return .{
            .min = self.min - padding,
            .max = self.max + padding,
        };
    }
};

pub const AxisAlignedBB = struct {
    min: Vec3,
    max: Vec3,

    pub fn x(self: AxisAlignedBB) Interval {
        return .{ .min = self.min[0], .max = self.max[0] };
    }

    pub fn y(self: AxisAlignedBB) Interval {
        return .{ .min = self.min[1], .max = self.max[1] };
    }

    pub fn z(self: AxisAlignedBB) Interval {
        return .{ .min = self.min[2], .max = self.max[2] };
    }

    pub fn fromVec3s(a: Vec3, b: Vec3) AxisAlignedBB {
        return .{
            .min = @min(a, b),
            .max = @max(a, b),
        };
    }

    pub fn fromAABBs(a: AxisAlignedBB, b: AxisAlignedBB) AxisAlignedBB {
        return .{
            .min = @min(a.min, b.min),
            .max = @max(a.max, b.max),
        };
    }

    pub fn hit(self: AxisAlignedBB, ray: main.Ray, ray_tmin: f64, ray_tmax: f64) bool {
        const origin = ray.origin;
        const dinv = vec3.splat(1) / ray.dir;
        const t0 = (self.min - origin) * dinv;
        const t1 = (self.max - origin) * dinv;

        var tmin = ray_tmin;
        var tmax = ray_tmax;

        for (0..3) |i| {
            const t_near = @min(t0[i], t1[i]);
            const t_far = @max(t0[i], t1[i]);

            tmin = @max(tmin, t_near);
            tmax = @min(tmax, t_far);

            if (tmin > tmax) {
                return false;
            }
        }

        return true;
    }
};

test "AABB fromVec3s" {
    const a = Vec3{ -1, 1, 0 };
    const b = Vec3{ 1, -1, 1 };
    const aabb = AxisAlignedBB.fromVec3s(a, b);
    try expect(aabb.min[0] == -1);
    try expect(aabb.max[0] == 1);
    try expect(aabb.min[1] == -1);
    try expect(aabb.max[1] == 1);
    try expect(aabb.min[2] == 0);
    try expect(aabb.max[2] == 1);
}
