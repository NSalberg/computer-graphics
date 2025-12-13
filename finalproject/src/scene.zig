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

const Camera = struct {
    center: Vec3,
    target: Vec3,

    pub fn orbit(self: *Camera, dx: f32, dy: f32) void {
        std.debug.print("dx, dy: {} {}\n", .{ dx, dy });
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
        std.debug.print("old_off {f}, new_off{f}\n", .{ cur_offset, new_offset });

        // 5. Apply the calculated position relative to the target
        self.center = self.target.add(new_offset);
    }

    pub fn translate(self: *Camera, dx: f32, dy: f32) void {
        const sensitivity = 0.005;
        // const dist = self.center.sub(self.target).length();
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
    color: Vec3,
};

/// Describes the 3d world, contains objects, camera, lights, etc.
pub const Scene = struct {
    camera: Camera = Camera{
        .center = Vec3.one,
        .target = Vec3.zero,
    },
    meshes: std.ArrayList(CpuMesh) = .empty,
    materials: std.ArrayList(Material) = .empty,

    objects: std.MultiArrayList(Object) = .empty,

    // Camera properties
    // output_image: [:0]const u8 = "raytraced.bmp",
    // background: Vec3 = Vec3{ 0, 0, 0 },

    // lights: std.ArrayList(Light),

    // materials: std.ArrayList(Material),

    // bvh: []bvh_tree.BVHNode = undefined,
    //
    // vertices: std.ArrayList(Vec3),
    // normals: std.ArrayList(Vec3),
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
        return self.materials.items.len - 1;
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
