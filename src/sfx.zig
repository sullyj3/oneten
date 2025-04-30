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

startup: ?ray.Sound,
blip: ?ray.Sound,
poweroff: ?ray.Sound,
plip: ?ray.Sound,

fn maybe_load_sound(path: [:0]const u8) ?ray.Sound {
    return ray.loadSound(path) catch null;
}

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
    const res_path_abs = try std.fs.path.joinZ(alloc, &.{ exe_path, res_path_rel });

    const startup_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "startup.wav" });
    const blip_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "blip.wav" });
    const poweroff_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "poweroff.wav" });
    const plip_path = try std.fs.path.joinZ(alloc, &.{ res_path_abs, "plip.wav" });

    const startup = maybe_load_sound(startup_path);
    const blip = maybe_load_sound(blip_path);
    const poweroff = maybe_load_sound(poweroff_path);
    const plip = maybe_load_sound(plip_path);

    return Sfx{
        .startup = startup,
        .blip = blip,
        .poweroff = poweroff,
        .plip = plip,
    };
}

pub fn deinit(self: *const Sfx) void {
    if (self.startup) |s| ray.unloadSound(s);
    if (self.blip) |s| ray.unloadSound(s);
    if (self.poweroff) |s| ray.unloadSound(s);
    ray.closeAudioDevice();
}
