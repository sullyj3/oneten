const std = @import("std");
const lib = @import("oneten_lib");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const sleep = std.time.sleep;
const ns_per_s = std.time.ns_per_s;

fn draw_square(x: c_int, y: c_int, side: c_int, color: ray.Color) void {
    ray.DrawRectangle(x, y, side, side, color);
}

const CELL_SIDE = 50;
const CELL_GAP = 7;
const CELL_BORDER_WIDTH = 5;

fn draw_cell(on: bool, x: c_int, y: c_int) void {
    draw_square(x, y, 50, ray.VIOLET);
    if (!on) {
        draw_square(
            x + CELL_BORDER_WIDTH,
            y + CELL_BORDER_WIDTH,
            CELL_SIDE - 2 * CELL_BORDER_WIDTH,
            ray.RAYWHITE,
        );
    }
}

fn draw_cell_row(cell_states: []bool, x: c_int, y: c_int) void {
    var x_offs: c_int = 0;
    for (cell_states) |cell| {
        draw_cell(cell, x + x_offs, y);
        x_offs += CELL_SIDE + CELL_GAP;
    }
}

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator.init(.{}){};
    // const alloc = gpa.alloc();

    const title = "oneten";
    ray.InitWindow(1080, 720, title);
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var cells: [10]bool = undefined;
    var toggle: bool = true;
    inline for (0..cells.len) |i| {
        cells[i] = toggle;
        toggle = !toggle;
    }

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        // draw_cell(true, 200, 200);
        // draw_cell(false, 200 + CELL_SIDE + CELL_GAP, 200);
        draw_cell_row(cells[0..], 150, 300);
        ray.EndDrawing();

        if (ray.IsKeyPressed(ray.KEY_ESCAPE)) {
            std.debug.print("esc pressed", .{});
            break;
        }
    }
}
