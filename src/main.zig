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
const CELL_GAP = 3;
const CELL_BORDER_WIDTH = 2;

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

fn cells_draw_width(n_cells: c_int) c_int {
    return n_cells * CELL_SIDE + (n_cells - 1) * CELL_GAP;
}

fn top_left_from_center(
    cx: c_int,
    cy: c_int,
    width: c_int,
    height: c_int,
) struct { c_int, c_int } {
    return .{
        cx - @divTrunc(width, 2),
        cy - @divTrunc(height, 2),
    };
}

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator.init(.{}){};
    // const alloc = gpa.alloc();
    const win_width = 1080;
    const win_height = 720;

    const title = "oneten";
    ray.InitWindow(win_width, win_height, title);
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var cells: [10]bool = undefined;
    var toggle: bool = true;
    inline for (0..cells.len) |i| {
        cells[i] = toggle;
        toggle = !toggle;
    }

    const cx: c_int = win_width / 2;
    const cy: c_int = win_height / 2;

    const cells_x: c_int, const cells_y: c_int = top_left_from_center(
        cx,
        cy,
        cells_draw_width(10),
        cells_draw_width(1),
    );

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        draw_cell_row(cells[0..], cells_x, cells_y);
        ray.EndDrawing();
    }
}
