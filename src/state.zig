const std = @import("std");

const OneTenGrid = @import("grid.zig").OneTenGrid;
const InputState = @import("input.zig").InputState;

const Allocator = std.mem.Allocator;

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
