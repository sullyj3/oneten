const std = @import("std");
const CountdownTimer = @This();

const ns_per_s = std.time.ns_per_s;
const ns_per_ms = std.time.ns_per_ms;

duration_ns: i128,
remaining_ns: i128,
elapsed: bool = false,

pub fn new(duration_ns: i128) CountdownTimer {
    return .{
        .duration_ns = duration_ns,
        .remaining_ns = duration_ns,
        .elapsed = false,
    };
}

pub fn new_ms(duration_ms: i128) CountdownTimer {
    return CountdownTimer.new(duration_ms * ns_per_ms);
}

pub fn new_elapsed_ms(duration_ms: i128) CountdownTimer {
    var timer = CountdownTimer.new(duration_ms * ns_per_ms);
    timer.elapsed = true;
    return timer;
}

pub fn new_s(duration_s: f64) CountdownTimer {
    const ns_f: f64 = duration_s * @as(f64, @floatFromInt(ns_per_s));
    return CountdownTimer.new(@intFromFloat(ns_f));
}

pub fn tick_ns(self: *CountdownTimer, dt_ns: i128) void {
    self.remaining_ns, _ = @subWithOverflow(self.remaining_ns, dt_ns);
    self.elapsed = self.elapsed or self.remaining_ns <= 0;
}

pub fn reset(self: *CountdownTimer) void {
    self.elapsed = false;
    self.remaining_ns = self.duration_ns;
}
