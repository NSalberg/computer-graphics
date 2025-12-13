const std = @import("std");
const c = @import("c.zig").c;
const scene = @import("scene.zig");
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;
const model_loader = @import("model_loader.zig");
const render = @import("render.zig");

pub const EditorState = struct {
    selected_obj_idx: ?usize = null,
    selected_obj_changed: bool = false,
    selected_mesh_idx: ?usize = null,
    selected_mesh_changed: bool = false,
    show_open_dialog: bool = false,
    show_open_dialog_changed: bool = false,
    obj_file_list: ?[][]u8 = null,
};

pub fn scanForObjFile(allocator: std.mem.Allocator, dir: std.fs.Dir) ![][]u8 {
    var obj_file_list: std.ArrayList([]u8) = .empty;
    var path_buf = std.mem.zeroes([std.fs.max_path_bytes]u8);
    var path_list = std.ArrayList(u8).initBuffer(&path_buf);
    try scanRecursive(allocator, dir, &obj_file_list, &path_list);
    return obj_file_list.toOwnedSlice(allocator);
}

fn scanRecursive(
    allocator: std.mem.Allocator,
    dir: std.fs.Dir,
    list: *std.ArrayList([]u8),
    path: *std.ArrayList(u8),
) !void {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        const old_len = path.items.len;
        defer path.items.len = old_len;

        if (old_len != 0) path.appendAssumeCapacity('/');
        try path.appendSlice(allocator, entry.name);

        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".obj")) {
            try list.append(allocator, try allocator.dupe(u8, path.items));
        } else if (entry.kind == .directory) {
            var sub = try dir.openDir(entry.name, .{ .iterate = true });
            defer sub.close();
            try scanRecursive(allocator, sub, list, path);
        }
    }
}

var float_f: f32 = 0.0;
pub fn drawObjectWindow(
    allocator: std.mem.Allocator,
    e_state: *EditorState,
    scne: *scene.Scene,
    renderer: *render.SceneRenderer,
) !void {
    _ = allocator;
    _ = renderer;
    const flags = c.ImGuiWindowFlags_MenuBar;
    const is_expanded = c.ImGui_Begin("Objects Editor", null, flags);
    defer c.ImGui_End();
    if (is_expanded) {
        const menu = c.ImGui_BeginMenuBar();
        if (menu) {
            defer c.ImGui_EndMenuBar();
            if (c.ImGui_BeginMenu("File")) {
                defer c.ImGui_EndMenu();
                if (c.ImGui_MenuItem("Save")) {}
            }
        }

        var zero = Vec3.zero;
        var my_color_ptr: *Vec3 = &zero;
        var selected_obj: scene.Object = undefined;
        if (e_state.selected_obj_idx) |obj_idx| {
            selected_obj = scne.objects.get(obj_idx);
            const mat_idx = selected_obj.materail_idx;
            my_color_ptr = &scne.materials.items[mat_idx].color;

            const drag_speed = 0.001;
            var translation = extractTranslation(selected_obj.transform);

            if (c.ImGui_DragFloat3Ex("Translation (x, y, z)", &translation.x, drag_speed, -std.math.floatMax(f32), std.math.floatMax(f32), "%.3f", 0)) {
                selected_obj.transform.fields[3][0] = translation.x;
                selected_obj.transform.fields[3][1] = translation.y;
                selected_obj.transform.fields[3][2] = translation.z;
                scne.objects.set(obj_idx, selected_obj);
            }

            // Scale
            var scale = extractScale(selected_obj.transform);
            if (c.ImGui_DragFloat3Ex("Scale (x, y, z)", &scale.x, drag_speed, 0.0000001, 1000.0, "%.3f", 0)) {
                applyScale(&selected_obj.transform, scale);
                scne.objects.set(obj_idx, selected_obj);
            }
        }

        // pub extern fn ImGui_DragFloatEx(label: [*c]const u8, v: [*c]f32, v_speed: f32, v_min: f32, v_max: f32, format: [*c]const u8, flags: ImGuiSliderFlags) bool;

        _ = c.ImGui_ColorEdit3("Color", &my_color_ptr.x, 0);

        drawScrollingObjWindow(e_state, scne, flags);
    }
}

fn vec3FromSlice(s: []const f32) Vec3 {
    std.debug.assert(s.len >= 3);
    return .{ .x = s[0], .y = s[1], .z = s[2] };
}

pub fn applyScale(transform: *zlm.Mat4, scale: Vec3) void {
    const x = vec3FromSlice(&transform.fields[0]).normalize().mul(Vec3.all(scale.x));
    const y = vec3FromSlice(&transform.fields[1]).normalize().mul(Vec3.all(scale.y));
    const z = vec3FromSlice(&transform.fields[2]).normalize().mul(Vec3.all(scale.z));

    transform.fields[0][0] = x.x;
    transform.fields[0][1] = x.y;
    transform.fields[0][2] = x.z;

    transform.fields[1][0] = y.x;
    transform.fields[1][1] = y.y;
    transform.fields[1][2] = y.z;

    transform.fields[2][0] = z.x;
    transform.fields[2][1] = z.y;
    transform.fields[2][2] = z.z;
}

pub fn extractScale(transform: zlm.Mat4) Vec3 {
    const x_axis = zlm.Vec3.new(
        transform.fields[0][0],
        transform.fields[0][1],
        transform.fields[0][2],
    );
    const y_axis = zlm.Vec3.new(
        transform.fields[1][0],
        transform.fields[1][1],
        transform.fields[1][2],
    );
    const z_axis = zlm.Vec3.new(
        transform.fields[2][0],
        transform.fields[2][1],
        transform.fields[2][2],
    );

    return Vec3.new(
        x_axis.length(),
        y_axis.length(),
        z_axis.length(),
    );
}
pub fn extractTranslation(transform: zlm.Mat4) zlm.Vec3 {
    return zlm.Vec3.new(
        transform.fields[3][0],
        transform.fields[3][1],
        transform.fields[3][2],
    );
}

pub fn drawScrollingObjWindow(e_state: *EditorState, scne: *const scene.Scene, flags: c_int) void {
    const child_begin = c.ImGui_BeginChild("Scrolling", .{ .x = 0, .y = 0 }, 0, flags);
    defer c.ImGui_EndChild();
    if (child_begin) {
        for (scne.objects.items(.name), 0..) |name, i| {
            c.ImGui_PushIDInt(@intCast(i));
            defer c.ImGui_PopID();
            var is_selected = if (e_state.selected_obj_idx) |idx| idx == i else false;
            if (c.ImGui_SelectableBoolPtrEx(name.ptr, &is_selected, 0, .{ .x = 0, .y = 0 })) {
                e_state.selected_obj_idx = i;
                e_state.selected_obj_changed = true;
            }
        }
    }
}

pub fn drawFileSelectPopup(
    allocator: std.mem.Allocator,
    e_state: *EditorState,
    scne: *scene.Scene,
    renderer: *render.SceneRenderer,
) !void {
    if (e_state.show_open_dialog_changed) {
        c.ImGui_OpenPopup("Select OBJ File", 0);
        std.debug.print("Open file: \n", .{});

        var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch |err| {
            c.ImGui_Text("Error opening dir!");
            return err;
        };
        defer dir.close();
        e_state.obj_file_list = try scanForObjFile(allocator, dir);
        e_state.show_open_dialog_changed = false;
    }

    const center = c.ImGuiViewport_GetCenter(c.ImGui_GetMainViewport());
    c.ImGui_SetNextWindowPos(center, c.ImGuiCond_Appearing);

    if (c.ImGui_BeginPopupModal("Select OBJ File", &e_state.show_open_dialog, 0)) {
        defer c.ImGui_EndPopup();

        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const real_path = try std.fs.cwd().realpath(".", &buf);

        var buf2: [std.fs.max_path_bytes]u8 = undefined;
        const gui_text = try std.fmt.bufPrintZ(&buf2, "Current Directory: {s}", .{real_path});
        c.ImGui_Text(gui_text);
        c.ImGui_Separator();

        if (c.ImGui_BeginChild("FileList", .{ .x = 400, .y = 200 }, 0, 0)) {
            defer c.ImGui_EndChild();

            if (e_state.obj_file_list) |file_list| {
                if (file_list.len == 0) {
                    c.ImGui_TextDisabled("No .obj files found in this folder.");
                }
                for (file_list) |file| {
                    if (c.ImGui_Selectable(file.ptr)) {
                        std.debug.print("Selected file: {s}\n", .{file});

                        const dir = std.fs.cwd();
                        const obj_idx = try model_loader.loadObjFile(
                            allocator,
                            dir,
                            file,
                            scne,
                            renderer,
                        );
                        std.debug.print("obj_idx: {}", .{obj_idx});

                        e_state.show_open_dialog = false;
                    }
                }
            }
        }

        if (c.ImGui_Button("Cancel")) {
            e_state.show_open_dialog = false;
        }
    }
}

pub fn drawMeshWindow(
    allocator: std.mem.Allocator,
    e_state: *EditorState,
    scne: *scene.Scene,
    // renderer: *render.SceneRenderer,
) !void {
    const flags = c.ImGuiWindowFlags_MenuBar;
    const is_expanded = c.ImGui_Begin("Mesh Editor", null, flags);
    defer c.ImGui_End();
    if (is_expanded) {
        const menu = c.ImGui_BeginMenuBar();
        if (menu) {
            defer c.ImGui_EndMenuBar();
            if (c.ImGui_BeginMenu("File")) {
                defer c.ImGui_EndMenu();
                if (c.ImGui_MenuItem("Add Mesh..")) {
                    e_state.show_open_dialog = true;
                    e_state.show_open_dialog_changed = true;
                }
                if (c.ImGui_MenuItem("Save")) {}
            }
        }
    }

    {
        const child_begin = c.ImGui_BeginChild("Scrolling", .{ .x = 0, .y = -35 }, 0, flags);
        defer c.ImGui_EndChild();
        if (child_begin) {
            for (scne.meshes.items, 0..) |mesh, i| {
                c.ImGui_PushIDInt(@intCast(i));
                defer c.ImGui_PopID();
                var is_selected = if (e_state.selected_mesh_idx) |idx| idx == i else false;
                if (c.ImGui_SelectableBoolPtrEx(mesh.name.ptr, &is_selected, 0, .{ .x = 0, .y = 0 })) {
                    e_state.selected_mesh_idx = i;
                    e_state.selected_mesh_changed = true;
                }
            }
        }
    }

    if (e_state.selected_mesh_idx) |mesh_idx| {
        if (c.ImGui_Button("Add")) {
            const mesh_name = scne.meshes.items[mesh_idx].name;
            const mat_idx = try scne.addMaterial(allocator, .{ .color = .{
                .x = 0.9,
                .y = 0.3,
                .z = 0.3,
            } });
            const new_obj = scene.Object{
                .materail_idx = mat_idx,
                .mesh_idx = mesh_idx,
                .name = try std.fmt.allocPrint(allocator, "{s}{}", .{ mesh_name, scne.objects.len + 1 }),
                .typ = .mesh,
                .transform = zlm.Mat4.createTranslation(Vec3.zero),
            };

            _ = try scne.addObject(allocator, new_obj);
        }
    }
}
