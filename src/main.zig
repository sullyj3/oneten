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

fn draw_cell_row(cell_states: []bool, x: c_int, y: c_int) void {
    var x_offs: c_int = 0;
    for (cell_states) |cell| {
        draw_cell(cell, x + x_offs, y);
        x_offs += CELL_SIDE + CELL_GAP;
    }
}

fn cells_draw_width(n_cells: usize) c_int {
    const n_cells_c: c_int = @intCast(n_cells);
    return n_cells_c * CELL_SIDE + (n_cells_c - 1) * CELL_GAP;
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

const ArrayListUM = std.ArrayListUnmanaged;

// rows are owned by the grid
const OneTenGrid = struct {
    rows: ArrayListUM([]bool),
    row_width: usize,

    // takes ownership of initial_state, which must have been allocated from `alloc`.
    fn init(alloc: Allocator, initial_state: []bool) !OneTenGrid {
        var rows: ArrayListUM([]bool) = try ArrayListUM([]bool).initCapacity(
            alloc,
            32,
        );
        rows.appendAssumeCapacity(initial_state);
        return .{
            .rows = rows,
            .row_width = initial_state.len,
        };
    }

    fn deinit(self: OneTenGrid, alloc: Allocator) void {
        for (self.rows.items) |row| {
            alloc.free(row);
        }
        self.rows.deinit();
    }

    fn append_step(self: *OneTenGrid, alloc: Allocator) !void {
        const prev: []bool = self.rows.getLast();
        const next: []bool = try sim_step_110(alloc, prev);
        try self.rows.append(alloc, next);
    }

    fn n_rows(self: OneTenGrid) usize {
        return self.rows.items.len;
    }

    fn draw(self: OneTenGrid) void {
        const cx: c_int = WIN_WIDTH / 2;
        const cy: c_int = WIN_HEIGHT / 2;

        const cells_x: c_int, const cells_y: c_int = top_left_from_center(
            cx,
            cy,
            cells_draw_width(self.row_width),
            cells_draw_width(self.rows.items.len),
        );

        self.draw_grid_bg(cx, cy);
        for (self.rows.items, 0..) |row, i| {
            draw_cell_row(
                row,
                cells_x,
                cells_y + @as(c_int, @intCast(i)) * (CELL_SIDE + CELL_GAP),
            );
        }
    }

    fn draw_grid_bg(self: OneTenGrid, cx: c_int, cy: c_int) void {
        const GRID_PADDING = 20;
        const GRID_BORDER_THICKNESS = 5;

        const row_width_c: c_int = @as(c_int, @intCast(self.row_width));
        const n_rows_c: c_int = @as(c_int, @intCast(self.n_rows()));

        const bg_width: c_int = row_width_c * CELL_SIDE +
            (row_width_c - 1) * CELL_GAP +
            2 * GRID_PADDING;
        const bg_height: c_int = n_rows_c * CELL_SIDE +
            (n_rows_c - 1) * CELL_GAP +
            2 * GRID_PADDING;

        const bg_x: c_int, const bg_y: c_int = top_left_from_center(
            cx,
            cy,
            bg_width,
            bg_height,
        );

        const fg_width = bg_width - 2 * GRID_BORDER_THICKNESS;
        const fg_height = bg_height - 2 * GRID_BORDER_THICKNESS;
        const fg_x = bg_x + GRID_BORDER_THICKNESS;
        const fg_y = bg_y + GRID_BORDER_THICKNESS;

        ray.DrawRectangle(bg_x, bg_y, bg_width, bg_height, ray.VIOLET);
        ray.DrawRectangle(fg_x, fg_y, fg_width, fg_height, ray.RAYWHITE);
    }
};

fn fill(val: bool, cells: []bool) void {
    for (cells) |*cell| cell.* = val;
}

const WIN_WIDTH = 1080;
const WIN_HEIGHT = 720;

pub fn oneten() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    //////////////////////////////////////////////////
    const title = "oneten";
    ray.InitWindow(WIN_WIDTH, WIN_HEIGHT, title);
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    //////////////////////////////////////////////////

    // construct initial row
    const cells0: []bool = try alloc.alloc(bool, 30);
    fill(false, cells0);
    cells0[cells0.len - 1] = true;
    var grid: OneTenGrid = try OneTenGrid.init(alloc, cells0);

    //////////////////////////////////////////////////

    while (!ray.WindowShouldClose()) {
        if (ray.IsKeyPressed(ray.KEY_SPACE)) {
            try grid.append_step(alloc);
        }

        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        grid.draw();
        ray.EndDrawing();
    }
}

pub fn main() !void {
    try oneten();
}
