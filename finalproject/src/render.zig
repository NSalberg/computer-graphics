const std = @import("std");
const scene = @import("scene.zig");
const Scene = @import("scene.zig").Scene;
const assert = std.debug.assert;
const gl = @import("gl");
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;

const c = @import("c.zig").c;
// const c = @cImport({
//     @cInclude("SDL3/SDL.h");
//     @cInclude("SDL3/SDL_opengl.h");
//     @cInclude("dcimgui.h");
//     @cInclude("backends/dcimgui_impl_sdl3.h");
//     @cInclude("backends/dcimgui_impl_opengl3.h");
// });

pub const Vertex = extern struct {
    pos: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
};

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

const VerticeShits = struct {
    vao: c_uint = 0,
    vbo: c_uint = 0,
};

pub const SceneRenderer = struct {
    vertex_objs: [std.meta.fields(scene.Object).len]VerticeShits = undefined,
    program: c_uint,
    pub fn init(allocator: std.mem.Allocator, program: c_uint) !SceneRenderer {
        _ = allocator;

        var renderer = SceneRenderer{
            .vertex_objs = undefined,
            .program = program,
        };

        // Initialize each mesh type
        const fields = std.meta.fields(scene.Object);
        inline for (fields) |field| {
            if (comptime std.mem.eql(u8, field.name, "cube")) {
                renderer.vertex_objs[0] = try createCubeMesh();
            } else if (comptime std.mem.eql(u8, field.name, "sphere")) {
                // renderer.vertex_objs[i] = try createSphereMesh();
            }
        }

        return renderer;
    }

    fn createCubeMesh() !VerticeShits {
        var vao: c_uint = 0;
        var vbo: c_uint = 0;

        setupVertexBuffer(&vao, &vbo, &cube_vertices);

        return .{
            .vao = vao,
            .vbo = vbo,
        };
    }

    fn createSphereMesh() !VerticeShits {
        return error.SphereUnimpl;
    }

    pub fn render(self: SceneRenderer, scne: Scene, imio: [*c]c.ImGuiIO) void {
        gl.UseProgram(self.program);
        defer gl.UseProgram(0);

        gl.Enable(gl.DEPTH_TEST);
        defer gl.Disable(gl.DEPTH_TEST);

        const cam = Vec3.one;

        const view = zlm.Mat4.createLookAt(cam, Vec3.zero, Vec3.new(0, 1, 0));
        const aspect = imio.*.DisplaySize.x / imio.*.DisplaySize.y;
        const proj = zlm.Mat4.createPerspective(zlm.toRadians(70.0), aspect, 0.1, 100.0);

        gl.UniformMatrix4fv(gl.GetUniformLocation(self.program, "view"), 1, gl.FALSE, @ptrCast(&view.fields[0][0]));
        gl.UniformMatrix4fv(gl.GetUniformLocation(self.program, "proj"), 1, gl.FALSE, @ptrCast(&proj.fields[0][0]));

        gl.Uniform3fv(gl.GetUniformLocation(self.program, "viewPos"), 1, @ptrCast(&cam.x));
        gl.Uniform1f(gl.GetUniformLocation(self.program, "ambient"), 0.3);

        const tags = scne.objects.items(.tags);
        const data = scne.objects.items(.data);

        for (tags, data, 0..) |tag, obj_data, i| {
            switch (tag) {
                .sphere => {
                    const sphere = obj_data.sphere;
                    // Render sphere with sphere data
                    _ = sphere;
                },
                .cube => {
                    gl.BindVertexArray(self.vertex_objs[0].vao);
                    std.debug.print("cube {}\n", .{i});
                    const cube = obj_data.cube;
                    const translation = zlm.Mat4.createTranslation(cube.center);
                    gl.UniformMatrix4fv(gl.GetUniformLocation(self.program, "model"), 1, gl.FALSE, @ptrCast(&translation.fields[0][0]));

                    gl.Uniform3f(gl.GetUniformLocation(self.program, "objectColor"), 1, 0.5, 0);
                    gl.DrawArrays(gl.TRIANGLES, 0, cube_vertices.len);
                },
            }
        }
    }
};

fn setupVertexBuffer(
    vao: *c_uint,
    vbo: *c_uint,
    buffer: []const Vertex,
) void {
    assert(vao.* == 0);
    assert(vbo.* == 0);
    assert(buffer.len > 0);
    gl.GenVertexArrays(1, @ptrCast(vao));
    gl.GenBuffers(1, @ptrCast(vbo));
    gl.BindVertexArray(vao.*);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo.*);
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(buffer.len * @sizeOf(Vertex)), buffer.ptr, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "pos"));
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "normal"));
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "uv"));

    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);
    gl.EnableVertexAttribArray(2);
}
