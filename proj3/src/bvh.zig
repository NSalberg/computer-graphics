const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const main = @import("main.zig");
const std = @import("std");
const aabb = @import("aabb.zig");
const Scene = @import("scene.zig").Scene;

pub fn buildBVH(scene: *Scene, alloc: std.mem.Allocator) !void {
    const num_objects = 2 * scene.objects.items.len - 1;
    const bvh = try alloc.alloc(BVHNode, num_objects);

    for (bvh) |*node| {
        node.* = std.mem.zeroInit(BVHNode, .{});
    }

    scene.bvh = std.ArrayList(BVHNode).fromOwnedSlice(bvh);
    // scene.bvh = std.ArrayList(BVHNode).initBuffer(bvh);

    var nodes_used: usize = 1;
    const root: *BVHNode = &bvh[0];
    root.left_child = 0;
    root.right_child = 0;
    root.first_obj = 0;
    root.obj_count = scene.objects.items.len;
    root.updateBounds(scene);
    root.subdivide(scene, &nodes_used);
}

pub const BVHNode = struct {
    aab: aabb.AxisAlignedBB,
    left_child: usize,
    right_child: usize,
    first_obj: usize,
    obj_count: usize,

    pub inline fn isLeaf(self: BVHNode) bool {
        return self.obj_count > 0;
    }

    pub fn updateBounds(self: *BVHNode, scene: *Scene) void {
        const node_idx = self.first_obj;
        self.aab = aabb.AxisAlignedBB{
            .max = vec3.splat(-std.math.inf(f64)),
            .min = vec3.splat(std.math.inf(f64)),
        };
        for (scene.objects.items[node_idx..(node_idx + self.obj_count)]) |obj| {
            const bounding_box = obj.boundingBox();
            self.aab.min = @min(self.aab.min, bounding_box.min);
            self.aab.max = @max(self.aab.max, bounding_box.max);
        }
    }

    pub fn subdivide(self: *BVHNode, scene: *Scene, nodes_used: *usize) void {
        if (self.obj_count < 2) return;

        const extent = self.aab.max - self.aab.min;
        var axis: u4 = 0;
        if (extent[1] > extent[0]) axis = 1;
        if (extent[2] > extent[axis]) axis = 2;

        const split_pos = self.aab.min[axis] + extent[axis] * 0.5;
        var i = self.first_obj;
        var j = i + self.obj_count - 1;
        while (i <= j) {
            const t = scene.objects.items[i];
            const centroid = t.centroid()[axis];
            if (centroid < split_pos) {
                i += 1;
            } else {
                j -= 1;
                scene.objects.items[i] = scene.objects.items[j];
                scene.objects.items[j] = t;
            }
        }
        const left_count = i - self.first_obj;
        if (left_count == 0 or left_count == self.obj_count) return;
        //
        const left_child_idx = nodes_used.*;
        const right_child_idx = nodes_used.* + 1;
        nodes_used.* += 2;
        self.left_child = left_child_idx;
        self.right_child = right_child_idx;

        scene.bvh.items[left_child_idx].first_obj = self.first_obj;
        scene.bvh.items[left_child_idx].obj_count = left_count;

        scene.bvh.items[right_child_idx].first_obj = i;
        scene.bvh.items[right_child_idx].obj_count = self.obj_count - left_count;

        self.obj_count = 0;

        scene.bvh.items[left_child_idx].updateBounds(scene);
        scene.bvh.items[right_child_idx].updateBounds(scene);

        scene.bvh.items[left_child_idx].subdivide(scene, nodes_used);
        scene.bvh.items[right_child_idx].subdivide(scene, nodes_used);
    }
};
