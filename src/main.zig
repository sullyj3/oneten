// std
const std = @import("std");

// third party
const ray = @import("raylib");

// first party
const input = @import("input.zig");
const draw = @import("draw.zig");
const State = @import("state.zig").State;
const Sfx = @import("sfx.zig");

const AppCtx = struct {
    const MAX_EXE_DIR_PATH_LEN = 256;
    exe_dir_buf: [MAX_EXE_DIR_PATH_LEN]u8 = undefined,
    exe_dir: []const u8,
    sfx: Sfx,

    fn init() !AppCtx {
        var ctx: AppCtx = undefined;
        ctx.exe_dir = try std.fs.selfExeDirPath(&ctx.exe_dir_buf);
        std.debug.print("exe_dir: {s}\n", .{ctx.exe_dir});
        ctx.sfx = try Sfx.init(ctx.exe_dir);

        return ctx;
    }

    fn deinit(self: *AppCtx) void {
        self.sfx.deinit();
    }
};

pub fn oneten() !void {
    const ctx: AppCtx = try AppCtx.init();
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

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const alloc = gpa.allocator();

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
