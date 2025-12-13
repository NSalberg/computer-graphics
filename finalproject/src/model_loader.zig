const std = @import("std");
const zlm = @import("zlm").as(f32);
const Scene = @import("scene.zig").Scene;
const CpuMesh = @import("scene.zig").CpuMesh;
const Object = @import("scene.zig").Object;
const SceneRenderer = @import("render.zig").SceneRenderer;

const Vec3 = zlm.Vec3;
const Vec2 = zlm.Vec2;
const Vertex = @import("render.zig").Vertex;

pub fn loadObjFile(allocator: std.mem.Allocator, path: []const u8, scne: *Scene, renderer: *SceneRenderer) !usize {
    const dir = try std.fs.openDirAbsolute("", .{});
    defer dir.close();

    var file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer file.close();
    const stat_size = std.math.cast(usize, try file.getEndPos()) orelse return error.FileTooBig;

    const file_contents = file.readToEndAllocOptions(allocator, stat_size, stat_size, .of(u8), null);

    const c = std.mem.trimRight(u8, file_contents, &std.ascii.whitespace);

    const vertices = parseObj(allocator, c);

    const new_cpu_mesh = CpuMesh{
        .vertices = try vertices.toOwnedSlice(),
        .name = try allocator.dupe(u8, path),
    };

    const mesh_idx = try scne.addMesh(allocator, new_cpu_mesh);

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

/// Reccomend using an arena here.
/// Caller owns the returned vertex slice
pub fn parseObj(allocator: std.mem.Allocator, file_content: []const u8) ![]Vertex {
    var temp_positions: std.ArrayList(Vec3) = .empty;
    defer temp_positions.deinit();

    var temp_normals: std.ArrayList(Vec3) = .empty;
    defer temp_normals.deinit();

    var temp_uvs: std.ArrayList(Vec2) = .empty;
    defer temp_uvs.deinit();

    var final_vertices: std.ArrayList(Vertex) = .empty;
    errdefer final_vertices.deinit();

    var lines = std.mem.tokenizeAny(u8, file_content, "\r\n");
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;

        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const type_str = tokens.next() orelse continue;

        if (std.mem.eql(u8, type_str, "v")) {
            const x = try parseFloat(tokens.next());
            const y = try parseFloat(tokens.next());
            const z = try parseFloat(tokens.next());
            try temp_positions.append(allocator, Vec3.new(x, y, z));
        } else if (std.mem.eql(u8, type_str, "vn")) {
            // -- Vertex Normal --
            const x = try parseFloat(tokens.next());
            const y = try parseFloat(tokens.next());
            const z = try parseFloat(tokens.next());
            try temp_normals.append(allocator, Vec3.new(x, y, z));
        } else if (std.mem.eql(u8, type_str, "vt")) {
            // -- Vertex UV --
            const u = try parseFloat(tokens.next());
            const v = try parseFloat(tokens.next());
            try temp_uvs.append(allocator, Vec2.new(u, v));
        } else if (std.mem.eql(u8, type_str, "f")) {
            // -- Face (Triangle or Quad) --
            // We need to collect the indices for this face
            // Format is v/vt/vn or v//vn or v/vt

            var face_verts: [4]Vertex = undefined;
            var count: usize = 0;

            while (tokens.next()) |face_token| {
                if (count >= 4) break;

                // Parse "1/2/3" string
                face_verts[count] = try parseFaceIndices(face_token, temp_positions.items, temp_uvs.items, temp_normals.items);
                count += 1;
            }

            // Triangulate (Fan method)
            // Triangle 1: 0, 1, 2
            if (count >= 3) {
                try final_vertices.append(allocator, face_verts[0]);
                try final_vertices.append(allocator, face_verts[1]);
                try final_vertices.append(allocator, face_verts[2]);
            }
            // Triangle 2: 0, 2, 3 (if it was a quad)
            if (count == 4) {
                try final_vertices.append(allocator, face_verts[0]);
                try final_vertices.append(allocator, face_verts[2]);
                try final_vertices.append(allocator, face_verts[3]);
            }
        }
    }

    return final_vertices.toOwnedSlice();
}

// Helpers

fn parseFloat(str: ?[]const u8) !f32 {
    if (str) |s| return std.fmt.parseFloat(f32, s);
    return error.InvalidFormat;
}

fn parseFaceIndices(token: []const u8, positions: []const Vec3, uvs: []const Vec2, normals: []const Vec3) !Vertex {
    var iter = std.mem.splitScalar(u8, token, '/');

    const v_str = iter.next();
    const vt_str = iter.next();
    const vn_str = iter.next();

    // 1. Position (Required)
    const v_idx = try std.fmt.parseInt(usize, v_str.?, 10) - 1; // OBJ is 1-based
    const pos = if (v_idx < positions.len) positions[v_idx] else Vec3.zero;

    // 2. UV (Optional)
    var uv = Vec2.zero;
    if (vt_str) |s| {
        if (s.len > 0) {
            const vt_idx = try std.fmt.parseInt(usize, s, 10) - 1;
            if (vt_idx < uvs.len) uv = uvs[vt_idx];
        }
    }

    // 3. Normal (Optional)
    var normal = Vec3.new(0, 1, 0);
    if (vn_str) |s| {
        if (s.len > 0) {
            const vn_idx = try std.fmt.parseInt(usize, s, 10) - 1;
            if (vn_idx < normals.len) normal = normals[vn_idx];
        }
    }

    return Vertex{ .pos = pos, .normal = normal, .uv = uv };
}
