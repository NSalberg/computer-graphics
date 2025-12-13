const std = @import("std");
const c = @import("c.zig").c;
const scene = @import("scene.zig");
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;
const model_loader = @import("model_loader.zig");

pub const EditorState = struct {
    selected_obj_idx: ?usize = null,
    selected_obj_changed: bool = false,
    show_open_dialog: bool = false,
    show_open_dialog_changed: bool = false,
    obj_file_list: ?[][]u8 = null,
};
var inc: usize = 0;

pub fn scanForObjFile(allocator: std.mem.Allocator, dir: std.fs.Dir) ![][]u8 {
    var obj_file_list: std.ArrayList([]u8) = .empty;
    try scanRecursive(allocator, dir, &obj_file_list, "");
    return obj_file_list.toOwnedSlice(allocator);
}
fn scanRecursive(allocator: std.mem.Allocator, dir: std.fs.Dir, list: *std.ArrayList([]u8), path: []const u8) !void {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        const full_path = if (path.len > 0)
            try std.fmt.allocPrintSentinel(allocator, "{s}/{s}", .{ path, entry.name }, 0)
        else
            try allocator.dupe(u8, entry.name);

        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".obj")) {
            try list.append(allocator, full_path);
            std.debug.print("found file: {s}\n", .{full_path});
        } else if (entry.kind == .directory) {
            var sub_dir = try dir.openDir(entry.name, .{ .iterate = true });
            defer sub_dir.close();
            try scanRecursive(allocator, sub_dir, list, full_path);
            allocator.free(full_path);
        } else {
            allocator.free(full_path);
        }
    }
}

pub fn drawObjectWindow(
    allocator: std.mem.Allocator,
    e_state: *EditorState,
    scne: *scene.Scene,
) !void {
    const flags = c.ImGuiWindowFlags_MenuBar;
    const is_expanded = c.ImGui_Begin("Objects Editor", null, flags);
    defer c.ImGui_End();
    if (is_expanded) {
        const menu = c.ImGui_BeginMenuBar();
        if (menu) {
            defer c.ImGui_EndMenuBar();
            if (c.ImGui_BeginMenu("File")) {
                defer c.ImGui_EndMenu();
                if (c.ImGui_MenuItem("Open..")) {
                    e_state.show_open_dialog = true;
                    e_state.show_open_dialog_changed = true;
                }
                if (c.ImGui_MenuItem("Save")) {}
                // if (c.ImGui_MenuItem("Close")) {}
            }
        }

        if (e_state.show_open_dialog_changed) {
            c.ImGui_OpenPopup("Select OBJ File", 0);
            std.debug.print("Open file: \n", .{});

            var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch |err| {
                c.ImGui_Text("Error opening dir!");
                return err;
            };
            defer dir.close();
            var arena = std.heap.ArenaAllocator.init(allocator);
            e_state.obj_file_list = try scanForObjFile(arena.allocator(), dir);
            e_state.show_open_dialog_changed = false;
        }

        // Always center the modal
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

                // if (num_objs == 0) {
                //     c.ImGui_Text("No .obj files found in directory: ");
                // }

                if (e_state.obj_file_list) |file_list| {
                    if (file_list.len == 0) {
                        c.ImGui_TextDisabled("No .obj files found in this folder.");
                    }
                    for (file_list) |file| {
                        if (c.ImGui_Selectable(file.ptr)) {
                            std.debug.print("Selected file: {s}\n", .{file});

                            // TODO: Call load function here
                            // model_loader.loadObjFile(
                            //     entry.name,
                            //     scne,
                            // );

                            e_state.show_open_dialog = false;
                        }
                    }
                }
            }

            if (c.ImGui_Button("Cancel")) {
                e_state.show_open_dialog = false;
            }
        }
        // Edit a color stored as 4 floats

        var zero = Vec3.zero;
        var my_color_ptr: *Vec3 = &zero;
        var selected_obj: scene.Object = undefined;
        if (e_state.selected_obj_idx) |obj_idx| {
            selected_obj = scne.objects.get(obj_idx);
            const mat_idx = selected_obj.materail_idx;
            my_color_ptr = &scne.materials.items[mat_idx].color;
        }

        _ = c.ImGui_ColorEdit3("Color", &my_color_ptr.x, 0);
        {
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
    }
}
