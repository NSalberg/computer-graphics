const std = @import("std");
const gl = @import("gl");
const shader_version = switch (gl.info.api) {
    .gl => (
        \\#version 410 core
        \\
    ),
    .gles, .glsc => (
        \\#version 300 es
        \\
    ),
};

var info_log_buf: [512:0]u8 = undefined;
const vertex_shader_source = @embedFile("shaders/vertex_shader.glsl");
const fragment_shader_source = @embedFile("shaders/fragment_shader.glsl");
const Vertex = @import("render.zig").Vertex;

// pub const vertex_shader = compileShader(vertex_shader_source, gl.VERTEX_SHADER);
// pub const fragment_shader = compileShader(fragment_shader_source, gl.FRAGMENT_SHADER);

const gl_log = std.log.scoped(.gl);
pub fn compileShader(shader_source: []const u8, shader_type: c_uint) !c_uint {
    const shader = gl.CreateShader(shader_type);
    var success: c_int = undefined;
    gl.ShaderSource(shader, 2, &.{ shader_version, shader_source.ptr }, null);
    gl.CompileShader(shader);
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, (&success)[0..1]);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(shader, info_log_buf.len, null, &info_log_buf);
        gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return error.GlCompileShaderFailed;
    }
    return shader;
}

pub fn linkProgram(program: c_uint) !void {
    var success: c_int = undefined;
    gl.LinkProgram(program);
    gl.GetProgramiv(program, gl.LINK_STATUS, (&success)[0..1]);
    if (success == gl.FALSE) {
        gl.GetProgramInfoLog(program, info_log_buf.len, null, &info_log_buf);
        gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return error.LinkProgramFailed;
    }
}

pub fn createProgram() !c_uint {
    const vertex_shader = try compileShader(vertex_shader_source, gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertex_shader);

    const fragment_shader = try compileShader(fragment_shader_source, gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragment_shader);

    const program = gl.CreateProgram();
    errdefer gl.DeleteProgram(program);
    if (program == 0) return error.GlCreateProgramFailed;

    gl.AttachShader(program, vertex_shader);
    gl.AttachShader(program, fragment_shader);

    try linkProgram(program);

    return program;
}

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

/// Generate a UV sphere with the given subdivisions
/// segments = number of vertical divisions (longitude)
/// rings = number of horizontal divisions (latitude)
/// Returns an array of vertices that can be allocated at comptime or runtime
pub fn generateSphere(comptime segments: usize, comptime rings: usize) [(segments * rings * 6)]Vertex {
    var vertices: [(segments * rings * 6)]Vertex = undefined;
    var idx: usize = 0;

    const pi = std.math.pi;
    @setEvalBranchQuota(1000000);

    var r: usize = 0;
    while (r < rings) : (r += 1) {
        var s: usize = 0;
        while (s < segments) : (s += 1) {
            const theta = @as(f32, @floatFromInt(r)) / @as(f32, @floatFromInt(rings)) * pi;
            const phi = @as(f32, @floatFromInt(s)) / @as(f32, @floatFromInt(segments)) * 2.0 * pi;

            const theta_next = @as(f32, @floatFromInt(r + 1)) / @as(f32, @floatFromInt(rings)) * pi;
            const phi_next = @as(f32, @floatFromInt(s + 1)) / @as(f32, @floatFromInt(segments)) * 2.0 * pi;

            // Four corners of the quad
            const p0 = spherePoint(theta, phi);
            const p1 = spherePoint(theta, phi_next);
            const p2 = spherePoint(theta_next, phi_next);
            const p3 = spherePoint(theta_next, phi);

            // UVs
            const @"u0" = @as(f32, @floatFromInt(s)) / @as(f32, @floatFromInt(segments));
            const v0 = @as(f32, @floatFromInt(r)) / @as(f32, @floatFromInt(rings));
            const @"u1" = @as(f32, @floatFromInt(s + 1)) / @as(f32, @floatFromInt(segments));
            const v1 = @as(f32, @floatFromInt(r + 1)) / @as(f32, @floatFromInt(rings));

            // Triangle 1
            vertices[idx] = .{ .pos = p0.pos, .normal = p0.normal, .uv = .{ @"u0", v0 } };
            idx += 1;
            vertices[idx] = .{ .pos = p1.pos, .normal = p1.normal, .uv = .{ @"u1", v0 } };
            idx += 1;
            vertices[idx] = .{ .pos = p2.pos, .normal = p2.normal, .uv = .{ @"u1", v1 } };
            idx += 1;

            // Triangle 2
            vertices[idx] = .{ .pos = p0.pos, .normal = p0.normal, .uv = .{ @"u0", v0 } };
            idx += 1;
            vertices[idx] = .{ .pos = p2.pos, .normal = p2.normal, .uv = .{ @"u1", v1 } };
            idx += 1;
            vertices[idx] = .{ .pos = p3.pos, .normal = p3.normal, .uv = .{ @"u0", v1 } };
            idx += 1;
        }
    }

    return vertices;
}

fn spherePoint(theta: f32, phi: f32) struct { pos: [3]f32, normal: [3]f32 } {
    const sin_theta = @sin(theta);
    const cos_theta = @cos(theta);
    const sin_phi = @sin(phi);
    const cos_phi = @cos(phi);

    const x = sin_theta * cos_phi * 0.5;
    const y = cos_theta * 0.5;
    const z = sin_theta * sin_phi * 0.5;

    // For a sphere centered at origin, the normal is just the normalized position
    return .{
        .pos = .{ x, y, z },
        .normal = .{ x * 2, y * 2, z * 2 }, // *2 because radius is 0.5
    };
}

pub const sphere_low = generateSphere(16, 16); // 1,536 vertices (low poly)
pub const sphere_med = generateSphere(32, 32); // 6,144 vertices (medium)
pub const sphere_high = generateSphere(64, 64); // 24,576 vertices (high poly)
