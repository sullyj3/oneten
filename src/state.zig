const std = @import("std");

const CountdownTimer = @import("countdown.zig");

const OneTenGrid = @import("grid.zig").OneTenGrid;

const Allocator = std.mem.Allocator;

// TODO: design: it feels weird for this to be here instead of in input.zig,
// but if it was there it would be a circular dependency, since we keep an InputState in State
const InputState = struct {
    // TODO make this start slow and speed up while held
    const move_timeout_ms = 80;

    move_left_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_right_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_up_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_down_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),

    pub fn tick_ns(self: *InputState, dt_ns: i128) void {
        self.move_left_timeout.tick_ns(dt_ns);
        self.move_right_timeout.tick_ns(dt_ns);
        self.move_up_timeout.tick_ns(dt_ns);
        self.move_down_timeout.tick_ns(dt_ns);
    }
};

pub const State = struct {
    grid: OneTenGrid,
    quit: bool = false,
    delta_timer: std.time.Timer,
    input_state: InputState = .{},

    alloc: Allocator,

    pub fn init(alloc: Allocator) error{ TimerUnsupported, OutOfMemory }!State {
        var grid: OneTenGrid = try OneTenGrid.init(alloc, 25);
        const row0 = grid.rows.getLast();
        row0[row0.len - 1] = true;

        return .{
            .grid = grid,
            .delta_timer = try std.time.Timer.start(),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *State) void {
        self.grid.deinit();
    }
};
