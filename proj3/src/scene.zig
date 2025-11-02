const vec3 = @import("vec3.zig");
const main = @import("main.zig");
const bvh_tree = @import("bvh.zig");
const Light = @import("lights.zig").Light;
const Camera = @import("camera.zig").Camera;
const Image = @import("image.zig").Image;
const Vec3 = vec3.Vec3;
const std = @import("std");
const assert = std.debug.assert;

const objects = @import("objects.zig");

pub const Scene = struct {
    camera: Camera = Camera{},
    // Camera properties

    output_image: [:0]const u8 = "raytraced.bmp",

    objects: std.ArrayList(objects.Object),

    background: Vec3 = Vec3{ 0, 0, 0 },

    lights: std.ArrayList(Light),

    materials: std.ArrayList(Material),

    bvh: []bvh_tree.BVHNode = undefined,

    vertices: std.ArrayList(Vec3),
    normals: std.ArrayList(Vec3),

    pub fn render(self: Scene, alloc: std.mem.Allocator) !Image {
        return self.camera.render(alloc, self);
    }

    pub fn shadeRay(self: *const Scene, ray: main.Ray, bounces: u16) Vec3 {
        // Hit objects
        const hit_obj: ?main.HitRecord = self.hit(ray, 0, std.math.inf(f64));
        var color: Vec3 = self.background;

        if (hit_obj == null) {
            return color;
        }

        // we got a hit
        color = vec3.zero;
        for (self.lights.items) |light| {
            color += light.illuminate(ray, hit_obj.?, self);
            // Reflect
        }
        if (bounces > 0) {
            // Reflect
            const n = hit_obj.?.surface_normal;
            const material = self.materials.items[hit_obj.?.material_idx];

            const p = ray.eval(hit_obj.?.distance);
            if (vec3.magnitude2(material.specular_color) > 0.001) {
                const reflection = vec3.reflect(ray.dir, n);
                // bounce_point + eps * normal

                const bounce_color = material.specular_color * self.shadeRay(.{ .dir = reflection, .origin = p + n * vec3.splat(0.001) }, bounces - 1);
                color += bounce_color;
            }

            if (vec3.magnitude2(material.transmissive_color) > 0.001) {
                const entering = vec3.dot(ray.dir, n) < 0;
                const etai_over_etat = if (entering)
                    1.0 / material.index_of_refraction // air -> material
                else
                    material.index_of_refraction; // material -> air

                const normal = if (entering) n else -n;

                const refraction = vec3.refract(ray.dir, normal, etai_over_etat);
                const bounce_color = material.transmissive_color * self.shadeRay(.{ .dir = refraction, .origin = p + refraction * vec3.splat(0.001) }, bounces - 1);
                color += bounce_color;
            }
        }
        return color;
    }

    pub fn intersectBVH(self: Scene, ray: main.Ray, r: f64, node_idx: usize) ?main.HitRecord {
        const node = self.bvh[node_idx];
        if (!node.aab.hit(ray, 0, r)) {
            return null;
        }

        if (node.isLeaf()) {
            var closest_dist = r;
            var closest_hit: ?main.HitRecord = null;
            for (self.objects.items[node.first_obj_idx..(node.first_obj_idx + node.obj_count)]) |obj| {
                // std.debug.print("obj_count{}\n", .{node.obj_count});
                // Use closest_dist instead of r for early termination
                const hit_record = obj.hit(ray, 0, closest_dist);
                if (hit_record != null and hit_record.?.distance < closest_dist) {
                    closest_dist = hit_record.?.distance;
                    closest_hit = hit_record;
                }
            }
            return closest_hit;
        } else {
            // Check left child first
            var closest_dist = r;
            var closest_hit: ?main.HitRecord = null;

            if (self.intersectBVH(ray, closest_dist, node.left_child_idx)) |hitl| {
                closest_dist = hitl.distance;
                closest_hit = hitl;
            }

            // Check right child with updated distance (big performance win!)
            if (self.intersectBVH(ray, closest_dist, node.right_child_idx)) |hitr| {
                closest_hit = hitr;
            }

            return closest_hit;
        }
    }
    // Trace a ray through the scene from t = [0 + eps, r)
    pub fn hit(self: Scene, ray: main.Ray, eps: f64, r: f64) ?main.HitRecord {
        const eps_ray: main.Ray = .{
            .dir = ray.dir,
            .origin = ray.origin + ray.dir * vec3.splat(eps),
        };

        const closest_hit = intersectBVH(self, eps_ray, r, 0);

        return closest_hit;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{f}\n", .{self.camera});

        for (self.objects.items) |sphere| {
            try writer.print("{f}\n", .{sphere});
        }

        try writer.print("background: {d}, {d}, {d}\n", .{ self.background[0], self.background[1], self.background[2] });

        for (self.lights.items) |l| {
            try writer.print("{f}\n", .{l});
        }
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
