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
    camera_fov_ha: i16 = 45,
    film_resolution: struct { u16, u16 } = .{ 640, 280 },
    output_image: []const u8 = "raytraced.bmp",
    spheres: ?std.ArrayList(Sphere) = null,
    ambient_light: Vec3 = Vec3{ 0, 0, 0 },
    max_depth: u16 = 5,
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
    film_resolution,
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

fn parseSceneFile(reader: *std.Io.Reader) !Scene {
    var scene = Scene{};
    while (reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => null,
        else => return err,
    }) |line| {
        var line_it = std.mem.splitScalar(u8, line, ':');
        const command = std.meta.stringToEnum(SceneCommands, line_it.first());

        if (command == null) {
            return error.UnknownSceneCommand;
        }

        const vals = line_it.next();
        switch (command.?) {
            .camera_pos => scene.camera_pos = try parseVec3(vals.?),
            .camera_fwd => scene.camera_fwd = try parseVec3(vals.?),
            .camera_up => scene.camera_up = try parseVec3(vals.?),
            .camera_fov_ha => scene.camera_fov_ha = try std.fmt.parseInt(i16, vals.?, 10),
            .film_resolution => {
                var val_it = std.mem.splitScalar(u8, vals.?, ' ');
                const width = try std.fmt.parseInt(u16, val_it.first(), 10);
                const height = try std.fmt.parseInt(u16, val_it.next().?, 10);
                scene.film_resolution = .{ width, height };
            },
            .output_image => {
                scene.output_image = std.mem.trim(u8, vals.?, " ");
            },
            .sphere => {},
            .background => {},
            .material => {},
            .directional_light => {},
            .point_light => {},
            .spot_light => {},
            .ambient_light => scene.ambient_light = try parseVec3(vals.?),
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

    const cur_dir = try std.fs.selfExeDirPathAlloc(alloc);
    var dir = try std.fs.openDirAbsolute(cur_dir, .{});
    defer dir.close();
    var file = try std.fs.Dir.openFile(dir, file_name.?, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    _ = try parseSceneFile(&file_reader.interface);

    try project_3a.bufferedPrint();
}
