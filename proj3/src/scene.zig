const vec3 = @import("vec3.zig");
const main = @import("main.zig");
const Vec3 = vec3.Vec3;
const std = @import("std");
const assert = std.debug.assert;

pub const Object = union {
    sphere: Sphere,
};

// This might actually be slower, might be better to each have their own array lists
pub const Light = union(enum) {
    directional_light: DirectionalLight,
    ambient_light: AmbientLight,
    spot_light: SpotLight,
    point_light: PointLight,

    pub fn illuminate(light: Light, r: main.Ray, hit: main.HitRecord) Vec3 {
        return switch (light) {
            inline else => |l| l.illuminate(r, hit),
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
    pub fn illuminate(self: AmbientLight, ray: main.Ray, hit_record: main.HitRecord) Vec3 {
        _ = ray;
        return self.intensity * hit_record.material.ambient_color;
    }

    pub fn format(self: @This(), writer: anytype) !void {
        try writer.print("AmbientLight(intensity=({d}, {d}, {d}))", .{ self.intensity[0], self.intensity[1], self.intensity[2] });
    }
};

pub const PointLight = struct {
    color: Vec3,
    loc: Vec3,

    pub fn illuminate(self: PointLight, ray: main.Ray, hit_record: main.HitRecord) Vec3 {
        const x = ray.eval(hit_record.distance);
        // const to_light = self.loc - x;
        // const dist_squared = vec3.dot(to_light, to_light);

        const r = vec3.norm(self.loc - x);
        const l = (self.loc - x) / vec3.splat(r);
        const n = hit_record.surface_normal;

        const E = vec3.splat(@max(0, vec3.dot(n, l))) * self.color / vec3.splat(r * r);
        const k = hit_record.material.evaluate(vec3.unit(l), vec3.unit(ray.point - x), n);
        // std.debug.print("E: {d}, k: {d}\n", .{ E[0], k[0] });
        return E * k;
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

    pub fn illuminate(self: DirectionalLight, ray: main.Ray, hit_record: main.HitRecord) Vec3 {
        _ = self;
        _ = ray;
        _ = hit_record;
        return vec3.zero;
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

    pub fn illuminate(self: SpotLight, ray: main.Ray, hit_record: main.HitRecord) Vec3 {
        _ = self;
        _ = ray;
        _ = hit_record;
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

pub const Scene = struct {
    // Camera properties
    camera_pos: Vec3 = vec3.zero,
    camera_fwd: Vec3 = Vec3{ 0, 0, -1 },
    camera_up: Vec3 = Vec3{ 0, 1, 0 },
    camera_right: Vec3 = Vec3{ -1, 0, 0 },
    camera_fov_ha: f32 = 45,
    film_resolution: struct { u16, u16 } = .{ 640, 480 },

    output_image: [:0]const u8 = "raytraced.bmp",

    // Objects
    spheres: std.ArrayList(Sphere),

    background: Vec3 = Vec3{ 0, 0, 0 },

    lights: std.ArrayList(Light),

    max_depth: u16 = 5,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Orthogonal Camera Basis:\n", .{});
        try writer.print("fwd: {d}, {d}, {d}\n", .{ self.camera_fwd[0], self.camera_fwd[1], self.camera_fwd[2] });
        try writer.print("right: {d}, {d}, {d}\n", .{ self.camera_right[0], self.camera_right[1], self.camera_right[2] });
        try writer.print("up: {d}, {d}, {d}\n", .{ self.camera_up[0], self.camera_up[1], self.camera_up[2] });

        for (self.spheres.items) |sphere| {
            try writer.print("{f}\n", .{sphere});
        }

        try writer.print("background: {d}, {d}, {d}\n", .{ self.background[0], self.background[1], self.background[2] });

        for (self.lights.items) |l| {
            try writer.print("{f}\n", .{l});
        }

        try writer.print("max_depth: {}\n", .{self.max_depth});
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
    material: Material,

    pub fn init(center: Vec3.Vec3, radius: f64) Sphere {
        assert(radius > 0);
        return .{
            .center = center,
            .radius = radius,
        };
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Sphere: {d}, {d}, {d}, {d}, \n {f}\n", .{
            self.center[0],
            self.center[1],
            self.center[2],
            self.radius,
            self.material,
        });
    }
};

pub const SceneCommands = enum {
    camera_pos,
    camera_fwd,
    camera_up,
    camera_fov_ha,
    image_resolution,
    output_image,
    sphere,
    background,
    material,
    directional_light,
    point_light,
    spot_light,
    ambient_light,
    max_depth,
};

pub fn parseVec3(vals: []const u8) !Vec3 {
    var val_it = std.mem.splitScalar(u8, vals, ' ');
    const x = try std.fmt.parseFloat(f64, val_it.first());
    const y = try std.fmt.parseFloat(f64, val_it.next().?);
    const z = try std.fmt.parseFloat(f64, val_it.next().?);
    return .{ x, y, z };
}

pub fn parseVec3It(val_it: *std.mem.SplitIterator(u8, .scalar)) !Vec3 {
    const x = try std.fmt.parseFloat(f64, val_it.next().?);
    const y = try std.fmt.parseFloat(f64, val_it.next().?);
    const z = try std.fmt.parseFloat(f64, val_it.next().?);
    return .{ x, y, z };
}

pub fn parseMaterial(vals: []const u8) !Material {
    var val_it = std.mem.splitScalar(u8, vals, ' ');
    return Material{
        .ambient_color = try parseVec3It(&val_it),
        .diffuse_color = try parseVec3It(&val_it),
        .specular_color = try parseVec3It(&val_it),
        .specular_coefficient = try std.fmt.parseFloat(f64, val_it.next().?),
        .transmissive_color = try parseVec3It(&val_it),
        .index_of_refraction = blk: {
            const ior_s = val_it.next().?;
            std.debug.print("ior|{x}|gg, len = {}\n", .{ ior_s, ior_s.len });
            const ior = try std.fmt.parseFloat(f64, ior_s);
            break :blk ior;
        },
    };
}

pub fn parseLine(allocator: std.mem.Allocator, line: []const u8, scene: *Scene, material: *Material) !void {
    // std.debug.print("{s}", .{line});
    std.debug.print("{s}", .{line});
    if (line.len <= 0 or line[0] == '#')
        return;

    const trimmed_line = std.mem.trim(u8, line, &std.ascii.whitespace);
    if (std.mem.allEqual(u8, trimmed_line, ' ')) {
        return;
    }

    var line_it = std.mem.splitScalar(u8, trimmed_line, ':');

    const l1 = line_it.first();
    const command = std.meta.stringToEnum(SceneCommands, l1);
    if (command == null) {
        std.debug.print("Unkown scene command : {s} \n", .{l1});
        return error.UnknownSceneCommand;
    }

    const vals = std.mem.trim(u8, line_it.next().?, " ");
    errdefer {
        std.debug.print("Unable to parse line:  {s}\n", .{line});
    }
    switch (command.?) {
        .camera_pos => scene.camera_pos = try parseVec3(vals),
        .camera_fwd => scene.camera_fwd = try parseVec3(vals),
        .camera_up => scene.camera_up = try parseVec3(vals),
        .camera_fov_ha => scene.camera_fov_ha = try std.fmt.parseFloat(f32, vals),
        .image_resolution => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const width = try std.fmt.parseInt(u16, val_it.first(), 0);
            const height = try std.fmt.parseInt(u16, val_it.next().?, 0);
            scene.film_resolution = .{ width, height };
        },
        .output_image => {
            const out = std.mem.trim(u8, vals, " ");
            var out_term = try allocator.alloc(u8, out.len + 1);
            @memcpy(out_term.ptr, out);
            out_term[out_term.len - 1] = 0;
            scene.output_image = out_term[0..(out_term.len - 1) :0];
        },
        .sphere => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const x = try std.fmt.parseFloat(f64, val_it.next().?);
            const y = try std.fmt.parseFloat(f64, val_it.next().?);

            const z_s = val_it.next().?;
            std.debug.print("dddd|{s}|bbb\n", .{z_s});
            const z = try std.fmt.parseFloat(f64, z_s);

            const r_s = val_it.next().?;
            std.debug.print("ff|{x}|gg, len = {}\n", .{ r_s, r_s.len });
            const r = try std.fmt.parseFloat(f64, r_s);

            try scene.spheres.append(allocator, .{
                .center = .{ x, y, z },
                .radius = r,
                .material = material.*,
            });
        },

        .background => scene.background = try parseVec3(vals),
        .material => material.* = try parseMaterial(vals),
        .directional_light => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const color = try parseVec3It(&val_it);
            const direction = try parseVec3It(&val_it);
            try scene.lights.append(allocator, .{
                .directional_light = .{
                    .color = color,
                    .direction = direction,
                },
            });
        },
        .point_light => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const color = try parseVec3It(&val_it);
            const location = try parseVec3It(&val_it);
            try scene.lights.append(allocator, .{
                .point_light = .{
                    .color = color,
                    .loc = location,
                },
            });
        },
        .spot_light => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');

            try scene.lights.append(
                allocator,
                .{ .spot_light = .{
                    .color = try parseVec3It(&val_it),
                    .location = try parseVec3It(&val_it),
                    .direction = try parseVec3It(&val_it),
                    .angle1 = try std.fmt.parseFloat(f64, val_it.next().?),
                    .angle2 = try std.fmt.parseFloat(f64, val_it.next().?),
                } },
            );
        },
        .ambient_light => {
            try scene.lights.append(allocator, .{
                .ambient_light = .{ .intensity = try parseVec3(vals) },
            });
        },
        .max_depth => scene.max_depth = try std.fmt.parseInt(u16, vals, 10),
    }
}
pub fn parseSceneFile(alloc: std.mem.Allocator, reader: *std.Io.Reader) !Scene {
    var scene = Scene{
        .spheres = try std.ArrayList(Sphere).initCapacity(alloc, 1),
        .lights = try std.ArrayList(Light).initCapacity(alloc, 1),
    };

    var material = Material{};
    while (reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => blk: {
            try parseLine(alloc, try reader.take(reader.end - reader.seek), &scene, &material);
            break :blk null;
        },
        else => return err,
    }) |line| {
        try parseLine(alloc, line, &scene, &material);
    }
    scene.camera_right = vec3.unit(vec3.cross(scene.camera_up, scene.camera_fwd));
    return scene;
}
