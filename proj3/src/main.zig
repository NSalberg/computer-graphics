const std = @import("std");
const project_3a = @import("project_3a");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const assert = std.debug.assert;

// const scene = struct {};
const Object = union {
    sphere: Sphere,
};

const Scene = struct {
    camera_pos: Vec3 = vec3.zero,
    camera_fwd: Vec3 = Vec3{ 0, 0, -1 },
    camera_up: Vec3 = Vec3{ 0, 1, 0 },
    camera_right: Vec3 = Vec3{ -1, 0, 0 },
    camera_fov_ha: i16 = 45,
    film_resolution: struct { u16, u16 } = .{ 640, 280 },
    output_image: []const u8 = "raytraced.bmp",
    spheres: std.ArrayList(Sphere),
    ambient_light: Vec3 = Vec3{ 0, 0, 0 },
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
            try writer.print("sphere: {d}, {d}, {d}, {d}\n", .{ sphere.center[0], sphere.center[1], sphere.center[2], sphere.radius });
        }
    }
};
pub const Sphere = struct {
    center: Vec3,
    radius: f64,

    pub fn init(center: Vec3.Vec3, radius: f64) Sphere {
        assert(radius > 0);
        return .{
            .center = center,
            .radius = radius,
        };
    }
};

const SceneCommands = enum {
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

fn parseVec3(vals: []const u8) !Vec3 {
    var val_it = std.mem.splitScalar(u8, vals, ' ');
    const x = try std.fmt.parseFloat(f64, val_it.first());
    const y = try std.fmt.parseFloat(f64, val_it.next().?);
    const z = try std.fmt.parseFloat(f64, val_it.next().?);
    return .{ x, y, z };
}

fn parseSceneFile(alloc: std.mem.Allocator, reader: *std.Io.Reader) !Scene {
    var scene = Scene{
        .spheres = try std.ArrayList(Sphere).initCapacity(alloc, 1),
    };

    while (reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => null,
        else => return err,
    }) |line| {
        std.debug.print("{s}", .{line});
        if (line.len <= 0 or line[0] == '#')
            continue;
        var line_it = std.mem.splitScalar(u8, line, ':');

        // std.debug.print("{s}\n", .{line_it.first()});
        const command = std.meta.stringToEnum(SceneCommands, line_it.first());

        if (command == null)
            return error.UnknownSceneCommand;

        const vals = std.mem.trim(u8, line_it.next().?, " \n");
        switch (command.?) {
            .camera_pos => scene.camera_pos = try parseVec3(vals),
            .camera_fwd => scene.camera_fwd = try parseVec3(vals),
            .camera_up => scene.camera_up = try parseVec3(vals),
            .camera_fov_ha => scene.camera_fov_ha = try std.fmt.parseInt(i16, vals, 10),
            .image_resolution => {
                var val_it = std.mem.splitScalar(u8, vals, ' ');
                const width = try std.fmt.parseInt(u16, val_it.first(), 0);
                const height = try std.fmt.parseInt(u16, val_it.next().?, 0);
                scene.film_resolution = .{ width, height };
            },
            .output_image => {
                scene.output_image = std.mem.trim(u8, vals, " ");
            },
            .sphere => {
                var val_it = std.mem.splitScalar(u8, vals, ' ');
                const x = try std.fmt.parseFloat(f64, val_it.next().?);
                const y = try std.fmt.parseFloat(f64, val_it.next().?);
                const z = try std.fmt.parseFloat(f64, val_it.next().?);
                const r = try std.fmt.parseFloat(f64, val_it.next().?);
                try scene.spheres.append(alloc, .{
                    .center = .{ x, y, z },
                    .radius = r,
                });
            },
            .background => {},
            .material => {},
            .directional_light => {},
            .point_light => {},
            .spot_light => {},
            .ambient_light => scene.ambient_light = try parseVec3(vals),
            .max_depth => {
                // const  = try std.fmt.parseInt(u16, vals.?, 10);
            },
        }
    }
    return scene;
}

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();
    var args = try std.process.argsWithAllocator(alloc);
    _ = args.skip();

    const file_name = args.next();
    if (file_name == null) {
        std.debug.print("Please provide a file argument", .{});
    }

    const cur_dir = std.fs.cwd();
    std.debug.print("{s}\n", .{file_name.?});
    var file = try cur_dir.openFile(file_name.?, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const scene = try parseSceneFile(alloc, &file_reader.interface);
    std.debug.print("\n", .{});
    std.debug.print("{f}\n", .{scene});

    try project_3a.bufferedPrint();
}
