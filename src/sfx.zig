const std = @import("std");
const ray = @import("raylib");

const Sfx = @This();

pub const SoundId = enum {
    startup,
    blip,
    poweroff,
};

startup: ?ray.Sound,
blip: ?ray.Sound,
poweroff: ?ray.Sound,

fn maybe_load_sound(path: [:0]const u8) ?ray.Sound {
    return ray.loadSound(path) catch null;
}

pub fn get_sound_by_id(self: Sfx, sound_id: SoundId) ?ray.Sound {
    return switch (sound_id) {
        .startup => self.startup,
        .blip => self.blip,
        .poweroff => self.poweroff,
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

pub fn init() Sfx {
    ray.initAudioDevice();

    const startup = maybe_load_sound("res/startup.wav");
    const blip = maybe_load_sound("res/blip.wav");
    const poweroff = maybe_load_sound("res/poweroff.wav");
    return Sfx{
        .startup = startup,
        .blip = blip,
        .poweroff = poweroff,
    };
}

pub fn deinit(self: *const Sfx) void {
    if (self.startup) |s| ray.unloadSound(s);
    if (self.blip) |s| ray.unloadSound(s);
    if (self.poweroff) |s| ray.unloadSound(s);
    ray.closeAudioDevice();
}
