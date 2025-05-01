// std
const std = @import("std");

// third party
const ray = @import("raylib");

// first party
const input = @import("input.zig");
const draw = @import("draw.zig");
const State = @import("state.zig").State;
const Sfx = @import("sfx.zig");

const Allocator = std.mem.Allocator;

const AppCtx = struct {
    const MAX_EXE_DIR_PATH_LEN = 256;
    exe_dir: []const u8,
    // TODO calculate and store res folder path here
    sfx: Sfx,

    alloc: Allocator,

    fn init(alloc: Allocator) !AppCtx {
        const exe_dir = try std.fs.selfExeDirPathAlloc(alloc);
        const sfx = try Sfx.init(exe_dir);

        return .{
            .exe_dir = exe_dir,
            .sfx = sfx,
            .alloc = alloc,
        };
    }

    fn deinit(self: *AppCtx) void {
        self.alloc.free(self.exe_dir);
        self.sfx.deinit();
    }
};

pub fn oneten() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var ctx: AppCtx = try AppCtx.init(alloc);
    defer ctx.deinit();

    ctx.sfx.play(.startup);
    {
        ray.setConfigFlags(.{
            .window_undecorated = true,
            .window_resizable = false,
        });
        const title = "OneTen";
        ray.initWindow(draw.WIN_WIDTH, draw.WIN_HEIGHT, title);
        defer ray.closeWindow();

        ray.setTargetFPS(60);

        var state = try State.init(alloc);
        defer state.deinit();

        while (!ray.windowShouldClose() and !state.quit) {
            const dt_ns: i128 = state.delta_timer.lap();
            try input.handle_input(&state, ctx.sfx, dt_ns);
            draw.draw(state);
        }
        ctx.sfx.play(.poweroff);
    }
    ctx.sfx.sleep_til_finished(.poweroff, 3);
}

pub fn main() !void {
    try oneten();
}
