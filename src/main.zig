// std
const std = @import("std");

// third party
const ray = @import("raylib");

// first party
const input = @import("input.zig");
const draw = @import("draw.zig");
const State = @import("state.zig").State;
const Sfx = @import("sfx.zig");

const try_clay = @import("try_clay.zig");

const Allocator = std.mem.Allocator;

const AppCtx = struct {
    const MAX_EXE_DIR_PATH_LEN = 256;
    exe_dir: []const u8,
    res_dir: []const u8,
    sfx: Sfx,

    alloc: Allocator,

    fn init(alloc: Allocator) !AppCtx {
        const exe_dir = try std.fs.selfExeDirPathAlloc(alloc);

        // relative to ./zig-out/bin
        // TODO possibly the res folder should get copied to zig-out?
        // maybe the sounds should be included in the binary? need to research the best approach
        const res_path_rel = "../../res";
        const res_path_abs = try std.fs.path.join(alloc, &.{ exe_dir, res_path_rel });

        const sfx: Sfx = try .init(res_path_abs);

        return .{
            .exe_dir = exe_dir,
            .res_dir = res_path_abs,
            .sfx = sfx,
            .alloc = alloc,
        };
    }

    fn deinit(self: *AppCtx) void {
        self.alloc.free(self.exe_dir);
        self.alloc.free(self.res_dir);
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
    // try oneten();
    try try_clay.main();
}
