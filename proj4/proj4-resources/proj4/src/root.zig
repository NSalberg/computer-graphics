//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

const gl = @import("gl");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

const float = f32;
const zlm = @import("zlm").as(float);
const Vec3 = zlm.Vec3;
const Vec2 = zlm.Vec2;

const maze = @import("maze.zig");
const models = @import("models.zig");

const sdl_log = std.log.scoped(.sdl);
const gl_log = std.log.scoped(.gl);

const target_triple: [:0]const u8 = x: {
    var buf: [256]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    break :x (builtin.target.zigTriple(fba.allocator()) catch unreachable) ++ "";
};

var program: c_uint = undefined;
const window_title: [*c]const u8 = "3D Maze Game";
const window_w = 1280;
const window_h = 720;
var window: *c.SDL_Window = undefined;
var gl_context: c.SDL_GLContext = undefined;
var gl_procs: gl.ProcTable = undefined;

// Player state

const PlayerState = struct {
    pos: Vec3,
    yaw: float = 0,
    pitch: float = 0,
    height: float = 0.5,
    move_speed: float = 2.5,
    rotate_speed: float = 2.0,
    mouse_sense: float = 0.002,
    radius: float = 0.2,
};

var player = PlayerState{
    .pos = undefined,
};
// float playerYaw = 0.0f; // Horizontal rotation
// float playerPitch = 0.0f;
// const float PLAYER_HEIGHT = 0.5f;
// const float PLAYER_RADIUS = 0.2f;
// const float MOVE_SPEED = 2.5f;
// const float ROTATE_SPEED = 2.0f;
// const float MOUSE_SENSITIVITY = 0.002f;

/// Vertex Array Object (VAO). Holds information on how vertex data is laid out in memory.
var wall_VAO: c_uint = 0;
var wall_VBO: c_uint = 0;
const cube_vertices = models.cube_vertices;

var floor_VAO: c_uint = 0;
var floor_VBO: c_uint = 0;
const floor_vertices = models.floor_vertices;

var key_VAO: c_uint = 0;
var key_VBO: c_uint = 0;
const key_vertices = models.key_vertices;

var uptime: std.time.Timer = undefined;

pub const Vertex = extern struct {
    pos: [3]float,
    normal: [3]float,
    uv: [2]float,
};

pub fn canMoveTo(x: float, z: float) bool {
    const gx: i64 = @intFromFloat(x);
    const gz: i64 = @intFromFloat(z);
    // std.debug.print("{}, {d}, {d}\n", .{ x < 0, x, z });
    if (x < 0.0 or gx >= maze.map_width or z < 0.0 or gz >= maze.map_height) {
        return false;
    }
    const char = maze.game_map.items[@intCast(gz)][@intCast(gx)];
    if (char == 'W')
        return false;
    if (char >= 'A' and char <= 'E') {
        const needed = char - 'A' + 'a';
        if (maze.keys_collected.contains(needed)) {
            maze.game_map.items[@intCast(gz)][@intCast(gx)] = '0';
            _ = maze.keys_collected.remove(needed);
        }
        return maze.keys_collected.contains(needed);
    }
    return true;
}

pub fn checkCollisions() !void {
    const gx: usize = @intFromFloat(player.pos.x);
    const gz: usize = @intFromFloat(player.pos.z);
    if (gx >= 0 and gx < maze.map_width and gz >= 0 and gz < maze.map_height) {
        const char = &maze.game_map.items[gz][gx];
        if (char.* >= 'a' and char.* <= 'e') {
            try maze.keys_collected.put(char.*, {});
            std.debug.print("Collected key: {c}\n", .{char.*});
            char.* = '0';
        }

        if (char.* == 'G') {
            maze.game_won = true;
            std.debug.print("Game Won!\n", .{});
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    // Skip the first arg (program name)
    _ = args.skip();

    // Get the next argument
    const filename = args.next() orelse "level1.txt";
    try maze.loadMap(alloc, filename);
    player.pos = maze.player_pos;

    std.debug.print("Map dimensions: {d}x{d}\n", .{ maze.map_width, maze.map_height });
    try initSDL();
    setupGeometry();

    gl.Enable(gl.DEPTH_TEST);

    _ = c.SDL_SetWindowRelativeMouseMode(window, true);
    var quit = false;

    var e: c.SDL_Event = undefined;
    var lastTime = c.SDL_GetTicks();

    while (!quit) {
        const now = c.SDL_GetTicks();
        const dt: f64 = @as(f64, @floatFromInt(now - lastTime)) / 1000.0;
        lastTime = now;
        while (c.SDL_PollEvent(&e)) {
            switch (e.type) {
                c.SDL_EVENT_QUIT => quit = true,
                c.SDL_EVENT_KEY_UP => if (e.key.key == c.SDLK_ESCAPE) {
                    quit = true;
                },
                c.SDL_EVENT_MOUSE_MOTION => {
                    player.yaw += e.motion.xrel * player.mouse_sense;
                },
                else => {},
            }
        }

        // std.debug.print("Player position: x={d:.2}, y={d:.2}, z={d:.2}\n", .{ player.pos.x, player.pos.y, player.pos.z });
        const keys = c.SDL_GetKeyboardState(null);

        const front = Vec3.new(@cos(player.yaw), 0, @sin(player.yaw));
        const right = Vec3.new(-front.z, 0, front.x);
        var move = Vec3.zero;

        if (keys[c.SDL_SCANCODE_W] == true or keys[c.SDL_SCANCODE_UP] == true)
            move = move.add(front);
        if (keys[c.SDL_SCANCODE_S] == true or keys[c.SDL_SCANCODE_DOWN] == true)
            move = move.sub(front);
        if (keys[c.SDL_SCANCODE_A] == true)
            move = move.sub(right);
        if (keys[c.SDL_SCANCODE_D] == true)
            move = move.add(right);

        if (move.length() > 0) {
            move = move.normalize().mul(Vec3.all(player.move_speed)).mul(Vec3.all(@as(float, @floatCast(dt))));
            const new_pos = player.pos.add(move);

            if (canMoveTo(new_pos.x + player.radius, new_pos.z) and
                canMoveTo(new_pos.x - player.radius, new_pos.z) and
                canMoveTo(new_pos.x, new_pos.z + player.radius) and
                canMoveTo(new_pos.x, new_pos.z - player.radius))
            {
                player.pos = new_pos;
            }
        }
        try checkCollisions();

        render();

        // Display the drawn content.
        try errify(c.SDL_GL_SwapWindow(window));
    }
}
fn render() void {
    const aspect: float = @as(float, @floatFromInt(window_w)) / @as(float, @floatFromInt(window_h));
    // Clear the screen to white.
    gl.ClearColor(1, 1, 1, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    gl.UseProgram(program);
    defer gl.UseProgram(0);

    const front = Vec3.new(@cos(player.yaw), 0, @sin(player.yaw));

    const view = zlm.Mat4.createLookAt(player.pos, player.pos.add(front), Vec3.new(0, 1, 0));
    const proj = zlm.Mat4.createPerspective(zlm.toRadians(70.0), aspect, 0.1, 100.0);

    gl.UniformMatrix4fv(gl.GetUniformLocation(program, "view"), 1, gl.FALSE, @ptrCast(&view.fields[0][0]));
    gl.UniformMatrix4fv(gl.GetUniformLocation(program, "proj"), 1, gl.FALSE, @ptrCast(&proj.fields[0][0]));

    gl.Uniform3fv(gl.GetUniformLocation(program, "viewPos"), 1, @ptrCast(&player.pos.x));
    // 0.5 was 2
    gl.Uniform3f(gl.GetUniformLocation(program, "lightPos"), player.pos.x, player.pos.y + 2, player.pos.z);
    gl.Uniform1f(gl.GetUniformLocation(program, "ambient"), 0.3);

    // draw floor
    {
        gl.BindVertexArray(floor_VAO);
        defer gl.BindVertexArray(0);

        gl.Uniform1f(gl.GetUniformLocation(program, "useCheckerboard"), 1.0);
        defer gl.Uniform1f(gl.GetUniformLocation(program, "useCheckerboard"), 0.0);

        gl.Uniform3f(gl.GetUniformLocation(program, "objectColor"), 0.4, 0.35, 0.3);
        for (0..maze.map_width) |x| {
            for (0..maze.map_height) |z| {
                const translation = zlm.Mat4.createTranslationXYZ(@floatFromInt(x), 0, @floatFromInt(z));
                gl.UniformMatrix4fv(gl.GetUniformLocation(program, "model"), 1, gl.FALSE, @ptrCast(&translation.fields[0][0]));
                gl.DrawArrays(gl.TRIANGLES, 0, models.floor_vertices.len);
            }
        }
    }

    // draw walls
    {
        gl.BindVertexArray(wall_VAO);
        for (0..maze.map_width) |x| {
            for (0..maze.map_height) |z| {
                const char = maze.game_map.items[z][x];

                var color: zlm.Vec3 = undefined;
                var draw = false;
                if (char == 'W') {
                    color = zlm.vec3(0.6, 0.6, 0.65);
                    draw = true;
                } else if (char >= 'A' and char <= 'E') {
                    color = maze.getDoorColor(char);
                    draw = true;
                } else if (char == 'G') {
                    color = zlm.vec3(1.0, 0.84, 0.0);
                    draw = true;
                }
                if (draw) {
                    const translation = zlm.Mat4.createTranslationXYZ(
                        @as(float, @floatFromInt(x)) + 0.5,
                        0,
                        @as(float, @floatFromInt(z)) + 0.5,
                    );
                    gl.UniformMatrix4fv(gl.GetUniformLocation(program, "model"), 1, gl.FALSE, @ptrCast(&translation.fields[0][0]));

                    gl.Uniform3f(gl.GetUniformLocation(program, "objectColor"), color.x, color.y, color.z);
                    gl.DrawArrays(gl.TRIANGLES, 0, models.cube_vertices.len);
                }
            }
        }
    }

    // Draw floating keys
    {
        gl.BindVertexArray(key_VAO);

        for (0..maze.map_width) |x| {
            for (0..maze.map_height) |z| {
                const char = maze.game_map.items[z][x];

                if (char >= 'a' and char <= 'e') {
                    const color = maze.getKeyColor(char);
                    const bob = @sin(@as(float, @floatFromInt(c.SDL_GetTicks())) / 300.0) * 0.1;
                    const translation = zlm.Mat4.createTranslationXYZ(
                        @as(float, @floatFromInt(x)) + 0.5,
                        bob + 0.3,
                        @as(float, @floatFromInt(z)) + 0.5,
                    );
                    const rotate = zlm.Mat4.createAngleAxis(
                        .{ .x = 0, .y = 1, .z = 0 },
                        @as(float, @floatFromInt(c.SDL_GetTicks())) / 500.0,
                    );
                    const scale = zlm.Mat4.createScale(0.5, 0.5, 0.5);

                    const model = scale.mul(rotate).mul(translation);

                    gl.UniformMatrix4fv(gl.GetUniformLocation(program, "model"), 1, gl.FALSE, @ptrCast(&model.fields[0][0]));
                    gl.Uniform3f(gl.GetUniformLocation(program, "objectColor"), color.x, color.y, color.z);
                    gl.DrawArrays(gl.TRIANGLES, 0, key_vertices.len);
                }
            }
        }
    }

    {
        var key_it = maze.keys_collected.keyIterator();
        var i: u16 = 0;
        while (key_it.next()) |key| {
            defer i += 1;

            const bob_offset = @as(u64, @intCast(key.*)) * 600;
            const bob = @sin(@as(float, @floatFromInt(c.SDL_GetTicks() + bob_offset)) / 300.0) * 0.01;
            const horizontal_offset = front.mul(Vec3.all(0.2));
            const offset = zlm.vec3(horizontal_offset.x, bob, horizontal_offset.z);

            const translation = zlm.Mat4.createTranslation(offset.add(player.pos));
            // std.debug.print("offset {d} {d} {d}", .{ offset.x, offset.y, offset.z });
            const rotate = zlm.Mat4.createAngleAxis(
                .{ .x = 0, .y = 1, .z = 0 },
                @as(float, @floatFromInt(c.SDL_GetTicks())) / 500.0,
            );
            const scale = zlm.Mat4.createScale(0.1, 0.1, 0.1);

            const color = maze.getKeyColor(key.*);
            const model = scale.mul(rotate).mul(translation);

            gl.UniformMatrix4fv(gl.GetUniformLocation(program, "model"), 1, gl.FALSE, @ptrCast(&model.fields[0][0]));
            gl.Uniform3f(gl.GetUniformLocation(program, "objectColor"), color.x, color.y, color.z);
            gl.DrawArrays(gl.TRIANGLES, 0, key_vertices.len);
        }
    }
}

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

fn setupGeometry() void {
    setupVertexBuffer(&wall_VAO, &wall_VBO, &cube_vertices);
    setupVertexBuffer(&floor_VAO, &floor_VBO, &floor_vertices);
    setupVertexBuffer(&key_VAO, &key_VBO, &key_vertices);
}
/// Creates shaders and initializes program.
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
        const fragment_shader_source =
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
