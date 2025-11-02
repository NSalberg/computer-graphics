const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const main = @import("main.zig");
const std = @import("std");
const aabb = @import("aabb.zig");
const Scene = @import("scene.zig").Scene;
const objects = @import("objects.zig");

pub fn buildBVH(scene: *Scene, alloc: std.mem.Allocator) !void {
    const num_objects = 2 * scene.objects.items.len - 1;
    const bvh = try alloc.alloc(BVHNode, num_objects);

    scene.bvh = bvh;
    // scene.bvh = std.ArrayList(BVHNode).initBuffer(bvh);

    var nodes_used: usize = 1;
    const root: *BVHNode = &bvh[0];
    root.left_child_idx = 0;
    root.first_obj_idx = 0;
    root.obj_count = scene.objects.items.len;
    root.updateBounds(scene);
    root.subdivide(scene, &nodes_used);
}

pub const BVHNode = struct {
    aab: aabb.AxisAlignedBB,
    left_child_idx: usize,
    first_obj_idx: usize,
    obj_count: usize,

    pub inline fn isLeaf(self: BVHNode) bool {
        return self.obj_count > 0;
    }

    pub fn updateBounds(self: *BVHNode, scene: *Scene) void {
        const node_idx = self.first_obj_idx;
        self.aab = aabb.AxisAlignedBB{
            .min = vec3.splat(std.math.inf(f64)),
            .max = vec3.splat(-std.math.inf(f64)),
        };
        for (scene.objects.items[node_idx..(node_idx + self.obj_count)]) |obj| {
            const bounding_box = obj.boundingBox();
            self.aab.min = @min(self.aab.min, bounding_box.min);
            self.aab.max = @max(self.aab.max, bounding_box.max);
            if (node_idx == 0) {
                std.debug.print("aabb0: {} {}\n", .{ self.aab.min, self.aab.max });
            }
        }
        if (node_idx == 0) {
            std.debug.print("aabb0 fin: {} {}\n", .{ self.aab.min, self.aab.max });
        }
    }

    pub fn subdivide(node: *BVHNode, scene: *Scene, nodes_used: *usize) void {
        if (node.obj_count <= 2) return;

        const extent = node.aab.max - node.aab.min;
        var axis: u4 = 0;
        if (extent[1] > extent[0]) axis = 1;
        if (extent[2] > extent[axis]) axis = 2;

        const split_pos = node.aab.min[axis] + extent[axis] * 0.5;
        var i = node.first_obj_idx;
        var j = i + node.obj_count - 1;
        while (i <= j) {
            const centroid = scene.objects.items[i].centroid()[axis];
            if (centroid < split_pos) {
                i += 1;
            } else {
                std.mem.swap(objects.Object, &scene.objects.items[i], &scene.objects.items[j]);
                j -= 1;
            }
        }
        const left_count = i - node.first_obj_idx;
        if (left_count == 0 or left_count == node.obj_count) return;

        const left_child_idx = nodes_used.*;
        const right_child_idx = nodes_used.* + 1;
        nodes_used.* += 2;
        node.left_child_idx = left_child_idx;

        scene.bvh[left_child_idx].first_obj_idx = node.first_obj_idx;
        scene.bvh[left_child_idx].obj_count = left_count;

        scene.bvh[right_child_idx].first_obj_idx = i;
        scene.bvh[right_child_idx].obj_count = node.obj_count - left_count;

        node.obj_count = 0;

        scene.bvh[left_child_idx].updateBounds(scene);
        scene.bvh[right_child_idx].updateBounds(scene);
        // std.debug.print("Node {}: left={}, right={}, obj_count={}\n", .{ nodes_used.* - 2, left_child_idx, right_child_idx, self.obj_count });

        scene.bvh[left_child_idx].subdivide(scene, nodes_used);
        scene.bvh[right_child_idx].subdivide(scene, nodes_used);
    }
};
