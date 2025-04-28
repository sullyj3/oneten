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

const CELL_SIDE = 30;
const CELL_GAP = 3;
const CELL_BORDER_WIDTH = 2;

fn draw_cell(on: bool, x: c_int, y: c_int) void {
    draw_square(x, y, CELL_SIDE, ray.VIOLET);
    if (!on) {
        draw_square(
            x + CELL_BORDER_WIDTH,
            y + CELL_BORDER_WIDTH,
            CELL_SIDE - 2 * CELL_BORDER_WIDTH,
            ray.RAYWHITE,
        );
    }
}

fn draw_grid_bg(cx: c_int, cy: c_int) void {
    const GRID_PADDING = 20;
    const GRID_BORDER_THICKNESS = 5;

    const bg_width = ROW_SIZE * CELL_SIDE +
        (ROW_SIZE - 1) * CELL_GAP +
        2 * GRID_PADDING; // edges
    const bg_height = N_ROWS * CELL_SIDE +
        (N_ROWS - 1) * CELL_GAP +
        2 * GRID_PADDING; // edges

    const bg_x: c_int, const bg_y: c_int = top_left_from_center(
        cx,
        cy,
        bg_width,
        bg_height,
    );

    const fg_width = bg_width - 2 * GRID_BORDER_THICKNESS;
    const fg_height = bg_width - 2 * GRID_BORDER_THICKNESS;
    const fg_x = bg_x + GRID_BORDER_THICKNESS;
    const fg_y = bg_y + GRID_BORDER_THICKNESS;

    ray.DrawRectangle(bg_x, bg_y, bg_width, bg_height, ray.VIOLET);
    ray.DrawRectangle(fg_x, fg_y, fg_width, fg_height, ray.RAYWHITE);
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

const BoolTriple = struct { bool, bool, bool };

/// trip_code summarizes the prior state of the 3 cells centered on the index
/// whose new value we want to calculate
fn rule_110(trip_code: u3) bool {
    return switch (trip_code) {
        0b111 => false,
        0b110 => true,
        0b101 => true,
        0b100 => false,
        0b011 => true,
        0b010 => true,
        0b001 => true,
        0b000 => false,
    };
}

const Allocator = std.mem.Allocator;

fn sim_step_110(alloc: Allocator, in_row: []bool) ![]bool {
    const out_row: []bool = try alloc.alloc(bool, in_row.len);

    // obvious perf stuff to explore
    // - string search for nonzero
    // - write zeroes to memory in bulk
    // - look up if 110 can be done in place... seems plausible with constant tmp variables

    // we special case the start and end to avoid indexing out of bounds or
    // having to check if we're at the end each iteration
    // cells outside our array are implicitly false
    var trip_code: u3 =
        @as(u3, @intFromBool(false)) << 2 |
        @as(u3, @intFromBool(in_row[0])) << 1 |
        @as(u3, @intFromBool(in_row[1])) << 0;
    out_row[0] = rule_110(trip_code);

    for (1..out_row.len - 1) |i| {
        trip_code =
            @as(u3, @intFromBool(in_row[i - 1])) << 2 |
            @as(u3, @intFromBool(in_row[i])) << 1 |
            @as(u3, @intFromBool(in_row[i + 1])) << 0;

        out_row[i] = rule_110(trip_code);
    }

    trip_code =
        @as(u3, @intFromBool(in_row[in_row.len - 2])) << 2 |
        @as(u3, @intFromBool(in_row[in_row.len - 1])) << 1 |
        @as(u3, @intFromBool(false)) << 0;
    out_row[in_row.len - 1] = rule_110(trip_code);

    return out_row;
}

fn init_alternating(cells: []bool) void {
    var toggle: bool = true;
    inline for (0..cells.len) |i| {
        cells[i] = toggle;
        toggle = !toggle;
    }
}

fn fill(val: bool, cells: []bool) void {
    for (cells) |*cell| cell.* = val;
}

const ROW_SIZE = 20;
const N_ROWS = 20;

pub fn oneten() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    //////////////////////////////////////////////////
    const win_width = 1080;
    const win_height = 720;

    const title = "oneten";
    ray.InitWindow(win_width, win_height, title);
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    //////////////////////////////////////////////////

    // construct initial row
    const cells0: []bool = try alloc.alloc(bool, ROW_SIZE);
    fill(false, cells0);
    cells0[cells0.len - 1] = true;

    // simulate and store some steps
    var rows: [N_ROWS][]bool = undefined;
    rows[0] = cells0;

    for (rows[1..], 1..) |*row, i| {
        row.* = try sim_step_110(alloc, rows[i - 1]);
    }
    defer for (rows) |row| alloc.free(row);

    //////////////////////////////////////////////////

    const cx: c_int = win_width / 2;
    const cy: c_int = win_height / 2;

    const cells_x: c_int, const cells_y: c_int = top_left_from_center(
        cx,
        cy,
        cells_draw_width(ROW_SIZE),
        cells_draw_width(N_ROWS),
    );

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        draw_grid_bg(cx, cy);
        for (rows, 0..) |row, i| {
            draw_cell_row(row, cells_x, cells_y + @as(c_int, @intCast(i)) * (CELL_SIDE + CELL_GAP));
        }
        ray.EndDrawing();
    }
}

pub fn main() !void {
    try oneten();
}
