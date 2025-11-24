const root = @import("root.zig");
const std = @import("std");
const Vertex = root.Vertex;

const segments = 12;
const handle_verts = segments * 6; // 2 triangles per segment
const shaft_verts = 36; // 6 faces, 2 triangles per face, 3 vertices per triangle
const total_verts = handle_verts + shaft_verts;

pub fn generateKey() [total_verts]Vertex {
    comptime {
        const handle_r = 0.15;
        const handle_h = 0.05;
        const shaft_w = 0.05;
        const shaft_l = 0.3;

        var vertices: [total_verts]Vertex = undefined;
        var idx: usize = 0;

        // --- Generate handle (torus-like ring) ---
        for (0..segments) |i| {
            const a1 = 2.0 * std.math.pi * @as(f32, i) / @as(f32, segments);
            const a2 = 2.0 * std.math.pi * @as(f32, i + 1) / @as(f32, segments);
            const x1 = handle_r * @cos(a1);
            const z1 = handle_r * @sin(a1);
            const x2 = handle_r * @cos(a2);
            const z2 = handle_r * @sin(a2);

            const normal1 = [3]f32{ x1, 0, z1 };
            const normal2 = [3]f32{ x2, 0, z2 };

            // 2 triangles per segment
            vertices[idx] = .{ .pos = .{ x1, -handle_h, z1 }, .normal = normal1, .uv = .{ 0, 0 } };
            idx += 1;
            vertices[idx] = .{ .pos = .{ x2, -handle_h, z2 }, .normal = normal2, .uv = .{ 1, 0 } };
            idx += 1;
            vertices[idx] = .{ .pos = .{ x2, handle_h, z2 }, .normal = normal2, .uv = .{ 1, 1 } };
            idx += 1;

            vertices[idx] = .{ .pos = .{ x1, -handle_h, z1 }, .normal = normal1, .uv = .{ 0, 0 } };
            idx += 1;
            vertices[idx] = .{ .pos = .{ x2, handle_h, z2 }, .normal = normal2, .uv = .{ 1, 1 } };
            idx += 1;
            vertices[idx] = .{ .pos = .{ x1, handle_h, z1 }, .normal = normal1, .uv = .{ 0, 1 } };
            idx += 1;
        }

        // --- Generate shaft (box) ---
        const sx = shaft_w;
        const sy = handle_h;
        const sz = shaft_l;
        const ox = handle_r + sz / 2.0;

        const box_positions = [_][3]f32{
            // Front face
            .{ -sx + ox, -sy, -sz / 2.0 }, .{ sx + ox, -sy, -sz / 2.0 },  .{ sx + ox, sy, -sz / 2.0 },
            .{ -sx + ox, -sy, -sz / 2.0 }, .{ sx + ox, sy, -sz / 2.0 },   .{ -sx + ox, sy, -sz / 2.0 },
            // Back face
            .{ sx + ox, -sy, sz / 2.0 },   .{ -sx + ox, -sy, sz / 2.0 },  .{ -sx + ox, sy, sz / 2.0 },
            .{ sx + ox, -sy, sz / 2.0 },   .{ -sx + ox, sy, sz / 2.0 },   .{ sx + ox, sy, sz / 2.0 },
            // Left face
            .{ -sx + ox, -sy, sz / 2.0 },  .{ -sx + ox, -sy, -sz / 2.0 }, .{ -sx + ox, sy, -sz / 2.0 },
            .{ -sx + ox, -sy, sz / 2.0 },  .{ -sx + ox, sy, -sz / 2.0 },  .{ -sx + ox, sy, sz / 2.0 },
            // Right face
            .{ sx + ox, -sy, -sz / 2.0 },  .{ sx + ox, -sy, sz / 2.0 },   .{ sx + ox, sy, sz / 2.0 },
            .{ sx + ox, -sy, -sz / 2.0 },  .{ sx + ox, sy, sz / 2.0 },    .{ sx + ox, sy, -sz / 2.0 },
            // Top face
            .{ -sx + ox, sy, -sz / 2.0 },  .{ sx + ox, sy, -sz / 2.0 },   .{ sx + ox, sy, sz / 2.0 },
            .{ -sx + ox, sy, -sz / 2.0 },  .{ sx + ox, sy, sz / 2.0 },    .{ -sx + ox, sy, sz / 2.0 },
            // Bottom face
            .{ -sx + ox, -sy, sz / 2.0 },  .{ sx + ox, -sy, sz / 2.0 },   .{ sx + ox, -sy, -sz / 2.0 },
            .{ -sx + ox, -sy, sz / 2.0 },  .{ sx + ox, -sy, -sz / 2.0 },  .{ -sx + ox, -sy, -sz / 2.0 },
        };

        const face_normals = [_][3]f32{
            .{ 0, 0, -1 }, // front
            .{ 0, 0, 1 }, // back
            .{ -1, 0, 0 }, // left
            .{ 1, 0, 0 }, // right
            .{ 0, 1, 0 }, // top
            .{ 0, -1, 0 }, // bottom
        };

        var face = 0;
        for (0..36) |i| {
            vertices[idx] = .{
                .pos = box_positions[i],
                .normal = face_normals[face],
                .uv = .{ 0, 0 },
            };
            idx += 1;
            if ((i + 1) % 6 == 0) face += 1;
        }

        return vertices;
    }
}

pub const key_vertices = generateKey();

pub const cube_vertices = [36]Vertex{
    // Front (Z+)
    .{ .pos = .{ -0.5, -0.5, 0.5 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, -0.5, 0.5 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 0 } },
    .{ .pos = .{ 0.5, 0.5, 0.5 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, -0.5, 0.5 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, 0.5, 0.5 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, 0.5, 0.5 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 1 } },
    // Back (Z-)
    .{ .pos = .{ 0.5, -0.5, -0.5 }, .normal = .{ 0, 0, -1 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ -0.5, -0.5, -0.5 }, .normal = .{ 0, 0, -1 }, .uv = .{ 1, 0 } },
    .{ .pos = .{ -0.5, 0.5, -0.5 }, .normal = .{ 0, 0, -1 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ 0.5, -0.5, -0.5 }, .normal = .{ 0, 0, -1 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ -0.5, 0.5, -0.5 }, .normal = .{ 0, 0, -1 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ 0.5, 0.5, -0.5 }, .normal = .{ 0, 0, -1 }, .uv = .{ 0, 1 } },
    // Left (X-)
    .{ .pos = .{ -0.5, -0.5, -0.5 }, .normal = .{ -1, 0, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ -0.5, -0.5, 0.5 }, .normal = .{ -1, 0, 0 }, .uv = .{ 1, 0 } },
    .{ .pos = .{ -0.5, 0.5, 0.5 }, .normal = .{ -1, 0, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, -0.5, -0.5 }, .normal = .{ -1, 0, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ -0.5, 0.5, 0.5 }, .normal = .{ -1, 0, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, 0.5, -0.5 }, .normal = .{ -1, 0, 0 }, .uv = .{ 0, 1 } },
    // Right (X+)
    .{ .pos = .{ 0.5, -0.5, 0.5 }, .normal = .{ 1, 0, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, -0.5, -0.5 }, .normal = .{ 1, 0, 0 }, .uv = .{ 1, 0 } },
    .{ .pos = .{ 0.5, 0.5, -0.5 }, .normal = .{ 1, 0, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ 0.5, -0.5, 0.5 }, .normal = .{ 1, 0, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, 0.5, -0.5 }, .normal = .{ 1, 0, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ 0.5, 0.5, 0.5 }, .normal = .{ 1, 0, 0 }, .uv = .{ 0, 1 } },
    // Top (Y+)
    .{ .pos = .{ -0.5, 0.5, 0.5 }, .normal = .{ 0, 1, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, 0.5, 0.5 }, .normal = .{ 0, 1, 0 }, .uv = .{ 1, 0 } },
    .{ .pos = .{ 0.5, 0.5, -0.5 }, .normal = .{ 0, 1, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, 0.5, 0.5 }, .normal = .{ 0, 1, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, 0.5, -0.5 }, .normal = .{ 0, 1, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, 0.5, -0.5 }, .normal = .{ 0, 1, 0 }, .uv = .{ 0, 1 } },
    // Bottom (Y-)
    .{ .pos = .{ -0.5, -0.5, -0.5 }, .normal = .{ 0, -1, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, -0.5, -0.5 }, .normal = .{ 0, -1, 0 }, .uv = .{ 1, 0 } },
    .{ .pos = .{ 0.5, -0.5, 0.5 }, .normal = .{ 0, -1, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, -0.5, -0.5 }, .normal = .{ 0, -1, 0 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ 0.5, -0.5, 0.5 }, .normal = .{ 0, -1, 0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -0.5, -0.5, 0.5 }, .normal = .{ 0, -1, 0 }, .uv = .{ 0, 1 } },
};

pub const floor_vertices: [6]Vertex = .{
    Vertex{ .pos = .{ 0, 0, 0 }, .normal = .{ 0, 1, 0 }, .uv = .{ 0, 0 } },
    Vertex{ .pos = .{ 1, 0, 0 }, .normal = .{ 0, 1, 0 }, .uv = .{ 1, 0 } },
    Vertex{ .pos = .{ 1, 0, 1 }, .normal = .{ 0, 1, 0 }, .uv = .{ 1, 1 } },
    Vertex{ .pos = .{ 0, 0, 0 }, .normal = .{ 0, 1, 0 }, .uv = .{ 0, 0 } },
    Vertex{ .pos = .{ 1, 0, 1 }, .normal = .{ 0, 1, 0 }, .uv = .{ 1, 1 } },
    Vertex{ .pos = .{ 0, 0, 1 }, .normal = .{ 0, 1, 0 }, .uv = .{ 0, 1 } },
};
