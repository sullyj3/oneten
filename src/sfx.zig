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

// TODO refactor so that we no longer enumerate these manually. this can result in leaks, forgetting
// etc
startup: ray.Sound,
blip: ray.Sound,
poweroff: ray.Sound,
plip: ray.Sound,

pub fn get_sound_by_id(self: Sfx, sound_id: SoundId) ?ray.Sound {
    return switch (sound_id) {
        .startup => self.startup,
        .blip => self.blip,
        .poweroff => self.poweroff,
        .plip => self.plip,
    };
}

pub fn play(self: Sfx, sound_id: SoundId) void {
    if (self.get_sound_by_id(sound_id)) |sound| ray.playSound(sound);
}

pub fn is_sound_playing(self: Sfx, sound_id: SoundId) bool {
    return if (self.get_sound_by_id(sound_id)) |sound|
        ray.isSoundPlaying(sound)
    else
        false;
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

    const startup = try ray.loadSound(startup_path);
    const blip = try ray.loadSound(blip_path);
    const poweroff = try ray.loadSound(poweroff_path);
    const plip = try ray.loadSound(plip_path);

    return Sfx{
        .startup = startup,
        .blip = blip,
        .poweroff = poweroff,
        .plip = plip,
    };
}

pub fn deinit(self: *const Sfx) void {
    ray.unloadSound(self.startup);
    ray.unloadSound(self.blip);
    ray.unloadSound(self.poweroff);
    ray.unloadSound(self.plip);
    ray.closeAudioDevice();
}
