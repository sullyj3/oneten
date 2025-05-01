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

    var sounds = std.EnumArray(SoundId, ray.Sound).initUndefined();
    inline for (std.meta.fields(SoundId)) |field| {
        const extension = ".wav";
        const filename_buf = try fba_alloc.alloc(u8, field.name.len + extension.len);
        const filename = try std.fmt.bufPrint(filename_buf, "{s}{s}", .{ field.name, extension });
        const filepath = try std.fs.path.joinZ(fba_alloc, &.{ res_dir, filename });
        const sound = try ray.loadSound(filepath);
        sounds.set(@enumFromInt(field.value), sound);
        fba.reset();
    }

    return Sfx{
        .sounds = sounds,
    };
}

pub fn deinit(self: *const Sfx) void {
    for (self.sounds.values) |s| ray.unloadSound(s);
    ray.closeAudioDevice();
}
