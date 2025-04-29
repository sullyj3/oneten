const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const Allocator = std.mem.Allocator;

const sleep = std.time.sleep;
const ns_per_s = std.time.ns_per_s;
const ns_per_ms = std.time.ns_per_ms;

const CELL_SIDE = 35;
const CELL_GAP = 4;
const CELL_BORDER_WIDTH = 2;

const BG_COLOR = ray.SKYBLUE;
const FG_COLOR = ray.DARKBLUE;
const SEL_COLOR = ray.GREEN;

fn draw_cell(on: bool, x: i32, y: i32) void {
    const rect: ray.Rectangle = .{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = CELL_SIDE,
        .height = CELL_SIDE,
    };

    if (on) {
        ray.DrawRectangleRec(rect, FG_COLOR);
    } else {
        ray.DrawRectangleLinesEx(rect, CELL_BORDER_WIDTH, FG_COLOR);
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
fn rule_110(triplet: []const bool) bool {
    std.debug.assert(triplet.len == 3);
    // we do this because in zig you can only switch on ints
    const trip_code: u3 =
        @as(u3, @intFromBool(triplet[0])) << 2 |
        @as(u3, @intFromBool(triplet[1])) << 1 |
        @as(u3, @intFromBool(triplet[2])) << 0;
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

fn sim_step_110(alloc: Allocator, in_row: []bool) ![]bool {
    const out_row: []bool = try alloc.alloc(bool, in_row.len);

    // cells outside our array are implicitly false
    out_row[0] = rule_110(&[3]bool{ false, in_row[0], in_row[1] });

    var windows = std.mem.window(bool, in_row, 3, 1);
    for (out_row[1 .. out_row.len - 1]) |*out_ptr| {
        out_ptr.* = rule_110(windows.next().?);
    }

    out_row[out_row.len - 1] = rule_110(&[3]bool{
        in_row[in_row.len - 2],
        in_row[in_row.len - 1],
        false,
    });

    return out_row;
}

const ArrayListUM = std.ArrayListUnmanaged;

const UVec2 = struct {
    x: u32,
    y: u32,

    fn mul_pointwise(self: UVec2, other: UVec2) UVec2 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }
};

const IVec2 = struct {
    x: i32,
    y: i32,

    fn mul_pointwise(self: IVec2, other: IVec2) IVec2 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    fn plus(self: IVec2, other: IVec2) IVec2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    fn plusU(self: IVec2, other: UVec2) IVec2 {
        return .{
            .x = self.x + @as(i32, @intCast(other.x)),
            .y = self.y + @as(i32, @intCast(other.y)),
        };
    }
};

fn cell_to_screen_offset(cell: UVec2) UVec2 {
    return cell.mul_pointwise(.{
        .x = CELL_SIDE + CELL_GAP,
        .y = CELL_SIDE + CELL_GAP,
    });
}

// rows are owned by the grid
const OneTenGrid = struct {
    rows: ArrayListUM([]bool),
    row_width: usize,

    // y down, so y=0 is the top
    selection: UVec2,

    alloc: Allocator,

    // takes ownership of initial_state, which must have been allocated from `alloc`.
    fn init(alloc: Allocator, n_cells: usize) !OneTenGrid {
        var rows: ArrayListUM([]bool) = try ArrayListUM([]bool).initCapacity(
            alloc,
            32,
        );
        const initial_state = try alloc.alloc(bool, n_cells);
        @memset(initial_state, false);
        rows.appendAssumeCapacity(initial_state);
        return .{
            .rows = rows,
            .row_width = initial_state.len,
            .selection = .{
                .x = @truncate(n_cells - 1),
                .y = 0,
            },
            .alloc = alloc,
        };
    }

    fn deinit(self: *OneTenGrid) void {
        for (self.rows.items) |row| {
            self.alloc.free(row);
        }
        self.rows.deinit(self.alloc);
    }

    fn append_step(self: *OneTenGrid) !void {
        const prev: []bool = self.rows.getLast();
        const next: []bool = try sim_step_110(self.alloc, prev);
        try self.rows.append(self.alloc, next);
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

        // draw selection
        const sel = (IVec2{
            .x = cells_x,
            .y = cells_y,
        }).plusU(cell_to_screen_offset(self.selection));
        const rect: ray.Rectangle = .{
            .x = @floatFromInt(sel.x),
            .y = @floatFromInt(sel.y),
            .width = CELL_SIDE,
            .height = CELL_SIDE,
        };

        ray.DrawRectangleLinesEx(rect, CELL_BORDER_WIDTH, SEL_COLOR);
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

        const rect: ray.Rectangle = .{
            .x = @floatFromInt(bg_x),
            .y = @floatFromInt(bg_y),
            .width = @floatFromInt(bg_width),
            .height = @floatFromInt(bg_height),
        };
        ray.DrawRectangleLinesEx(rect, GRID_BORDER_THICKNESS, FG_COLOR);
    }
};

const WIN_WIDTH = 1080;
const WIN_HEIGHT = 720;

const Sfx = struct {
    startup: ray.Sound,
    blip: ray.Sound,
    poweroff: ray.Sound,

    fn init() Sfx {
        ray.InitAudioDevice();

        // todo this depends on CWD
        return .{
            .startup = ray.LoadSound("res/startup.wav"),
            .blip = ray.LoadSound("res/blip.wav"),
            .poweroff = ray.LoadSound("res/poweroff.wav"),
        };
    }

    fn deinit(self: *const Sfx) void {
        ray.UnloadSound(self.startup);
        ray.UnloadSound(self.blip);
        ray.UnloadSound(self.poweroff);
        ray.CloseAudioDevice();
    }
};

fn handle_input(state: *State, sfx: Sfx) !void {
    if (ray.IsKeyPressed(ray.KEY_SPACE)) {
        ray.PlaySound(sfx.blip);
        try state.grid.append_step();
    }

    if (ray.IsKeyPressed(ray.KEY_Q)) {
        state.quit = true;
    }
}

fn draw(state: State) void {
    ray.BeginDrawing();
    defer ray.EndDrawing();
    ray.ClearBackground(BG_COLOR);
    state.grid.draw();
}

const State = struct {
    grid: OneTenGrid,
    quit: bool = false,

    alloc: Allocator,

    fn init(alloc: Allocator) !State {
        var grid: OneTenGrid = try OneTenGrid.init(alloc, 25);
        const row0 = grid.rows.getLast();
        row0[row0.len - 1] = true;

        return .{ .grid = grid, .alloc = alloc };
    }

    fn deinit(self: *State) void {
        self.grid.deinit();
    }
};

pub fn oneten() !void {
    const sfx = Sfx.init();
    defer sfx.deinit();
    ray.PlaySound(sfx.startup);

    {
        const title = "OneTen";
        ray.InitWindow(WIN_WIDTH, WIN_HEIGHT, title);
        defer ray.CloseWindow();
        ray.SetTargetFPS(60);

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const alloc = gpa.allocator();

        var state = try State.init(alloc);
        defer state.deinit();

        //////////////////////////////////////////////////
        // Main loop
        //////////////////////////////////////////////////
        while (!ray.WindowShouldClose() and !state.quit) {
            try handle_input(&state, sfx);
            draw(state);
        }
    }

    ray.PlaySound(sfx.poweroff);
    while (ray.IsSoundPlaying(sfx.poweroff)) {
        sleep(3 * ns_per_ms);
    }
}

pub fn main() !void {
    try oneten();
}
