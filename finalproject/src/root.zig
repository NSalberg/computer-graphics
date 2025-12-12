const std = @import("std");
const gl = @import("gl");

pub const scene = @import("scene.zig");
pub const Scene = @import("scene.zig").Scene;
pub const RenderState = @import("render.zig").SceneRenderer;
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;
const editor = @import("editor.zig");

/// This holds what OpenGL needs to render the scene
// const RenderState = struct {
//     /// Vertex Array Object (VAO). Holds information on how vertex data is laid out in memory.
//     pub fn init() !void {}
// };

/// This holds everything related to the editing tools, not the scene itself.
/// Currently selected object(s)
/// Active tool (translate / rotate / scale / material brush)
/// Gizmo state (dragging axis X? rotating around Y?)
/// Camera orbit/pan state
/// Undo/redo stacks
/// Clipboard (copy/paste)
/// Pending operations (e.g., “waiting for mouse release to commit action”)
///Raw input normalized into something easy to use.
///Examples:
///Mouse position delta
///Is left mouse currently down?
///Last-clicked screen position
///Keys pressed this frame
///Scroll events
///SDL events are fed into this each frame.
///Editor reads from it; nothing writes to it except SDL event handling
const InputState = struct {};

///A centralized asset repository.
///Contents:
///  Loaded meshes
///  Loaded textures
///  Materials (organized by ID)
///  Shaders
///  Icons/UI textures for ImGui
const resources = @import("resources.zig");

const ApplicationState = struct {
    scene: Scene,
    render_state: RenderState,
    editor_state: EditorState,
    input_state: InputState,
    resources: @import("resources.zig"),
};

const imgui = @import("cimgui");
const c = @import("c.zig").c;

const SdlWinCon = struct {
    window: *c.SDL_Window,
    context: c.SDL_GLContext,
    pub fn init(procs: *gl.ProcTable) !SdlWinCon {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) {
            std.log.err("SDL Init failed : {s}", .{c.SDL_GetError()});
            return error.SDL_INIT;
        }

        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, 0);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 2);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_STENCIL_SIZE, 8);

        const window = c.SDL_CreateWindow("Renzig", 800, 600, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);
        if (window == null) {
            std.log.err("SDL create window failed : {s}", .{c.SDL_GetError()});
            return error.SDL_CREATE_WINDOW;
        }

        const context = c.SDL_GL_CreateContext(window);
        if (context == null) {
            std.log.err("SDL create context failed : {s}", .{c.SDL_GetError()});
            return error.SDL_CREATE_CONTEXT;
        }

        _ = c.SDL_GL_MakeCurrent(window, context);
        _ = c.SDL_GL_SetSwapInterval(1);

        if (!procs.init(c.SDL_GL_GetProcAddress)) return error.InitFailed;
        return .{ .context = context, .window = window.? };
    }

    pub fn deinit(self: SdlWinCon) void {
        _ = c.SDL_Quit();
        _ = c.SDL_DestroyWindow(self.window);
        _ = c.SDL_GL_DestroyContext(self.context);
    }
};

pub fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();

    var procs: gl.ProcTable = undefined;

    const GLSL_VERSION = "#version 130";

    // Initialize SDL
    const window_context = try SdlWinCon.init(&procs);
    defer window_context.deinit();
    const window = window_context.window;
    const context = window_context.context;

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    const program = try resources.createProgram();
    var scene_renderer = try RenderState.init(alloc, program);

    var scne = Scene{};
    const cube_mesh_idx = try scne.addMesh(alloc, .{
        .vertices = &resources.cube_vertices,
        .name = "cube",
    });
    const cube = scene.Object{
        .name = "cube1",
        .transform = zlm.Mat4.createTranslation(Vec3.all(0)),
        .materail_idx = try scne.addMaterial(alloc, .{ .color = Vec3{ .x = 1, .y = 0.5, .z = 0.5 } }),
        .typ = .cube,
        .mesh_idx = cube_mesh_idx,
    };

    const cube2 = scene.Object{
        .name = "cube2",
        .transform = zlm.Mat4.createTranslation(Vec3.all(-0.5)),
        .materail_idx = try scne.addMaterial(alloc, .{ .color = Vec3{ .x = 0.5, .y = 0.0, .z = 0.5 } }),
        .typ = .cube,
        .mesh_idx = cube_mesh_idx,
    };
    try scne.objects.append(alloc, cube);
    try scne.objects.append(alloc, cube2);
    try scene_renderer.loadScene(alloc, &scne);

    var e_stat = editor.EditorState{};

    _ = c.CIMGUI_CHECKVERSION();
    _ = c.ImGui_CreateContext(null);
    defer c.ImGui_DestroyContext(null);

    const imio = c.ImGui_GetIO();
    imio.*.ConfigFlags = c.ImGuiConfigFlags_NavEnableKeyboard;

    c.ImGui_StyleColorsDark(null);

    _ = c.cImGui_ImplSDL3_InitForOpenGL(window, context.?);
    defer c.cImGui_ImplSDL3_Shutdown();
    _ = c.cImGui_ImplOpenGL3_InitEx(GLSL_VERSION);
    defer c.cImGui_ImplOpenGL3_Shutdown();

    main_loop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            _ = c.cImGui_ImplSDL3_ProcessEvent(&event);
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    break :main_loop;
                },
                else => {},
            }
        }

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();

        c.ImGui_ShowDemoWindow(null);
        // ImGui::Text("Hello, world %d", 123);
        // if (ImGui::Button("Save"))
        //     MySaveFunction();
        // ImGui::InputText("string", buf, IM_ARRAYSIZE(buf));
        // ImGui::SliderFloat("float", &f, 0.0f, 1.0f);
        try editor.drawObjectWindow(scne);
        // ImGui::InputText("string", buf, IM_ARRAYSIZE(buf));
        // ImGui::SliderFloat("float", &f, 0.0f, 1.0f);

        gl.Viewport(0, 0, @intFromFloat(imio.*.DisplaySize.x), @intFromFloat(imio.*.DisplaySize.y));
        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        const io = c.ImGui_GetIO();

        if (!io.*.WantCaptureMouse) {
            if (c.ImGui_IsMouseDragging(c.ImGuiMouseButton_Right, 0.0)) {
                const delta = c.ImGui_GetMouseDragDelta(c.ImGuiMouseButton_Right, 0.0);
                scne.camera.orbit(delta.x, delta.y);
                c.ImGui_ResetMouseDragDeltaEx(c.ImGuiMouseButton_Right);
            }

            if (c.ImGui_IsMouseDragging(c.ImGuiMouseButton_Middle, 0.0)) {
                const delta = c.ImGui_GetMouseDragDelta(c.ImGuiMouseButton_Middle, 0.0);
                scne.camera.translate(delta.x, delta.y);
                std.debug.print("center {f}, target{f}\n", .{ scne.camera.center, scne.camera.target });
                c.ImGui_ResetMouseDragDeltaEx(c.ImGuiMouseButton_Middle);
            }

            // if (c.ImGui_IsMouseClicked(c.ImGuiMouseButton_Left, false)) {
            //     // The user just clicked the Scene (not a UI window)
            //     // Perform Raycast here...
            // }

            if (io.*.MouseWheel != 0.0) {
                scne.camera.zoom(io.*.MouseWheel);
            }
        }

        // scne.objects
        scene_renderer.render(scne, imio);

        c.ImGui_Render();
        c.cImGui_ImplOpenGL3_RenderDrawData(c.ImGui_GetDrawData());
        _ = c.SDL_GL_SwapWindow(window);
    }
}
