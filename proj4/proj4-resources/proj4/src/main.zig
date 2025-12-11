const std = @import("std");
const proj4 = @import("proj4");

const gl = @import("gl");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    try proj4.main();
}
