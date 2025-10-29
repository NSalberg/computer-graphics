const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const std = @import("std");

const scene = @import("scene.zig");
const Scene = scene.Scene;
const Material = scene.Material;
const Sphere = scene.Sphere;
const Light = @import("lights.zig").Light;

const Image = @import("image.zig").Image;

pub const SceneCommands = enum {
    camera_pos,
    camera_fwd,
    camera_up,
    camera_fov_ha,
    film_resolution,
    samples_per_pixel,
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

pub fn parseLine(allocator: std.mem.Allocator, line: []const u8, s: *Scene, material: *Material) !void {
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
        .camera_pos => s.camera.pos = try parseVec3(vals),
        .camera_fwd => s.camera.fwd = try parseVec3(vals),
        .camera_up => s.camera.up = try parseVec3(vals),
        .camera_fov_ha => s.camera.fov_ha = try std.fmt.parseFloat(f32, vals),
        .film_resolution => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const width = try std.fmt.parseInt(u16, val_it.first(), 0);
            const height = try std.fmt.parseInt(u16, val_it.next().?, 0);
            s.camera.film_resolution = .{ width, height };
        },
        .output_image => {
            const out = std.mem.trim(u8, vals, " ");
            var out_term = try allocator.alloc(u8, out.len + 1);
            @memcpy(out_term.ptr, out);
            out_term[out_term.len - 1] = 0;
            s.output_image = out_term[0..(out_term.len - 1) :0];
        },
        .sphere => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const x = try std.fmt.parseFloat(f64, val_it.next().?);
            const y = try std.fmt.parseFloat(f64, val_it.next().?);

            const z_s = val_it.next().?;
            // std.debug.print("dddd|{s}|bbb\n", .{z_s});
            const z = try std.fmt.parseFloat(f64, z_s);

            const r_s = val_it.next().?;
            // std.debug.print("ff|{x}|gg, len = {}\n", .{ r_s, r_s.len });
            const r = try std.fmt.parseFloat(f64, r_s);

            try s.spheres.append(allocator, .{
                .center = .{ x, y, z },
                .radius = r,
                .material_idx = @as(u16, @intCast(s.materials.items.len)) - 1,
            });
        },

        .background => s.background = try parseVec3(vals),
        .material => {
            material.* = try parseMaterial(vals);
            s.materials.appendBounded(material.*) catch |err| {
                std.debug.print("Too many materials", .{});
                return err;
            };
        },
        .directional_light => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const color = try parseVec3It(&val_it);
            const direction = try parseVec3It(&val_it);
            try s.lights.append(allocator, .{
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
            try s.lights.append(allocator, .{
                .point_light = .{
                    .color = color,
                    .loc = location,
                },
            });
        },
        .spot_light => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');

            try s.lights.append(
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
            try s.lights.append(allocator, .{
                .ambient_light = .{ .intensity = try parseVec3(vals) },
            });
        },
        .max_depth => s.camera.max_depth = try std.fmt.parseInt(u16, vals, 10),
        .samples_per_pixel => s.camera.samples_per_pixel = try std.fmt.parseInt(u32, vals, 10),
    }
}
pub fn parseSceneFile(alloc: std.mem.Allocator, reader: *std.Io.Reader) !Scene {
    const material_buffer = try alloc.alloc(Material, std.math.pow(usize, 2, 16));
    var s = scene.Scene{
        .spheres = try std.ArrayList(Sphere).initCapacity(alloc, 1),
        .lights = try std.ArrayList(Light).initCapacity(alloc, 1),
        .materials = std.ArrayList(Material).initBuffer(material_buffer),
    };

    var material = Material{};
    while (reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => blk: {
            try parseLine(alloc, try reader.take(reader.end - reader.seek), &s, &material);
            break :blk null;
        },
        else => return err,
    }) |line| {
        try parseLine(alloc, line, &s, &material);
    }
    s.camera.init();
    return s;
}
