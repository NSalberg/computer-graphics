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

const VerticeShits = struct {
    vao: c_uint = 0,
    vbo: c_uint = 0,
};

pub const GPUMesh = struct {
    vao: c_uint,
    vbo: c_uint,
    vertex_count: usize,

    /// Clean up GL resources
    pub fn deinit(self: GPUMesh) void {
        gl.DeleteVertexArrays(1, &self.vao);
        gl.DeleteBuffers(1, &self.vbo);
    }
};

pub const SceneRenderer = struct {
    meshes: std.ArrayList(GPUMesh) = .empty,
    program: c_uint,
    pub fn init(allocator: std.mem.Allocator, program: c_uint) !SceneRenderer {
        _ = allocator;
        // const meshes: std.ArrayList(GPUMesh) = .empty;

        const renderer = SceneRenderer{
            .program = program,
        };

        return renderer;
    }
    pub fn loadScene(self: *SceneRenderer, allocator: std.mem.Allocator, scne: *const Scene) !void {
        for (scne.meshes.items) |cpu_mesh| {
            const gpu_mesh = createMesh(cpu_mesh.vertices);
            try self.meshes.append(allocator, gpu_mesh);
        }
    }

    pub fn addMesh(self: *SceneRenderer, allocator: std.mem.Allocator, cpu_mesh: scene.CpuMesh) void {
        const gpu_mesh = createMesh(cpu_mesh.vertices);
        try self.meshes.append(allocator, gpu_mesh);
    }

    pub fn render(self: SceneRenderer, scne: Scene, imio: [*c]c.ImGuiIO) void {
        gl.UseProgram(self.program);
        defer gl.UseProgram(0);

        gl.Enable(gl.DEPTH_TEST);
        defer gl.Disable(gl.DEPTH_TEST);

        const cam = scne.camera;

        const view = zlm.Mat4.createLookAt(cam.center, cam.target, Vec3.new(0, 1, 0));
        const aspect = imio.*.DisplaySize.x / imio.*.DisplaySize.y;
        const proj = zlm.Mat4.createPerspective(zlm.toRadians(70.0), aspect, 0.1, 100.0);

        gl.UniformMatrix4fv(gl.GetUniformLocation(self.program, "view"), 1, gl.FALSE, @ptrCast(&view.fields[0][0]));
        gl.UniformMatrix4fv(gl.GetUniformLocation(self.program, "proj"), 1, gl.FALSE, @ptrCast(&proj.fields[0][0]));

        gl.Uniform3fv(gl.GetUniformLocation(self.program, "viewPos"), 1, @ptrCast(&cam.center.x));
        gl.Uniform1f(gl.GetUniformLocation(self.program, "ambient"), 0.3);

        const slc = scne.objects.slice();
        for (slc.items(.transform), slc.items(.typ), slc.items(.mesh_idx), slc.items(.materail_idx)) |transform, typ, mesh_idx, mat_idx| {
            const gpu_mesh = self.meshes.items[mesh_idx];
            const color = scne.materials.items[mat_idx].color;

            gl.BindVertexArray(gpu_mesh.vao);
            gl.UniformMatrix4fv(gl.GetUniformLocation(self.program, "model"), 1, gl.FALSE, @ptrCast(&transform.fields[0][0]));
            gl.Uniform3fv(gl.GetUniformLocation(self.program, "objectColor"), 1, @ptrCast(&color.x));
            gl.DrawArrays(gl.TRIANGLES, 0, @intCast(gpu_mesh.vertex_count));
            _ = typ;

            // switch (typ) {
            //     .cube => {},
            //     .sphere => {},
            //     .mesh => {},
            // }
        }
    }
};

fn createMesh(
    vertices: []const Vertex,
) GPUMesh {
    var vao: c_uint = 0;
    var vbo: c_uint = 0;
    assert(vertices.len > 0);
    gl.GenVertexArrays(1, @ptrCast(&vao));
    gl.GenBuffers(1, @ptrCast(&vbo));
    gl.BindVertexArray(vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(vertices.len * @sizeOf(Vertex)), vertices.ptr, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "pos"));
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "normal"));
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "uv"));

    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);
    gl.EnableVertexAttribArray(2);

    return GPUMesh{
        .vao = vao,
        .vbo = vbo,
        .vertex_count = vertices.len,
    };
}
