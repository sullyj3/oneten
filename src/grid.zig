const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUM = std.ArrayListUnmanaged;

const intvecs = @import("intvecs.zig");
const UVec2 = intvecs.UVec2;
const IVec2 = intvecs.IVec2;

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

// rows are owned by the grid
pub const OneTenGrid = struct {
    rows: ArrayListUM([]bool),
    row_width: usize,

    // y down, so y=0 is the top
    selection: UVec2,

    alloc: Allocator,

    // takes ownership of initial_state, which must have been allocated from `alloc`.
    pub fn init(alloc: Allocator, n_cells: usize) !OneTenGrid {
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

    pub fn deinit(self: *OneTenGrid) void {
        for (self.rows.items) |row| {
            self.alloc.free(row);
        }
        self.rows.deinit(self.alloc);
    }

    pub fn reset(self: *OneTenGrid) !void {
        const alloc = self.alloc;
        const n_cells = self.row_width;

        // this is obviously suboptimal, but unlikely to become too slow
        self.deinit();
        self.* = try OneTenGrid.init(alloc, n_cells);
    }

    pub fn append_step(self: *OneTenGrid) !void {
        const prev: []bool = self.rows.getLast();
        const next: []bool = try sim_step_110(self.alloc, prev);
        try self.rows.append(self.alloc, next);
    }

    fn n_rows(self: OneTenGrid) usize {
        return self.rows.items.len;
    }

    pub fn cellspace_dimensions(self: OneTenGrid) struct { usize, usize } {
        return .{ self.row_width, self.n_rows() };
    }

    pub fn move_selection(self: *OneTenGrid, offs: IVec2) void {
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

    pub fn toggle_selection(self: *OneTenGrid) void {
        const ptr: *bool = self.selection_ptr();
        ptr.* = !ptr.*;
    }

    pub fn delete_latest_row(self: *OneTenGrid) void {
        if (self.n_rows() == 1) {
            return;
        } else if (self.rows.pop()) |last| {
            self.alloc.free(last);
            // ensure selection remains in new smaller bounds
            if (self.selection.y >= self.n_rows()) {
                self.move_selection(.{ .x = 0, .y = -1 });
            }
        }
    }
};
