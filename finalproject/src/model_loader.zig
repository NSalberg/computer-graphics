const std = @import("std");
const zlm = @import("zlm").as(f32);
const Scene = @import("scene.zig").Scene;
const CpuMesh = @import("scene.zig").CpuMesh;
const Object = @import("scene.zig").Object;
const SceneRenderer = @import("render.zig").SceneRenderer;
const Vertex = @import("render.zig").Vertex;

pub fn loadObjFile(allocator: std.mem.Allocator, path: []const u8, scne: *Scene, renderer: *SceneRenderer) !usize {
    const dir = try std.fs.openDirAbsolute("", .{});
    defer dir.close();

    var file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer file.close();
    const stat_size = std.math.cast(usize, try file.getEndPos()) orelse return error.FileTooBig;

    const file_contents = file.readToEndAllocOptions(allocator, stat_size, stat_size, .of(u8), null);

    const c = std.mem.trimRight(u8, file_contents, &std.ascii.whitespace);

    var vertices = std.ArrayList(Vertex).init(allocator);
    // defer vertices.deinit(); // Don't deinit if we pass ownership to Scene!

    // ... [PARSING LOGIC HERE: Parse 'v', 'vn', 'f' lines] ...
    // For now, let's pretend we parsed it into `vertices`

    const new_cpu_mesh = CpuMesh{
        .vertices = try vertices.toOwnedSlice(), // Transfer ownership
        .name = try allocator.dupe(u8, path),
    };

    // 3. Add to Scene (CPU Data)
    // We strictly maintain that index X in Scene matches index X in Renderer
    const mesh_idx = try scne.addMesh(allocator, new_cpu_mesh);

    // 4. Upload to GPU (Renderer Data)
    // We reuse the addMesh you already wrote
    renderer.addMesh(allocator, new_cpu_mesh);

    const new_obj = Object{
        .transform = zlm.Mat4.identity(),
        .mesh_idx = mesh_idx,
        .materail_idx = 0,
        .name = try allocator.dupe(u8, std.fs.path.basename(path)),
        .typ = .mesh,
    };

    const obj_idx = try scne.addObject(allocator, new_obj);
    return obj_idx;
}
