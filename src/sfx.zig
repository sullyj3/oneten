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

pub fn init(res_dir: []const u8) !Sfx {
    ray.initAudioDevice();
    var buf: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const fba_alloc = fba.allocator();

    const startup_path = try std.fs.path.joinZ(fba_alloc, &.{ res_dir, "startup.wav" });
    const startup = try ray.loadSound(startup_path);
    fba.reset();

    const blip_path = try std.fs.path.joinZ(fba_alloc, &.{ res_dir, "blip.wav" });
    const blip = try ray.loadSound(blip_path);
    fba.reset();

    const poweroff_path = try std.fs.path.joinZ(fba_alloc, &.{ res_dir, "poweroff.wav" });
    const poweroff = try ray.loadSound(poweroff_path);
    fba.reset();

    const plip_path = try std.fs.path.joinZ(fba_alloc, &.{ res_dir, "plip.wav" });
    const plip = try ray.loadSound(plip_path);
    fba.reset();

    return Sfx{
        .sounds = std.EnumArray(SoundId, ray.Sound).init(.{
            .startup = startup,
            .blip = blip,
            .poweroff = poweroff,
            .plip = plip,
        }),
    };
}

pub fn deinit(self: *const Sfx) void {
    for (self.sounds.values) |s| ray.unloadSound(s);
    ray.closeAudioDevice();
}
