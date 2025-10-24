const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const std = @import("std");
const assert = std.debug.assert;

pub const Object = union {
    sphere: Sphere,
};

pub const DirectionalLight = struct {
    color: Vec3,
    direction: Vec3,

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
    film_resolution: struct { u16, u16 } = .{ 640, 280 },

    output_image: [:0]const u8 = "raytraced.bmp",

    // Objects
    spheres: std.ArrayList(Sphere),

    background: Vec3 = Vec3{ 0, 0, 0 },

    // Lights
    ambient_light: Vec3 = Vec3{ 0, 0, 0 },
    directional_lights: std.ArrayList(DirectionalLight),
    point_lights: std.ArrayList(DirectionalLight),
    spot_lights: std.ArrayList(SpotLight),

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

        try writer.print("ambient_light: {d}, {d}, {d}\n", .{ self.ambient_light[0], self.ambient_light[1], self.ambient_light[2] });
        for (self.directional_lights.items) |light| {
            try writer.print("directional_lights: {f}\n", .{light});
        }
        for (self.point_lights.items) |light| {
            try writer.print("point_lights: {f}\n", .{light});
        }
        for (self.spot_lights.items) |light| {
            try writer.print("spot_lights: {f}\n", .{light});
        }

        try writer.print("max_depth: {}\n", .{self.max_depth});
    }
};

pub const Material = struct {
    ambient_color: Vec3 = Vec3{ 0, 0, 0 },
    diffuse_color: Vec3 = Vec3{ 1, 1, 1 },
    specular_color: Vec3 = Vec3{ 0, 0, 0 },
    nspecular: f64 = 5,
    transmissive_color: Vec3 = Vec3{ 0, 0, 0 },
    index_of_refraction: f64 = 1,

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
                self.nspecular,             self.transmissive_color[0], self.transmissive_color[1],
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
        .nspecular = try std.fmt.parseFloat(f64, val_it.next().?),
        .transmissive_color = try parseVec3It(&val_it),
        .index_of_refraction = try std.fmt.parseFloat(f64, val_it.next().?),
    };
}

pub fn parseLine(allocator: std.mem.Allocator, line: []const u8, scene: *Scene, material: *Material) !void {
    // std.debug.print("{s}", .{line});
    std.debug.print("{s}", .{line});
    if (line.len <= 0 or line[0] == '#')
        return;

    const trimmed_line = std.mem.trim(u8, line, " \n");
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
            const z = try std.fmt.parseFloat(f64, val_it.next().?);
            const r = try std.fmt.parseFloat(f64, val_it.next().?);
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
            try scene.directional_lights.append(allocator, .{ .color = color, .direction = direction });
        },
        .point_light => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const color = try parseVec3It(&val_it);
            const direction = try parseVec3It(&val_it);
            try scene.point_lights.append(allocator, .{ .color = color, .direction = direction });
        },
        .spot_light => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            try scene.spot_lights.append(allocator, .{
                .color = try parseVec3It(&val_it),
                .location = try parseVec3It(&val_it),
                .direction = try parseVec3It(&val_it),
                .angle1 = try std.fmt.parseFloat(f64, val_it.next().?),
                .angle2 = try std.fmt.parseFloat(f64, val_it.next().?),
            });
        },
        .ambient_light => scene.ambient_light = try parseVec3(vals),
        .max_depth => scene.max_depth = try std.fmt.parseInt(u16, vals, 10),
    }
}
pub fn parseSceneFile(alloc: std.mem.Allocator, reader: *std.Io.Reader) !Scene {
    var scene = Scene{
        .spheres = try std.ArrayList(Sphere).initCapacity(alloc, 1),
        .directional_lights = try std.ArrayList(DirectionalLight).initCapacity(alloc, 1),
        .point_lights = try std.ArrayList(DirectionalLight).initCapacity(alloc, 1),
        .spot_lights = try std.ArrayList(SpotLight).initCapacity(alloc, 1),
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
