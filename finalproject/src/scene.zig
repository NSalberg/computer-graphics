const std = @import("std");
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;

pub const Sphere = struct {
    center: Vec3,
    radius: f32,
    scale: Vec3,
};

pub const Cube = struct {
    center: Vec3,
    scale: Vec3,
    rotation: Vec3,
};

pub const Object = union(enum) {
    sphere: Sphere,
    cube: Cube,
    // pentagon,
    // pyramid,
    // camera,
    //    fn tag(self: U2) usize {
    pub fn tag(self: Object) usize {
        switch (self) {
            .cube => return 0,
            .sphere => return 1,
        }
    }
};

// const Scene = struct {
//     objects: Object,
//     base_transform: zlm.Vec4 = zlm.Vec4.one,
// };

/// Describes the 3d world, contains objects, camera, lights, etc.
pub const Scene = struct {
    // camera: Camera = Camera{},
    // Camera properties

    // output_image: [:0]const u8 = "raytraced.bmp",

    objects: std.MultiArrayList(Object) = .empty,

    // background: Vec3 = Vec3{ 0, 0, 0 },

    // lights: std.ArrayList(Light),

    // materials: std.ArrayList(Material),

    // bvh: []bvh_tree.BVHNode = undefined,
    //
    // vertices: std.ArrayList(Vec3),
    // normals: std.ArrayList(Vec3),
};
