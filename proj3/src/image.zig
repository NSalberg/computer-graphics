//CSCI 5607 Header-only Image Library

const zstbi = @import("zstbi");
const std = @import("std");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;

pub const Image = struct {
    width: u32,
    height: u32,
    pixels: []Vec3,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Image {
        std.debug.assert(width > 0 or height > 0);
        return Image{
            .width = width,
            .height = height,
            .pixels = try allocator.alloc(Vec3, width * height),
        };
    }

    pub fn copy(allocator: std.mem.Allocator, image: Image) !Image {
        const new_img = Image{
            .width = image.width,
            .height = image.width,
            .pixels = try allocator.alloc(Vec3, image.width * image.height),
        };
        @memcpy(new_img.pixels, image.pixels);
        return new_img;
    }

    pub fn setPixel(self: *Image, x: u32, y: u32, c: Vec3) void {
        std.debug.assert(0 <= x and y < self.width);
        std.debug.assert(0 <= y and y < self.height);
        self.pixels[x + y * self.width] = c;
    }

    pub fn getPixel(self: *Image, x: u32, y: u32) Vec3 {
        std.debug.assert(0 <= x and y < self.width);
        std.debug.assert(0 <= y and y < self.height);
        return self.pixels[x + y * self.width];
    }

    pub fn toBytes(self: *Image, allocator: std.mem.Allocator) ![]u8 {
        const rawPixels = try allocator.alloc(u8, self.width * self.height * 4);
        for (0..self.width) |i| {
            for (0..self.height) |j| {
                const color = self.getPixel(@intCast(i), @intCast(j));
                rawPixels[4 * (i + j * self.width) + 0] = @intFromFloat(@min(color[0], 1) * 255);
                rawPixels[4 * (i + j * self.width) + 1] = @intFromFloat(@min(color[1], 1) * 255);
                rawPixels[4 * (i + j * self.width) + 2] = @intFromFloat(@min(color[2], 1) * 255);
                rawPixels[4 * (i + j * self.width) + 3] = 255; //alpha
            }
        }
        return rawPixels;
    }

    pub fn write(self: *Image, fname: [:0]const u8, allocator: std.mem.Allocator) !void {
        const raw_bytes = try self.toBytes(allocator);
        defer allocator.free(raw_bytes);

        const flen = fname.len;
        switch (fname[flen - 1]) {
            'g' => {
                var zimg: zstbi.Image = try zstbi.Image.createEmpty(self.width, self.height, 4, .{ .bytes_per_component = 4 });
                // defer zimg.deinit();
                zimg.data = raw_bytes;

                if (fname[flen - 2] == 'p' or fname[flen - 2] == 'e') {
                    try zimg.writeToFile(fname, .{ .jpg = .{ .quality = 95 } });
                } //jpeg or jpg
                else { //png
                    try zimg.writeToFile(fname, .png);
                }
            },
            else => {
                _ = zstbi.stbi_write_bmp(fname.ptr, @intCast(self.width), @intCast(self.height), 4, raw_bytes.ptr, 0);
            },
        }
    }
};
