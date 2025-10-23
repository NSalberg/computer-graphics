const std = @import("std");
const project_3a = @import("project_3a");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const assert = std.debug.assert;
const scene = @import("scene.zig");
const c = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_image_write.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();
    var args = try std.process.argsWithAllocator(alloc);
    _ = args.skip();

    const file_name = args.next();
    if (file_name == null) {
        std.debug.print("Please provide a file argument", .{});
    }

    const cur_dir = std.fs.cwd();
    std.debug.print("{s}\n", .{file_name.?});
    var file = try cur_dir.openFile(file_name.?, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const scene_ = try scene.parseSceneFile(alloc, &file_reader.interface);
    std.debug.print("{f}\n", .{scene_});

    // Image outputImg = Image(img_width,img_height);
    // auto t_start = std::chrono::high_resolution_clock::now();
    // for (int i = 0; i < img_width; i++){
    //   for (int j = 0; j < img_height; j++){
    //     //TODO - Understand: In what way does this assumes the basis is orthonormal?
    //     float u = (halfW - (imgW)*((i+0.5)/imgW));
    //     float v = (halfH - (imgH)*((j+0.5)/imgH));
    //     vec3 p = eye - d*forward + u*right + v*up;
    //     vec3 rayDir = (p - eye).normalized();  //Normalizing here is optional
    //     bool hit = raySphereIntersect(eye,rayDir,spherePos,sphereRadius);
    //     Color color;
    //     if (hit) color = Color(1,1,1);
    //     else color = Color(0,0,0);
    //     outputImg.setPixel(i,j, color);
    //     //outputImg.setPixel(i,j, Color(fabs(i/imgW),fabs(j/imgH),fabs(0))); //TODO - Understand: Try this, what is it visualizing?
    //   }
    // }
    // auto t_end = std::chrono::high_resolution_clock::now();
    // printf("Rendering took %.2f ms\n",std::chrono::duration<double, std::milli>(t_end-t_start).count());
    //
    // outputImg.write(imgName.c_str());
}
