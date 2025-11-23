const std = @import("std");

const float = f32;
const math = @import("zlm").as(float);
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;

const PLAYER_HEIGHT = 0.5;

pub var map_width: usize = 0;
pub var map_height: usize = 0;
pub var game_map: std.ArrayList([]u8) = undefined;
pub var player_pos: Vec3 = undefined;
pub var goal_pos: Vec2 = undefined;
pub var keys_collected: std.AutoHashMap(u8, void) = undefined;
pub var game_won = false;

pub fn loadMap(allocator: std.mem.Allocator, file_name: []const u8) !void {
    const cur_dir = std.fs.cwd();
    var file = try cur_dir.openFile(file_name, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    game_map = try std.ArrayList([]u8).initCapacity(allocator, 0);
    keys_collected = std.AutoHashMap(u8, void).init(allocator);
    try parseMaze(allocator, &file_reader.interface);
}

pub fn parseMaze(allocator: std.mem.Allocator, reader: *std.Io.Reader) !void {
    var y: i64 = 0;
    while (reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => blk: {
            try parseLine(allocator, try reader.take(reader.end - reader.seek), y);
            break :blk null;
        },
        else => return err,
    }) |line| {
        try parseLine(allocator, line, y);
        y += 1;
    }
}
fn parseLine(allocator: std.mem.Allocator, line: []const u8, y: i64) !void {
    const trimmed_line = std.mem.trim(u8, line, &std.ascii.whitespace);
    std.debug.print("{s}\n", .{trimmed_line});
    if (y == 0) {
        var v = std.mem.splitScalar(u8, trimmed_line, ' ');
        map_width = try std.fmt.parseInt(usize, v.next().?, 10);
        map_height = try std.fmt.parseInt(usize, v.next().?, 10);
        return;
    }

    const line_copy = try std.mem.Allocator.dupe(allocator, u8, trimmed_line);
    try game_map.append(allocator, line_copy);

    for (line, 0..) |c, x| {
        switch (c) {
            'S' => {
                player_pos = Vec3.new(
                    @as(float, @floatFromInt(x)) + 0.5,
                    PLAYER_HEIGHT,
                    @as(float, @floatFromInt(y)) + 0.5,
                );
            },
            'G' => {
                goal_pos = Vec2.new(
                    @as(f32, @floatFromInt(x)) + 0.5,
                    @as(f32, @floatFromInt(y)) + 0.5,
                );
            },
            else => {},
        }
    }
}
