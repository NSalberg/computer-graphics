const std = @import("std");
const c = @import("c.zig").c;
const scene = @import("scene.zig");
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;

pub const EditorState = struct {
    selected_obj_idx: ?usize = null,
};

pub fn drawObjectWindow(e_state: *EditorState, scne: scene.Scene) !void {
    //
    if (c.ImGui_Begin("Object Graph", null, 0)) {
        defer c.ImGui_End();
        {
            if (c.ImGui_BeginMenuBar()) {
                defer c.ImGui_EndMenuBar();

                if (c.ImGui_BeginMenu("File")) {
                    defer c.ImGui_EndMenu();
                    if (c.ImGui_MenuItem("Open..")) {}
                    if (c.ImGui_MenuItem("Save")) {}
                    if (c.ImGui_MenuItem("Close")) {}
                }
            }
        }
        // // Edit a color stored as 4 floats
        var my_color = Vec3.zero;
        var selected_obj: scene.Object = undefined;
        if (e_state) {
            selected_obj = scne.objects.get(e_state.selected_obj_idx);
            const mat_idx = selected_obj.materail_idx;
            my_color = scne.materials.items[mat_idx].color;
        }
        _ = c.ImGui_ColorEdit4("Color", &my_color.x, 0);

        {
            if (c.ImGui_BeginChild("Scrolling", .{ .x = 0, .y = 0 }, 0, 0)) {
                defer c.ImGui_EndChild();
                for (scne.objects.items(.name)) |name| {
                    c.ImGui_TextUnformatted(name.ptr);
                    // c.ImGui_Text("%s: Some text", &name);
                }
            }
        }
    }
}
