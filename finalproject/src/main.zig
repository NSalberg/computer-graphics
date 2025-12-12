const std = @import("std");
const finalproject = @import("finalproject");
const gl = @import("gl");
const zlm = @import("zlm").as(f32);
const Vec3 = zlm.Vec3;
const scene = finalproject.scene;

pub fn main() !void {
    try finalproject.run();
}
