const std = @import("std");
const ray = @import("raylib");

const Sfx = @This();

const Allocator = std.mem.Allocator;

pub const SoundId = enum {
    startup,
    blip,
    poweroff,
    plip,
};

sounds: std.enums.EnumArray(SoundId, ray.Sound),

pub fn play(self: Sfx, sound_id: SoundId) void {
    ray.playSound(self.sounds.get(sound_id));
}

pub fn is_sound_playing(self: Sfx, sound_id: SoundId) bool {
    return ray.isSoundPlaying(self.sounds.get(sound_id));
}

pub fn sleep_til_finished(self: Sfx, sound_id: SoundId, poll_interval_ms: u64) void {
    while (self.is_sound_playing(sound_id)) {
        std.time.sleep(poll_interval_ms * std.time.ns_per_ms);
    }
}

pub fn init(exe_path: []const u8) !Sfx {
    ray.initAudioDevice();
    var buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    // relative to ./zig-out/bin
    // TODO possibly the res folder should get copied to zig-out?
    // maybe the sounds should be included in the binary? need to research the best approach
    const res_path_rel = "../../res";
    // TODO currently we can't reset the fba for every path because it'll overwrite the res path
    // revisit once we've precalculated the res path and stored it in AppCtx
    const res_path_abs = try std.fs.path.joinZ(alloc, &.{ exe_path, res_path_rel });

    const startup_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "startup.wav" });
    const blip_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "blip.wav" });
    const poweroff_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "poweroff.wav" });
    const plip_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "plip.wav" });

    return Sfx{
        .sounds = std.EnumArray(SoundId, ray.Sound).init(.{
            .startup = try ray.loadSound(startup_path),
            .blip = try ray.loadSound(blip_path),
            .poweroff = try ray.loadSound(poweroff_path),
            .plip = try ray.loadSound(plip_path),
        }),
    };
}

pub fn deinit(self: *const Sfx) void {
    for (self.sounds.values) |s| ray.unloadSound(s);
    ray.closeAudioDevice();
}
