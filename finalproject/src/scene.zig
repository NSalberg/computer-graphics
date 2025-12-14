const std = @import("std");
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;
const Vertex = @import("render.zig").Vertex;

pub const ObjectType = enum {
    cube,
    sphere,
    mesh,
};

pub const Object = struct {
    name: []const u8,
    transform: zlm.Mat4,
    typ: ObjectType,
    mesh_idx: usize = 0,
    materail_idx: usize = 0,
};

const LightType = enum(u8) {
    directional,
    ambient,
    point,
};

pub const LightData = union(enum) {
    directional: DirectionalLight,
    ambient: AmbientLight,
    point: PointLight,
};

pub const Light = struct {
    name: []const u8,
    data: LightData,
};

pub const AmbientLight = struct {
    intensity: Vec3,
};

pub const PointLight = struct {
    color: Vec3,
    loc: Vec3,
};

pub const DirectionalLight = struct {
    color: Vec3,
    direction: Vec3,
};

const Camera = struct {
    center: Vec3,
    target: Vec3,

    pub fn orbit(self: *Camera, dx: f32, dy: f32) void {
        // std.debug.print("dx, dy: {} {}\n", .{ dx, dy });
        const sensitivity = 0.005;

        const cur_offset = self.center.sub(self.target);
        const radius = cur_offset.length();
        var theta = std.math.atan2(cur_offset.x, cur_offset.z);
        var phi = std.math.acos(cur_offset.y / radius);
        theta -= dx * sensitivity;
        phi -= dy * sensitivity;

        const epsilon = 0.01;
        phi = std.math.clamp(phi, epsilon, std.math.pi - epsilon);

        const sin_phi = @sin(phi);
        const new_offset = Vec3{
            .x = radius * sin_phi * @sin(theta),
            .y = radius * @cos(phi),
            .z = radius * sin_phi * @cos(theta),
        };

        self.center = self.target.add(new_offset);
    }

    pub fn translate(self: *Camera, dx: f32, dy: f32) void {
        const sensitivity = 0.005;
        const speed = 1 * sensitivity;
        const world_up = Vec3{ .x = 0, .y = 1, .z = 0 };
        const forward = self.target.sub(self.center).normalize();

        const right = forward.cross(world_up).normalize();
        const cam_up = right.cross(forward).normalize();

        const move_right = right.scale(-dx * speed);
        const move_up = cam_up.scale(dy * speed);

        const total_move = move_right.add(move_up);

        self.center = self.center.add(total_move);
        self.target = self.target.add(total_move);
    }

    pub fn zoom(self: *Camera, scroll_y: f32) void {
        const offset = self.center.sub(self.target);
        var dist = offset.length();
        const zoom_speed: f32 = 0.1;
        if (scroll_y > 0) {
            dist *= (1.0 - zoom_speed);
        } else if (scroll_y < 0) {
            dist *= (1.0 + zoom_speed);
        }
        if (dist < 0.1) dist = 0.1;

        self.center = self.target.add(offset.normalize().scale(dist));
    }
};

pub const CpuMesh = struct {
    vertices: []const Vertex,
    name: []const u8,
};

pub const Material = struct {
    ambient_color: Vec3 = Vec3.new(0, 0, 0),
    diffuse_color: Vec3 = Vec3.new(1, 1, 1),
    specular_color: Vec3 = Vec3.new(0, 0, 0),
    specular_coefficient: f32 = 5,
    transmissive_color: Vec3 = Vec3.new(0, 0, 0),
    index_of_refraction: f32 = 1,
};

/// Describes the 3d world, contains objects, camera, lights, etc.
pub const Scene = struct {
    camera: Camera = Camera{
        .center = Vec3.one,
        .target = Vec3.zero,
    },
    meshes: std.ArrayList(CpuMesh) = .empty,
    materials: std.MultiArrayList(Material) = .empty,

    objects: std.MultiArrayList(Object) = .empty,
    lights: std.ArrayList(Light) = .empty,
    pub fn dupeObject(
        self: *Scene,
        allocator: std.mem.Allocator,
        obj_idx: usize,
        transform: zlm.Vec4,
    ) !usize {
        var d = self.objects.get(obj_idx);
        d.transform = transform;
        try self.objects.append(allocator, d);
    }

    /// add a Material to the material ArrayList, returns its index
    pub fn addMaterial(self: *Scene, allocator: std.mem.Allocator, mat: Material) !usize {
        try self.materials.append(allocator, mat);
        return self.materials.len - 1;
    }

    pub fn addLight(self: *Scene, allocator: std.mem.Allocator, light: Light) !usize {
        try self.lights.append(allocator, light);
        return self.lights.items.len - 1;
    }

    /// add a Mesh to the mesh ArrayList, returns its index
    pub fn addMesh(self: *Scene, allocator: std.mem.Allocator, mesh: CpuMesh) !usize {
        try self.meshes.append(allocator, mesh);
        return self.meshes.items.len - 1;
    }

    pub fn addObject(self: *Scene, allocator: std.mem.Allocator, obj: Object) !usize {
        try self.objects.append(allocator, obj);
        return self.objects.len - 1;
    }
};

pub fn exportSceneToText(scne: *const Scene, file_path: []const u8) !void {
    const cwd = std.fs.cwd();
    const file = try cwd.createFile(file_path, .{});
    defer file.close();

    var buf = std.mem.zeroes([4096]u8);
    var writer = file.writer(&buf);

    // -------------------------------------------------------------------------
    // 1. Header & Camera
    // -------------------------------------------------------------------------
    try writer.interface.print("# Exported Scene\n", .{});
    try writer.interface.print("output_image: \"output.png\"\n", .{});
    try writer.interface.print("film_resolution: 800 600\n", .{});

    // Camera Pos
    const cam = scne.camera;
    try writer.interface.print("camera_pos: {d:.4} {d:.4} {d:.4}\n", .{ cam.center.x, cam.center.y, cam.center.z });

    // Camera Forward (Target - Center)
    const fwd = cam.target.sub(cam.center).normalize();
    try writer.interface.print("camera_fwd: {d:.4} {d:.4} {d:.4}\n", .{ -fwd.x, -fwd.y, -fwd.z });

    var world_up = Vec3.new(0, 1, 0);

    // If fwd and world_up are parallel (looking straight up or down), pick a different axis
    if (@abs(fwd.dot(world_up)) > 0.99) {
        world_up = Vec3.new(0, 0, 1);
    }

    // Recalculate basis to ensure Up is perfectly perpendicular to Forward
    const right = fwd.cross(world_up).normalize();
    const ortho_up = right.cross(fwd).normalize();
    // Camera Up (Calculate from Forward and World Up)
    try writer.interface.print("camera_up: {d:.4} {d:.4} {d:.4}\n", .{ ortho_up.x, ortho_up.y, ortho_up.z });

    try writer.interface.print("camera_fov_ha: 35\n", .{});
    try writer.interface.print("background: 0 0 0\n", .{});
    try writer.interface.print("\n", .{});
    try writer.interface.print("samples_per_pixel: 5\n", .{});

    // -------------------------------------------------------------------------
    // 2. Lights
    // -------------------------------------------------------------------------
    try writer.interface.print("# Lights\n", .{});
    for (scne.lights.items) |light| {
        switch (light.data) {
            .ambient => |amb| {
                try writer.interface.print("ambient_light: {d:.4} {d:.4} {d:.4}\n", .{ amb.intensity.x, amb.intensity.y, amb.intensity.z });
            },
            .point => |pt| {
                try writer.interface.print("point_light: {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ pt.color.x * 255, pt.color.y * 255, pt.color.z * 255, pt.loc.x, pt.loc.y, pt.loc.z });
            },
            .directional => |dir| {
                try writer.interface.print("directional_light: {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ dir.color.x * 255, dir.color.y * 255, dir.color.z * 255, dir.direction.x, dir.direction.y, dir.direction.z });
            },
        }
    }
    try writer.interface.print("\n", .{});

    // -------------------------------------------------------------------------
    // 3. Geometry Pre-Pass
    //    The format requires 'max_vertices' declared BEFORE any vertex commands.
    // -------------------------------------------------------------------------
    var total_verts: usize = 0;

    // Iterate all objects to count total mesh vertices needed
    for (scne.objects.items(.typ), scne.objects.items(.mesh_idx)) |typ, mesh_idx| {
        if (typ == .mesh or typ == .cube) {
            if (mesh_idx < scne.meshes.items.len) {
                total_verts += scne.meshes.items[mesh_idx].vertices.len;
            }
        }
    }

    if (total_verts > 0) {
        try writer.interface.print("max_vertices: {}\n", .{total_verts});
    }
    try writer.interface.print("\n", .{});

    // -------------------------------------------------------------------------
    // 4. Objects (Materials, Meshes & Spheres)
    // -------------------------------------------------------------------------

    // We need to track global vertex indices because the file format
    // puts all vertices in one big pool.
    var global_vertex_offset: usize = 0;
    var current_mat_idx: ?usize = null;

    const objects = scne.objects;
    for (0..objects.len) |i| {
        const obj = objects.get(i);

        // --- A. Material State Change ---
        if (current_mat_idx != obj.materail_idx) {
            if (obj.materail_idx < scne.materials.len) {
                const mat = scne.materials.get(obj.materail_idx);
                try writer.interface.print("material: {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4}\n", .{
                    mat.ambient_color.x,
                    mat.ambient_color.y,
                    mat.ambient_color.z,
                    mat.diffuse_color.x,
                    mat.diffuse_color.y,
                    mat.diffuse_color.z,
                    mat.specular_color.x,
                    mat.specular_color.y,
                    mat.specular_color.z,
                    mat.specular_coefficient,
                    mat.transmissive_color.x,
                    mat.transmissive_color.y,
                    mat.transmissive_color.z,
                    mat.index_of_refraction,
                });
                current_mat_idx = obj.materail_idx;
            }
        }

        // --- B. Geometry Output ---
        switch (obj.typ) {
            .sphere => {
                // Extract position (Translation) from the 4th column of matrix
                const pos = Vec3.new(obj.transform.fields[3][0], obj.transform.fields[3][1], obj.transform.fields[3][2]);

                // Extract radius (Scale) from the 1st column length
                //
                const v = obj.transform.fields[0];
                const radius = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) / 2;
                // const radius = obj.transform.fields[0].length();

                try writer.interface.print("sphere: {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ pos.x, pos.y, pos.z, radius });
            },
            .mesh, .cube => {
                if (obj.mesh_idx >= scne.meshes.items.len) continue;

                const mesh = scne.meshes.items[obj.mesh_idx];

                // 1. Bake Transform & Write Vertices
                // The file format has no "transform" command, so we must multiply
                // vertices by the object matrix before writing them.
                for (mesh.vertices) |v| {
                    const local_pos = zlm.Vec4.new(v.pos[0], v.pos[1], v.pos[2], 1);
                    const world_pos = local_pos.transform(obj.transform);
                    try writer.interface.print("vertex: {d:.4} {d:.4} {d:.4}\n", .{ world_pos.x, world_pos.y, world_pos.z });
                }

                // 2. Write Triangles
                // Assuming mesh.vertices is a "triangle list" (soup), not indexed.
                // We map local indices (0, 1, 2) to global indices (offset+0, offset+1, offset+2).
                var v_idx: usize = 0;
                while (v_idx + 2 < mesh.vertices.len) : (v_idx += 3) {
                    const idx1 = global_vertex_offset + v_idx;
                    const idx2 = global_vertex_offset + v_idx + 1;
                    const idx3 = global_vertex_offset + v_idx + 2;

                    try writer.interface.print("triangle: {} {} {}\n", .{ idx1, idx2, idx3 });
                }

                global_vertex_offset += mesh.vertices.len;
            },
        }
    }
    try writer.interface.flush();
}

// Camera properties
// output_image: [:0]const u8 = "raytraced.bmp",
// background: Vec3 = Vec3{ 0, 0, 0 },

// lights: std.ArrayList(Light),

// materials: std.ArrayList(Material),

// bvh: []bvh_tree.BVHNode = undefined,
//
// vertices: std.ArrayList(Vec3),
// normals: std.ArrayList(Vec3),
