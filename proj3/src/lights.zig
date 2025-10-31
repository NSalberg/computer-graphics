const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const main = @import("main.zig");
const std = @import("std");
const Scene = @import("scene.zig").Scene;

// This might actually be slower, might be better to each have their own array lists
pub const Light = union(enum) {
    directional_light: DirectionalLight,
    ambient_light: AmbientLight,
    spot_light: SpotLight,
    point_light: PointLight,

    pub fn illuminate(light: Light, r: main.Ray, hit: main.HitRecord, scene: *const Scene) Vec3 {
        return switch (light) {
            inline else => |l| l.illuminate(r, hit, scene),
        };
    }

    pub fn format(self: @This(), writer: anytype) !void {
        return switch (self) {
            inline else => |l| try writer.print("{f}", .{l}),
        };
    }
};

pub const AmbientLight = struct {
    intensity: Vec3,
    pub fn illuminate(self: AmbientLight, ray: main.Ray, hit_record: main.HitRecord, scene: *const Scene) Vec3 {
        _ = ray;
        const material = scene.materials.items[hit_record.material_idx];
        return self.intensity * material.ambient_color;
    }

    pub fn format(self: @This(), writer: anytype) !void {
        try writer.print("AmbientLight(intensity=({d}, {d}, {d}))", .{ self.intensity[0], self.intensity[1], self.intensity[2] });
    }
};

pub const PointLight = struct {
    color: Vec3,
    loc: Vec3,

    pub fn illuminate(self: PointLight, ray: main.Ray, hit_record: main.HitRecord, scene: *const Scene) Vec3 {
        const n = hit_record.surface_normal;
        const x = ray.eval(hit_record.distance);
        const dir = self.loc - x;
        const r = vec3.norm(dir);
        const l = (dir) / vec3.splat(r);

        const srec = scene.hit(.{ .origin = x, .dir = l }, 0.002, r);

        if (srec != null) {
            @branchHint(.unlikely);
            // we hit an object on the way to the light so we in shadow
            return vec3.zero;
        } else {
            const E = vec3.splat(@max(0, vec3.dot(n, l))) * self.color * vec3.splat(1 / (r * r));

            const material = scene.materials.items[hit_record.material_idx];
            const k = material.evaluate(vec3.unit(l), vec3.unit(ray.origin - x), n);
            return E * k;
        }
    }

    pub fn format(self: @This(), writer: anytype) !void {
        try writer.print(
            "PointLight(color=({d}, {d}, {d}), dir=({d}, {d}, {d}))",
            .{
                self.color[0], self.color[1], self.color[2],
                self.loc[0],   self.loc[1],   self.loc[2],
            },
        );
    }
};

pub const DirectionalLight = struct {
    color: Vec3,
    direction: Vec3,

    pub fn illuminate(self: DirectionalLight, ray: main.Ray, hit_record: main.HitRecord, scene: *const Scene) Vec3 {
        const x = ray.eval(hit_record.distance);
        const l = vec3.unit(-self.direction);
        const n = hit_record.surface_normal;

        const srec = scene.hit(.{ .origin = x, .dir = -self.direction }, 0.002, std.math.inf(f64));
        if (srec != null) {
            // we hit an object on the way to the light so we in shadow
            return vec3.zero;
        } else {
            const E = self.color * vec3.splat(@max(0, vec3.dot(n, l)));
            const v = vec3.unit(ray.origin - x);

            const material = scene.materials.items[hit_record.material_idx];
            const k = material.evaluate(vec3.unit(l), v, n);
            return E * k;
        }
    }

    pub fn format(self: @This(), writer: anytype) !void {
        try writer.print(
            "DirectionalLight(color=({d}, {d}, {d}), dir=({d}, {d}, {d}))",
            .{
                self.color[0],     self.color[1],     self.color[2],
                self.direction[0], self.direction[1], self.direction[2],
            },
        );
    }
};

pub const SpotLight = struct {
    color: Vec3,
    location: Vec3,
    direction: Vec3,
    angle1: f64,
    angle2: f64,

    pub fn illuminate(self: SpotLight, ray: main.Ray, hit_record: main.HitRecord, scene: *const Scene) Vec3 {
        _ = self;
        _ = ray;
        _ = hit_record;
        _ = scene;
        return vec3.zero;
    }

    pub fn format(self: @This(), writer: anytype) !void {
        try writer.print(
            "SpotLight(color=({d}, {d}, {d}), loc=({d}, {d}, {d}), dir=({d}, {d}, {d}), angle1={d}, angle2={d})",
            .{
                self.color[0],     self.color[1],     self.color[2],
                self.location[0],  self.location[1],  self.location[2],
                self.direction[0], self.direction[1], self.direction[2],
                self.angle1,       self.angle2,
            },
        );
    }
};
