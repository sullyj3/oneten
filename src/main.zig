// std
const std = @import("std");
const Allocator = std.mem.Allocator;
const sleep = std.time.sleep;
const ns_per_s = std.time.ns_per_s;
const ns_per_ms = std.time.ns_per_ms;

// third party
const ray = @import("raylib");

// first party
const input = @import("input.zig");
const draw = @import("draw.zig");
const intvecs = @import("intvecs.zig");
const IVec2 = intvecs.IVec2;
const State = @import("state.zig").State;
const Sfx = @import("sfx.zig").Sfx;
const SoundId = @import("sfx.zig").SoundId;

pub fn oneten() !void {
    const sfx: Sfx = Sfx.init();
    defer sfx.deinit();
    sfx.play(SoundId.startup);

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
            const dt_ns: i128 = state.delta_timer.lap_ns();
            try input.handle_input(&state, sfx, dt_ns);
            draw.draw(state);
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
