const std = @import("std");
const lib = @import("oneten_lib");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const sleep = std.time.sleep;
const ns_per_s = std.time.ns_per_s;

pub fn main() !void {
    const title = "oneten";
    ray.InitWindow(1080, 720, title);
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    ray.BeginDrawing();
    ray.EndDrawing();
    sleep(5 * ns_per_s);
}
