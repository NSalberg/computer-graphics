const std = @import("std");
const project_3a = @import("project_3a");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const assert = std.debug.assert;

// const scene = struct {};
const Object = union {
    sphere: Sphere,
};

const DirectionalLight = struct {
    color: Vec3,
    direction: Vec3,
};
const SpotLight = struct {
    color: Vec3,
    location: Vec3,
    direction: Vec3,
    angle1: f64,
    angle2: f64,
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
    directional_lights: std.ArrayList(DirectionalLight),
    point_lights: std.ArrayList(DirectionalLight),
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
    }
};

const Material = struct {
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

fn parseVec3It(val_it: *std.mem.SplitIterator(u8, .scalar)) !Vec3 {
    const x = try std.fmt.parseFloat(f64, val_it.next().?);
    const y = try std.fmt.parseFloat(f64, val_it.next().?);
    const z = try std.fmt.parseFloat(f64, val_it.next().?);
    return .{ x, y, z };
}

fn parseMaterial(vals: []const u8) !Material {
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

fn parseSceneFile(alloc: std.mem.Allocator, reader: *std.Io.Reader) !Scene {
    var scene = Scene{
        .spheres = try std.ArrayList(Sphere).initCapacity(alloc, 1),
    };

    var material = Material{};
    while (reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => null,
        else => return err,
    }) |line| {
        // std.debug.print("{s}", .{line});
        if (line.len <= 0 or line[0] == '#')
            continue;

        const trimmed_line = std.mem.trim(u8, line, " \n");
        if (std.mem.allEqual(u8, trimmed_line, ' ')) {
            continue;
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
                    .material = material,
                });
            },
            .background => {},
            .material => {
                material = try parseMaterial(vals);
            },
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
