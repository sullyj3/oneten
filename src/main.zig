const std = @import("std");
const ray = @import("raylib");

const Allocator = std.mem.Allocator;

const sleep = std.time.sleep;
const ns_per_s = std.time.ns_per_s;
const ns_per_ms = std.time.ns_per_ms;

const CELL_SIDE = 35;
const CELL_GAP = 4;
const CELL_BORDER_WIDTH = 2;

const BG_COLOR = ray.Color.sky_blue;
const FG_COLOR = ray.Color.dark_blue;
const SEL_COLOR = ray.Color.green;

fn draw_cell(on: bool, x: i32, y: i32) void {
    const rect: ray.Rectangle = .{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = CELL_SIDE,
        .height = CELL_SIDE,
    };

    if (on) {
        ray.drawRectangleRec(rect, FG_COLOR);
    } else {
        ray.drawRectangleLinesEx(rect, CELL_BORDER_WIDTH, FG_COLOR);
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

        ray.drawRectangleLinesEx(rect, CELL_BORDER_WIDTH, SEL_COLOR);
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
        ray.drawRectangleLinesEx(rect, GRID_BORDER_THICKNESS, FG_COLOR);
    }

    fn move_selection(self: *OneTenGrid, offs: IVec2) void {
        var x: i64 = @as(i64, self.selection.x) + offs.x;
        var y: i64 = @as(i64, self.selection.y) + offs.y;

        x = @mod(x, @as(i64, @intCast(self.row_width)));
        y = @mod(y, @as(i64, @intCast(self.n_rows())));

        self.selection.x = @intCast(x);
        self.selection.y = @intCast(y);
    }

    fn selection_ptr(self: OneTenGrid) *bool {
        return &self.rows.items[self.selection.y][self.selection.x];
    }

    fn toggle_selection(self: *OneTenGrid) void {
        const ptr: *bool = self.selection_ptr();
        ptr.* = !ptr.*;
    }

    fn delete_latest_row(self: *OneTenGrid) void {
        if (self.n_rows() == 1) {
            return;
        } else if (self.rows.pop()) |last| {
            self.alloc.free(last);
            // ensure selection remains in new smaller bounds
            self.move_selection(.{ .x = 0, .y = -1 });
        }
    }
};

const WIN_WIDTH = 1080;
const WIN_HEIGHT = 720;

const SoundId = enum {
    startup,
    blip,
    poweroff,
};

const Sfx = struct {
    startup: ?ray.Sound,
    blip: ?ray.Sound,
    poweroff: ?ray.Sound,

    fn maybe_load_sound(path: [:0]const u8) ?ray.Sound {
        return ray.loadSound(path) catch null;
    }

    fn get_sound_by_id(self: Sfx, sound_id: SoundId) ?ray.Sound {
        return switch (sound_id) {
            SoundId.startup => self.startup,
            SoundId.blip => self.blip,
            SoundId.poweroff => self.poweroff,
        };
    }

    fn play(self: Sfx, sound_id: SoundId) void {
        const sound = self.get_sound_by_id(sound_id);
        if (sound) |sound_| {
            ray.playSound(sound_);
        }
    }

    fn is_sound_playing(self: Sfx, sound_id: SoundId) bool {
        return if (self.get_sound_by_id(sound_id)) |sound|
            ray.isSoundPlaying(sound)
        else
            false;
    }

    fn init() ray.RaylibError!Sfx {
        ray.initAudioDevice();

        const startup = Sfx.maybe_load_sound("res/startup.wav");
        const blip = Sfx.maybe_load_sound("res/blip.wav");
        const poweroff = Sfx.maybe_load_sound("res/poweroff.wav");
        return Sfx{
            .startup = startup,
            .blip = blip,
            .poweroff = poweroff,
        };
    }

    fn deinit(self: *const Sfx) void {
        if (self.startup) |s| ray.unloadSound(s);
        if (self.blip) |s| ray.unloadSound(s);
        if (self.poweroff) |s| ray.unloadSound(s);
        ray.closeAudioDevice();
    }
};

const CountdownTimer = struct {
    duration_ns: i128,
    remaining_ns: i128,
    elapsed: bool = false,

    fn new(duration_ns: i128) CountdownTimer {
        return .{
            .duration_ns = duration_ns,
            .remaining_ns = duration_ns,
            .elapsed = false,
        };
    }

    fn new_ms(duration_ms: i128) CountdownTimer {
        return CountdownTimer.new(duration_ms * std.time.ns_per_ms);
    }

    fn new_elapsed_ms(duration_ms: i128) CountdownTimer {
        var timer = CountdownTimer.new(duration_ms * std.time.ns_per_ms);
        timer.elapsed = true;
        return timer;
    }

    fn new_s(duration_s: f64) CountdownTimer {
        const ns_f: f64 = duration_s * @as(f64, @floatFromInt(std.time.ns_per_s));
        return CountdownTimer.new(@intFromFloat(ns_f));
    }

    fn tick_ns(self: *CountdownTimer, dt_ns: i128) void {
        self.remaining_ns, _ = @subWithOverflow(self.remaining_ns, dt_ns);
        self.elapsed = self.elapsed or self.remaining_ns <= 0;
    }

    fn reset(self: *CountdownTimer) void {
        self.elapsed = false;
        self.remaining_ns = self.duration_ns;
    }
};

const DeltaTimer = struct {
    last_ns: i128,

    fn init() DeltaTimer {
        return .{ .last_ns = std.time.nanoTimestamp() };
    }

    // return time in nanoseconds since init or last lap call
    fn lap_ns(self: *DeltaTimer) i128 {
        const now_ns = std.time.nanoTimestamp();
        const dt_ns = now_ns - self.last_ns;
        self.last_ns = now_ns;
        return dt_ns;
    }

    // return time in seconds since init or last lap call
    fn lap_s(self: *DeltaTimer) f32 {
        const NS_IN_S = 1_000_000_000;
        const dt_ns = self.lap_ns();
        return @as(f32, @floatFromInt(dt_ns)) / NS_IN_S;
    }
};

fn handle_input(state: *State, sfx: Sfx, dt_ns: i128) !void {
    state.input_state.tick_ns(dt_ns);
    const input_state = &state.input_state;

    const Key = ray.KeyboardKey;
    if (ray.isKeyPressed(Key.space)) {
        sfx.play(SoundId.blip);
        state.grid.toggle_selection();
    }

    if (ray.isKeyPressed(Key.enter)) {
        sfx.play(SoundId.blip);
        try state.grid.append_step();
    }
    if (ray.isKeyPressed(Key.backspace)) {
        sfx.play(SoundId.poweroff);
        state.grid.delete_latest_row();
    }

    // TODO create an input actions system
    // TODO abstract this timeout logic
    if ((ray.isKeyDown(Key.left) or ray.isKeyDown(Key.h)) and
        input_state.move_left_timeout.elapsed)
    {
        input_state.move_left_timeout.reset();
        state.grid.move_selection(IVec2{ .x = -1, .y = 0 });
        sfx.play(SoundId.blip);
    }
    if ((ray.isKeyDown(Key.right) or ray.isKeyDown(Key.l)) and
        input_state.move_right_timeout.elapsed)
    {
        input_state.move_right_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 1, .y = 0 });
        sfx.play(SoundId.blip);
    }
    if ((ray.isKeyDown(Key.up) or ray.isKeyDown(Key.k)) and
        input_state.move_up_timeout.elapsed)
    {
        input_state.move_up_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 0, .y = -1 });
        sfx.play(SoundId.blip);
    }
    if ((ray.isKeyDown(Key.down) or ray.isKeyDown(Key.j)) and
        input_state.move_down_timeout.elapsed)
    {
        input_state.move_down_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 0, .y = 1 });
        sfx.play(SoundId.blip);
    }

    if (ray.isKeyPressed(Key.q)) {
        state.quit = true;
    }
}

fn draw(state: State) void {
    ray.beginDrawing();
    defer ray.endDrawing();
    ray.clearBackground(BG_COLOR);
    state.grid.draw();
}

const InputState = struct {
    // TODO make this start slow and speed up while held
    const move_timeout_ms = 80;

    move_left_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_right_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_up_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_down_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),

    fn tick_ns(self: *InputState, dt_ns: i128) void {
        self.move_left_timeout.tick_ns(dt_ns);
        self.move_right_timeout.tick_ns(dt_ns);
        self.move_up_timeout.tick_ns(dt_ns);
        self.move_down_timeout.tick_ns(dt_ns);
    }
};

const State = struct {
    grid: OneTenGrid,
    quit: bool = false,
    input_state: InputState = .{},

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
    const sfx: Sfx = try Sfx.init();
    defer sfx.deinit();
    sfx.play(SoundId.startup);

    {
        ray.setConfigFlags(.{
            .window_undecorated = true,
            .window_resizable = false,
        });
        const title = "OneTen";
        ray.initWindow(WIN_WIDTH, WIN_HEIGHT, title);
        defer ray.closeWindow();

        ray.setTargetFPS(60);

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const alloc = gpa.allocator();

        var state = try State.init(alloc);
        defer state.deinit();

        //////////////////////////////////////////////////
        // Main loop
        //////////////////////////////////////////////////
        var delta_timer = DeltaTimer.init();
        while (!ray.windowShouldClose() and !state.quit) {
            const dt_ns: i128 = delta_timer.lap_ns();
            try handle_input(&state, sfx, dt_ns);
            draw(state);
        }
        sfx.play(SoundId.poweroff);
    }

    while (sfx.is_sound_playing(SoundId.poweroff)) {
        sleep(3 * ns_per_ms);
    }
}

pub fn main() !void {
    try oneten();
}
