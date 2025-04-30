const std = @import("std");

const OneTenGrid = @import("grid.zig").OneTenGrid;

const Allocator = std.mem.Allocator;

const ns_per_s = std.time.ns_per_s;
const ns_per_ms = std.time.ns_per_ms;

const CountdownTimer = struct {
    duration_ns: i128,
    remaining_ns: i128,
    elapsed: bool = false,

    pub fn new(duration_ns: i128) CountdownTimer {
        return .{
            .duration_ns = duration_ns,
            .remaining_ns = duration_ns,
            .elapsed = false,
        };
    }

    pub fn new_ms(duration_ms: i128) CountdownTimer {
        return CountdownTimer.new(duration_ms * ns_per_ms);
    }

    pub fn new_elapsed_ms(duration_ms: i128) CountdownTimer {
        var timer = CountdownTimer.new(duration_ms * ns_per_ms);
        timer.elapsed = true;
        return timer;
    }

    pub fn new_s(duration_s: f64) CountdownTimer {
        const ns_f: f64 = duration_s * @as(f64, @floatFromInt(ns_per_s));
        return CountdownTimer.new(@intFromFloat(ns_f));
    }

    pub fn tick_ns(self: *CountdownTimer, dt_ns: i128) void {
        self.remaining_ns, _ = @subWithOverflow(self.remaining_ns, dt_ns);
        self.elapsed = self.elapsed or self.remaining_ns <= 0;
    }

    pub fn reset(self: *CountdownTimer) void {
        self.elapsed = false;
        self.remaining_ns = self.duration_ns;
    }
};

const DeltaTimer = struct {
    last_ns: i128,

    pub fn init() DeltaTimer {
        return .{ .last_ns = std.time.nanoTimestamp() };
    }

    // return time in nanoseconds since init or last lap call
    pub fn lap_ns(self: *DeltaTimer) i128 {
        const now_ns = std.time.nanoTimestamp();
        const dt_ns = now_ns - self.last_ns;
        self.last_ns = now_ns;
        return dt_ns;
    }

    // return time in seconds since init or last lap call
    pub fn lap_s(self: *DeltaTimer) f32 {
        const NS_IN_S = 1_000_000_000;
        const dt_ns = self.lap_ns();
        return @as(f32, @floatFromInt(dt_ns)) / NS_IN_S;
    }
};

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
    delta_timer: DeltaTimer,
    input_state: InputState = .{},

    alloc: Allocator,

    pub fn init(alloc: Allocator) !State {
        var grid: OneTenGrid = try OneTenGrid.init(alloc, 25);
        const row0 = grid.rows.getLast();
        row0[row0.len - 1] = true;

        return .{
            .grid = grid,
            .delta_timer = DeltaTimer.init(),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *State) void {
        self.grid.deinit();
    }
};
