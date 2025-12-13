const std = @import("std");
const zlm = @import("zlm").as(f32);
const Scene = @import("scene.zig").Scene;
const CpuMesh = @import("scene.zig").CpuMesh;
const Object = @import("scene.zig").Object;
const SceneRenderer = @import("render.zig").SceneRenderer;

const Vec3 = zlm.Vec3;
const Vec2 = zlm.Vec2;
const Vertex = @import("render.zig").Vertex;

pub fn loadObjFile(
    allocator: std.mem.Allocator,
    dir: std.fs.Dir,
    path: []const u8,
    scne: *Scene,
    renderer: *SceneRenderer,
) !usize {
    const file_contents = try dir.readFileAlloc(allocator, path, std.math.maxInt(usize));

    const c = std.mem.trimRight(u8, file_contents, &std.ascii.whitespace);

    const vertices = try parseObj(allocator, c);

    const new_cpu_mesh = CpuMesh{
        .vertices = vertices,
        .name = try allocator.dupe(u8, path),
    };
    try renderer.addMesh(allocator, new_cpu_mesh);

    return try scne.addMesh(allocator, new_cpu_mesh);
}

/// Reccomend using an arena here.
/// Caller owns the returned vertex slice
pub fn parseObj(allocator: std.mem.Allocator, file_content: []const u8) ![]Vertex {
    var temp_positions: std.ArrayList(Vec3) = .empty;
    defer temp_positions.deinit(allocator);

    var temp_normals: std.ArrayList(Vec3) = .empty;
    defer temp_normals.deinit(allocator);

    var temp_uvs: std.ArrayList(Vec2) = .empty;
    defer temp_uvs.deinit(allocator);

    var final_vertices: std.ArrayList(Vertex) = .empty;
    errdefer final_vertices.deinit(allocator);

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

            if (temp_normals.items.len == 0 and count >= 3) {
                const p0 = Vec3.new(face_verts[0].pos[0], face_verts[0].pos[1], face_verts[0].pos[2]);
                const p1 = Vec3.new(face_verts[1].pos[0], face_verts[1].pos[1], face_verts[1].pos[2]);
                const p2 = Vec3.new(face_verts[2].pos[0], face_verts[2].pos[1], face_verts[2].pos[2]);

                const edge1 = p1.sub(p0);
                const edge2 = p2.sub(p0);
                const face_normal = edge1.cross(edge2).normalize();

                const n_array = [3]f32{ face_normal.x, face_normal.y, face_normal.z };
                face_verts[0].normal = n_array;
                face_verts[1].normal = n_array;
                face_verts[2].normal = n_array;
                if (count == 4) face_verts[3].normal = n_array;
            }

            if (count >= 3) {
                try final_vertices.append(allocator, face_verts[0]);
                try final_vertices.append(allocator, face_verts[1]);
                try final_vertices.append(allocator, face_verts[2]);
            }
            if (count == 4) {
                try final_vertices.append(allocator, face_verts[0]);
                try final_vertices.append(allocator, face_verts[2]);
                try final_vertices.append(allocator, face_verts[3]);
            }
        }
    }

    return final_vertices.toOwnedSlice(allocator);
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

    const v_idx = try std.fmt.parseInt(usize, v_str.?, 10) - 1; // OBJ is 1-based
    const pos = if (v_idx < positions.len) positions[v_idx] else Vec3.zero;

    var uv = Vec2.zero;
    if (vt_str) |s| {
        if (s.len > 0) {
            const vt_idx = try std.fmt.parseInt(usize, s, 10) - 1;
            if (vt_idx < uvs.len) uv = uvs[vt_idx];
        }
    }

    var normal = Vec3.new(0, 1, 0);
    if (vn_str) |s| {
        if (s.len > 0) {
            const vn_idx = try std.fmt.parseInt(usize, s, 10) - 1;
            if (vn_idx < normals.len) normal = normals[vn_idx];
        }
    }

    return Vertex{
        .pos = .{ pos.x, pos.y, pos.z },
        .normal = .{ normal.x, normal.y, normal.z },
        .uv = .{ uv.x, uv.y },
    };
}
