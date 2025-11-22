//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

const maze = @import("maze.zig");

const sdl_log = std.log.scoped(.sdl);
const gl_log = std.log.scoped(.gl);

const target_triple: [:0]const u8 = x: {
    var buf: [256]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    break :x (builtin.target.zigTriple(fba.allocator()) catch unreachable) ++ "";
};

var program: c_uint = undefined;
const window_title: [*c]const u8 = "3D Maze Game";
const window_w = 640;
const window_h = 480;
var window: *c.SDL_Window = undefined;
var renderer: *c.SDL_Renderer = undefined;
var gl_context: c.SDL_GLContext = undefined;
var gl_procs: gl.ProcTable = undefined;

/// Vertex Array Object (VAO). Holds information on how vertex data is laid out in memory.
/// Using VAOs is strictly required in modern OpenGL.
var vao: c_uint = undefined;

/// Vertex Buffer Object (VBO). Holds vertex data.
var vbo: c_uint = undefined;

var framebuffer_size_uniform: c_int = undefined;
var angle_uniform: c_int = undefined;
/// Index Buffer Object (IBO). Maps indices to vertices, to enable reusing vertex data.
var ibo: c_uint = undefined;

var uptime: std.time.Timer = undefined;

const Vertex = extern struct {
    pos: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
};

const cube_vertices = [36]Vertex{
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

// const hexagon_mesh = struct {
//     // zig fmt: off
//     const vertices = [_]Vertex{
//         .{ .position = .{  0,                        -1   }, .color = .{ 0, 1, 1 } },
//         .{ .position = .{ -(@sqrt(@as(f32, 3)) / 2), -0.5 }, .color = .{ 0, 0, 1 } },
//         .{ .position = .{  (@sqrt(@as(f32, 3)) / 2), -0.5 }, .color = .{ 0, 1, 0 } },
//         .{ .position = .{ -(@sqrt(@as(f32, 3)) / 2),  0.5 }, .color = .{ 1, 0, 1 } },
//         .{ .position = .{  (@sqrt(@as(f32, 3)) / 2),  0.5 }, .color = .{ 1, 1, 0 } },
//         .{ .position = .{  0,                         1   }, .color = .{ 1, 0, 0 } },
//     };
//     // zig fmt: on
//
//     const indices = [_]u8{
//         0, 3, 1,
//         0, 4, 3,
//         0, 2, 4,
//         3, 4, 5,
//     };
//
//     const Vertex = extern struct {
//         position: [2]f32,
//         color: [3]f32,
//     };
// };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();

    try maze.loadMap(alloc, "level1.txt");
    try initSDL();
    var quit = false;

    var e: c.SDL_Event = undefined;
    // var lastTime = c.SDL_GetTicks();
    while (!quit) {
        while (c.SDL_PollEvent(&e)) {
            switch (e.type) {
                c.SDL_EVENT_QUIT => quit = true,
                c.SDL_EVENT_KEY_UP => if (e.key.key == c.SDLK_ESCAPE) {
                    quit = true;
                },
                c.SDL_EVENT_MOUSE_MOTION => {

                    //   playerYaw += e.motion.xrel * MOUSE_SENSITIVITY;
                },
                else => {},
            }

            // if (e.type == SDL_EVENT_MOUSE_MOTION) {
            //   playerYaw += e.motion.xrel * MOUSE_SENSITIVITY;
            // }
        }
        // const now = c.SDL_GetTicks();
        // const dt: f64 = @as(f64, @floatFromInt(now - lastTime)) / 1000.0;
        // lastTime = now;
        {
            // Clear the screen to white.
            gl.ClearColor(1, 1, 1, 1);
            gl.Clear(gl.COLOR_BUFFER_BIT);

            gl.UseProgram(program);
            defer gl.UseProgram(0);

            // Make sure any changes to the window size are reflected by the framebuffer size uniform.
            var fb_width: c_int = undefined;
            var fb_height: c_int = undefined;
            try errify(c.SDL_GetWindowSizeInPixels(window, &fb_width, &fb_height));
            gl.Viewport(0, 0, fb_width, fb_height);
            gl.Uniform2f(framebuffer_size_uniform, @floatFromInt(fb_width), @floatFromInt(fb_height));

            // Rotate the hexagon clockwise at a rate of one complete revolution per minute.
            const seconds = @as(f32, @floatFromInt(uptime.read())) / std.time.ns_per_s;
            gl.Uniform1f(angle_uniform, seconds / 60 * -std.math.tau);

            gl.BindVertexArray(vao);
            defer gl.BindVertexArray(0);

            // Draw the hexagon!
            gl.DrawElements(gl.TRIANGLES, hexagon_mesh.indices.len, gl.UNSIGNED_BYTE, 0);
        }

        // Display the drawn content.
        try errify(c.SDL_GL_SwapWindow(window));
    }
}

fn initSDL() !void {
    var success: c_int = undefined;
    var info_log_buf: [512:0]u8 = undefined;

    std.log.debug("{s} {s}", .{ target_triple, @tagName(builtin.mode) });
    const platform: [*:0]const u8 = c.SDL_GetPlatform();

    sdl_log.debug("SDL platform: {s}", .{platform});
    sdl_log.debug("SDL build time version: {d}.{d}.{d}", .{
        c.SDL_MAJOR_VERSION,
        c.SDL_MINOR_VERSION,
        c.SDL_MICRO_VERSION,
    });
    sdl_log.debug("SDL build time revision: {s}", .{c.SDL_REVISION});
    {
        const version = c.SDL_GetVersion();
        sdl_log.debug("SDL runtime version: {d}.{d}.{d}", .{
            c.SDL_VERSIONNUM_MAJOR(version),
            c.SDL_VERSIONNUM_MINOR(version),
            c.SDL_VERSIONNUM_MICRO(version),
        });
        const revision: [*:0]const u8 = c.SDL_GetRevision();
        sdl_log.debug("SDL runtime revision: {s}", .{revision});
    }

    // setup gl
    {
        try errify(c.SDL_Init(c.SDL_INIT_VIDEO));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 2));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE));
        window = try errify(c.SDL_CreateWindow(window_title, window_w, window_h, c.SDL_WINDOW_OPENGL));
        gl_context = try errify(c.SDL_GL_CreateContext(window));
        if (!gl_procs.init(&c.SDL_GL_GetProcAddress)) return error.GlInitFailed;

        gl.makeProcTableCurrent(&gl_procs);
        errdefer gl.makeProcTableCurrent(null);

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
        const vertex_shader_source =
            \\// Width/height of the framebuffer
            \\uniform vec2 u_FramebufferSize;
            \\
            \\// Amount (in radians) to rotate the object
            \\uniform float u_Angle;
            \\
            \\// Vertex attributes
            \\in vec4 a_Position;
            \\in vec4 a_Color;
            \\
            \\// Color output to pass to fragment shader
            \\out vec4 v_Color;
            \\
            \\void main() {
            \\    // Scale the object to fit the framebuffer while maintaining its aspect ratio.
            \\    vec2 scale = min(u_FramebufferSize.yx / u_FramebufferSize.xy, vec2(1));
            \\
            \\    // Shrink the object slightly to fit the framebuffer even when rotated.
            \\    scale *= 0.875;
            \\
            \\    float s = sin(u_Angle);
            \\    float c = cos(u_Angle);
            \\
            \\    gl_Position = vec4(
            \\        (a_Position.x * c + a_Position.y * -s) * scale.x,
            \\        (a_Position.x * s + a_Position.y * c) * scale.y,
            \\        a_Position.zw
            \\    );
            \\
            \\    v_Color = a_Color;
            \\}
            \\
        ;

        _ =
            \\in vec3 position;
            \\in vec3 inNormal;
            \\in vec2 inTexCoord;
            \\out vec3 fragPos;
            \\out vec3 normal;
            \\out vec2 texCoord;
            \\out vec3 vertColor;
            \\uniform mat4 model;
            \\uniform mat4 view;
            \\uniform mat4 proj;
            \\uniform vec3 objectColor;
            \\void main() {
            \\    fragPos = vec3(model * vec4(position, 1.0));
            \\    normal = mat3(transpose(inverse(model))) * inNormal;
            \\    texCoord = inTexCoord;
            \\    vertColor = objectColor;
            \\    gl_Position = proj * view * model * vec4(position, 1.0);
            \\ }
            \\
        ;
        _ =
            \\in vec3 fragPos;
            \\in vec3 normal;
            \\in vec2 texCoord;
            \\in vec3 vertColor;
            \\out vec4 outColor;
            \\uniform vec3 lightPos;
            \\uniform vec3 viewPos;
            \\uniform float ambient;
            \\uniform float useCheckerboard;
            \\void main() {
            \\    vec3 color = vertColor;
            \\    // Checkerboard pattern for floor
            \\    if (useCheckerboard > 0.5) {
            \\        float scale = 2.0;
            \\        int cx = int(floor(texCoord.x * scale));
            \\        int cy = int(floor(texCoord.y * scale));
            \\        if ((cx + cy) % 2 == 0) color *= 0.7;
            \\    }
            \\    // Ambient
            \\    vec3 ambientLight = ambient * color;
            \\    // Diffuse
            \\    vec3 norm = normalize(normal);
            \\    vec3 lightDir = normalize(lightPos - fragPos);
            \\    float diff = max(dot(norm, lightDir), 0.0);
            \\    vec3 diffuse = diff * color;
            \\    // Specular
            \\    vec3 viewDir = normalize(viewPos - fragPos);
            \\    vec3 reflectDir = reflect(-lightDir, norm);
            \\    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
            \\    vec3 specular = 0.3 * spec * vec3(1.0);
            \\    outColor = vec4(ambientLight + diffuse + specular, 1.0);
            \\}
        ;
        const fragment_shader_source =
            \\// OpenGL ES default precision statements
            \\precision highp float;
            \\precision highp int;
            \\
            \\// Color input from the vertex shader
            \\in vec4 v_Color;
            \\
            \\// Final color output
            \\out vec4 f_Color;
            \\
            \\void main() {
            \\    f_Color = v_Color;
            \\}
            \\
        ;

        program = gl.CreateProgram();
        if (program == 0) return error.GlCreateProgramFailed;
        errdefer gl.DeleteProgram(program);

        const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
        gl.ShaderSource(vertex_shader, 2, &.{ shader_version, vertex_shader_source }, null);
        gl.CompileShader(vertex_shader);
        gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, (&success)[0..1]);
        if (success == gl.FALSE) {
            gl.GetShaderInfoLog(vertex_shader, info_log_buf.len, null, &info_log_buf);
            gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
            return error.GlCompileVertexShaderFailed;
        }

        const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
        if (fragment_shader == 0) return error.GlCreateFragmentShaderFailed;
        defer gl.DeleteShader(fragment_shader);

        gl.ShaderSource(
            fragment_shader,
            2,
            &.{ shader_version, fragment_shader_source },
            &.{ shader_version.len, fragment_shader_source.len },
        );
        gl.CompileShader(fragment_shader);
        gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, (&success)[0..1]);
        if (success == gl.FALSE) {
            gl.GetShaderInfoLog(fragment_shader, info_log_buf.len, null, &info_log_buf);
            gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
            return error.GlCompileFragmentShaderFailed;
        }

        gl.AttachShader(program, vertex_shader);
        gl.AttachShader(program, fragment_shader);

        gl.LinkProgram(program);
        gl.GetProgramiv(program, gl.LINK_STATUS, (&success)[0..1]);
        if (success == gl.FALSE) {
            gl.GetProgramInfoLog(program, info_log_buf.len, null, &info_log_buf);
            gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
            return error.LinkProgramFailed;
        }
    }

    framebuffer_size_uniform = gl.GetUniformLocation(program, "u_FramebufferSize");
    angle_uniform = gl.GetUniformLocation(program, "u_Angle");

    // Gen
    {
        gl.GenVertexArrays(1, (&vao)[0..1]);
        errdefer gl.DeleteVertexArrays(1, (&vao)[0..1]);

        gl.GenBuffers(1, (&vbo)[0..1]);
        errdefer gl.DeleteBuffers(1, (&vbo)[0..1]);

        gl.GenBuffers(1, (&ibo)[0..1]);
        errdefer gl.DeleteBuffers(1, (&ibo)[0..1]);
    }
    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    gl.BufferData(
        gl.ARRAY_BUFFER,
        @sizeOf(@TypeOf(hexagon_mesh.vertices)),
        &hexagon_mesh.vertices,
        gl.STATIC_DRAW,
    );

    const position_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Position"));
    gl.EnableVertexAttribArray(position_attrib);
    gl.VertexAttribPointer(
        position_attrib,
        @typeInfo(@FieldType(hexagon_mesh.Vertex, "position")).array.len,
        gl.FLOAT,
        gl.FALSE,
        @sizeOf(hexagon_mesh.Vertex),
        @offsetOf(hexagon_mesh.Vertex, "position"),
    );

    const color_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Color"));
    gl.EnableVertexAttribArray(color_attrib);
    gl.VertexAttribPointer(
        color_attrib,
        @typeInfo(@FieldType(hexagon_mesh.Vertex, "color")).array.len,
        gl.FLOAT,
        gl.FALSE,
        @sizeOf(hexagon_mesh.Vertex),
        @offsetOf(hexagon_mesh.Vertex, "color"),
    );

    // Instruct the VAO to use our IBO, then upload index data to the IBO.
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.BufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @sizeOf(@TypeOf(hexagon_mesh.indices)),
        &hexagon_mesh.indices,
        gl.STATIC_DRAW,
    );

    uptime = try .start();
}

/// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
