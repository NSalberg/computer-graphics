const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const std = @import("std");
const bvh_tree = @import("bvh.zig");

const scene = @import("scene.zig");
const objects = @import("objects.zig");
const Scene = scene.Scene;
const Material = scene.Material;
const Sphere = scene.Sphere;
const Light = @import("lights.zig").Light;

const Image = @import("image.zig").Image;

pub const SceneCommands = enum {
    camera,
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
    // Triangle shit
    max_vertices,
    max_normals,
    vertex,
    normal,
    triangle,
    normal_triangle,
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

    const trimmed = std.mem.trim(u8, line_it.next().?, " ");
    const vals = std.mem.collapseRepeats(u8, @constCast(trimmed), ' ');
    errdefer {
        std.debug.print("Unable to parse line:  {s}\n", .{line});
    }
    switch (command.?) {
        .camera => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            s.camera.pos = try parseVec3It(&val_it);
            s.camera.fwd = try parseVec3It(&val_it);
            s.camera.up = try parseVec3It(&val_it);
            s.camera.fov_ha = try std.fmt.parseFloat(f32, val_it.next().?);
        },
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

            const sphere = objects.Sphere{
                .center = .{ x, y, z },
                .radius = r,
                .material_idx = @as(u16, @intCast(s.materials.items.len)) - 1,
            };
            try s.objects.append(allocator, objects.Object{ .sphere = sphere });
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
        .max_vertices => {
            const max_vertices = try std.fmt.parseInt(u64, vals, 10);
            try s.vertices.ensureTotalCapacity(allocator, max_vertices);
        },
        .vertex => {
            if (s.vertices.capacity == 0) {
                @branchHint(.unlikely);
                return error.VertexBeforeMaxVertices;
            }
            const vertex = try parseVec3(vals);
            s.vertices.appendAssumeCapacity(vertex);
        },
        .max_normals => {
            const max_normals = try std.fmt.parseInt(u64, vals, 10);
            try s.normals.ensureTotalCapacity(allocator, max_normals);
        },

        .normal => {
            if (s.normals.capacity == 0) {
                @branchHint(.unlikely);
                return error.NormalBeforeMaxNormals;
            }
            const normal = try parseVec3(vals);
            s.normals.appendAssumeCapacity(normal);
        },
        .triangle => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const v0_idx = try std.fmt.parseInt(usize, val_it.first(), 0);
            const v1_idx = try std.fmt.parseInt(usize, val_it.next().?, 0);
            const v2_idx = try std.fmt.parseInt(usize, val_it.next().?, 0);

            const v0 = s.vertices.items[v0_idx];
            const v1 = s.vertices.items[v1_idx];
            const v2 = s.vertices.items[v2_idx];

            const tri = objects.Triangle.init(
                v0,
                v1,
                v2,
                @as(u16, @intCast(s.materials.items.len)) - 1,
            );
            try s.objects.append(allocator, objects.Object{ .triangle = tri });
        },
        .normal_triangle => {
            var val_it = std.mem.splitScalar(u8, vals, ' ');
            const v0_idx = try std.fmt.parseInt(usize, val_it.first(), 0);
            const v1_idx = try std.fmt.parseInt(usize, val_it.next().?, 0);
            const v2_idx = try std.fmt.parseInt(usize, val_it.next().?, 0);

            const v0 = s.vertices.items[v0_idx];
            const v1 = s.vertices.items[v1_idx];
            const v2 = s.vertices.items[v2_idx];

            const n0_idx = try std.fmt.parseInt(usize, val_it.next().?, 0);
            const n1_idx = try std.fmt.parseInt(usize, val_it.next().?, 0);
            const n2_idx = try std.fmt.parseInt(usize, val_it.next().?, 0);

            const n0 = s.normals.items[n0_idx];
            const n1 = s.normals.items[n1_idx];
            const n2 = s.normals.items[n2_idx];

            const tri = objects.NormalTriangle.init(v0, v1, v2, n0, n1, n2, @as(u16, @intCast(s.materials.items.len)) - 1);
            try s.objects.append(allocator, objects.Object{ .normal_triangle = tri });
        },
        // else => {
        //     return error.CommandNotImplemented;
        // },
    }
}
pub fn parseSceneFile(alloc: std.mem.Allocator, reader: *std.Io.Reader) !Scene {
    const material_buffer = try alloc.alloc(Material, std.math.maxInt(u16));
    var s = scene.Scene{
        .objects = try std.ArrayList(objects.Object).initCapacity(alloc, 1),
        // .spheres = try std.ArrayList(objects.Sphere).initCapacity(alloc, 1),
        // .triangles = try std.ArrayList(objects.Triangle).initCapacity(alloc, 1),
        // .normaltriangles = try std.ArrayList(objects.NormalTriangle).initCapacity(alloc, 1),

        .lights = try std.ArrayList(Light).initCapacity(alloc, 1),
        .materials = std.ArrayList(Material).initBuffer(material_buffer),
        .vertices = try std.ArrayList(Vec3).initCapacity(alloc, 0),
        .normals = try std.ArrayList(Vec3).initCapacity(alloc, 0),
    };

    var material = Material{};
    s.materials.appendAssumeCapacity(material);
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
    try bvh_tree.buildBVH(&s, alloc);
    return s;
}
