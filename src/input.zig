const ray = @import("raylib");

const State = @import("state.zig").State;
const CountdownTimer = @import("countdown.zig");

// TODO this module should not need these
const Sfx = @import("sfx.zig");

const intvecs = @import("intvecs.zig");
const IVec2 = intvecs.IVec2;

pub fn handle_input(state: *State, sfx: Sfx, dt_ns: i128) error{OutOfMemory}!void {
    state.input_state.tick_ns(dt_ns);
    const input_state = &state.input_state;

    const Key = ray.KeyboardKey;
    if (ray.isKeyPressed(Key.space)) {
        sfx.play(.blip);
        state.grid.toggle_selection();
    }

    if (ray.isKeyPressed(Key.enter) or ray.isKeyPressed(Key.o)) {
        sfx.play(.startup);
        try state.grid.append_step();
        state.grid.move_selection(.{ .y = 1 });
    }
    if (ray.isKeyPressed(Key.backspace) or ray.isKeyPressed(Key.d)) {
        sfx.play(.poweroff);
        state.grid.delete_latest_row();
    }

    if (ray.isKeyPressed(Key.r)) {
        sfx.play(.poweroff);
        try state.grid.reset();
    }

    // TODO create an input actions system. this module should just parse input
    //    into abstract actions, which are then executed in other modules. Then
    //    this module doesn't have to import eg sfx, or implement gameplay logic
    // TODO abstract this timeout logic
    if ((ray.isKeyDown(Key.left) or ray.isKeyDown(Key.h)) and
        input_state.move_left_timeout.elapsed)
    {
        input_state.move_left_timeout.reset();
        state.grid.move_selection(IVec2{ .x = -1, .y = 0 });
        sfx.play(.plip);
    }
    if ((ray.isKeyDown(Key.right) or ray.isKeyDown(Key.l)) and
        input_state.move_right_timeout.elapsed)
    {
        input_state.move_right_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 1, .y = 0 });
        sfx.play(.plip);
    }
    if ((ray.isKeyDown(Key.up) or ray.isKeyDown(Key.k)) and
        input_state.move_up_timeout.elapsed)
    {
        input_state.move_up_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 0, .y = -1 });
        sfx.play(.plip);
    }
    if ((ray.isKeyDown(Key.down) or ray.isKeyDown(Key.j)) and
        input_state.move_down_timeout.elapsed)
    {
        input_state.move_down_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 0, .y = 1 });
        sfx.play(.plip);
    }

    if (ray.isKeyPressed(Key.q)) {
        state.quit = true;
    }
}

pub const InputState = struct {
    // TODO make this start slow and speed up while held
    const move_timeout_ms = 80;

    move_left_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_right_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_up_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_down_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),

    pub fn tick_ns(self: *InputState, dt_ns: i128) void {
        self.move_left_timeout.tick_ns(dt_ns);
        self.move_right_timeout.tick_ns(dt_ns);
        self.move_up_timeout.tick_ns(dt_ns);
        self.move_down_timeout.tick_ns(dt_ns);
    }
};
