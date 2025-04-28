const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const sleep = std.time.sleep;
const ns_per_s = std.time.ns_per_s;

fn draw_square(x: i32, y: i32, side: i32, color: ray.Color) void {
    ray.DrawRectangle(x, y, side, side, color);
}

const CELL_SIDE = 30;
const CELL_GAP = 3;
const CELL_BORDER_WIDTH = 2;

const BG_COLOR = ray.SKYBLUE;
const FG_COLOR = ray.DARKBLUE;

fn draw_cell(on: bool, x: i32, y: i32) void {
    draw_square(x, y, CELL_SIDE, FG_COLOR);
    if (!on) {
        draw_square(
            x + CELL_BORDER_WIDTH,
            y + CELL_BORDER_WIDTH,
            CELL_SIDE - 2 * CELL_BORDER_WIDTH,
            BG_COLOR,
        );
    }
}

fn draw_cell_row(cell_states: []bool, x: i32, y: i32) void {
    var x_offs: i32 = 0;
    for (cell_states) |cell| {
        draw_cell(cell, x + x_offs, y);
        x_offs += CELL_SIDE + CELL_GAP;
    }
}

fn cells_draw_width(n_cells: usize) u32 {
    return @intCast(n_cells * CELL_SIDE + (n_cells - 1) * CELL_GAP);
}

fn top_left_from_center(
    cx: i32,
    cy: i32,
    width: u32,
    height: u32,
) struct { i32, i32 } {
    const half_width: i32 = @intCast(width / 2);
    const half_height: i32 = @intCast(height / 2);
    return .{
        cx - half_width,
        cy - half_height,
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

    fn deinit(self: *OneTenGrid, alloc: Allocator) void {
        for (self.rows.items) |row| {
            alloc.free(row);
        }
        self.rows.deinit(alloc);
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
        const cx: i32 = WIN_WIDTH / 2;
        const cy: i32 = WIN_HEIGHT / 2;

        const cells_x: i32, const cells_y: i32 = top_left_from_center(
            cx,
            cy,
            cells_draw_width(self.row_width),
            cells_draw_width(self.rows.items.len),
        );

        self.draw_grid_bg(cx, cy);
        for (self.rows.items, 0..) |row, i| {
            const y_offs: i32 = @intCast(i * (CELL_SIDE + CELL_GAP));
            draw_cell_row(row, cells_x, cells_y + y_offs);
        }
    }

    fn draw_grid_bg(self: OneTenGrid, cx: i32, cy: i32) void {
        const GRID_PADDING = 20;
        const GRID_BORDER_THICKNESS = 5;

        const row_width: u32 = @truncate(self.row_width);
        const n_rows_u: u32 = @truncate(self.n_rows());

        const bg_width: u32 = row_width * CELL_SIDE +
            (row_width - 1) * CELL_GAP +
            2 * GRID_PADDING;
        const bg_height: u32 = n_rows_u * CELL_SIDE +
            (n_rows_u - 1) * CELL_GAP +
            2 * GRID_PADDING;

        const bg_x: i32, const bg_y: i32 = top_left_from_center(
            cx,
            cy,
            bg_width,
            bg_height,
        );

        const fg_width = bg_width - 2 * GRID_BORDER_THICKNESS;
        const fg_height = bg_height - 2 * GRID_BORDER_THICKNESS;
        const fg_x = bg_x + GRID_BORDER_THICKNESS;
        const fg_y = bg_y + GRID_BORDER_THICKNESS;

        const bg_width_c: c_int = @intCast(bg_width);
        const bg_height_c: c_int = @intCast(bg_height);
        const fg_width_c: c_int = @intCast(fg_width);
        const fg_height_c: c_int = @intCast(fg_height);

        ray.DrawRectangle(bg_x, bg_y, bg_width_c, bg_height_c, FG_COLOR);
        ray.DrawRectangle(fg_x, fg_y, fg_width_c, fg_height_c, BG_COLOR);
    }
};

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
    @memset(cells0, false);
    cells0[cells0.len - 1] = true;
    var grid: OneTenGrid = try OneTenGrid.init(alloc, cells0);
    defer grid.deinit(alloc);

    //////////////////////////////////////////////////

    while (!ray.WindowShouldClose()) {
        if (ray.IsKeyPressed(ray.KEY_SPACE)) {
            try grid.append_step(alloc);
        }

        ray.BeginDrawing();
        ray.ClearBackground(BG_COLOR);
        grid.draw();
        ray.EndDrawing();
    }
}

pub fn main() !void {
    try oneten();
}
