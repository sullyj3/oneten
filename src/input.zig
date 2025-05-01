const std = @import("std");
const ray = @import("raylib");

const State = @import("state.zig").State;
const CountdownTimer = @import("countdown.zig");

// TODO this module should not need these
const Sfx = @import("sfx.zig");

const intvecs = @import("intvecs.zig");
const IVec2 = intvecs.IVec2;

const Allocator = std.mem.Allocator;
const EnumArray = std.enums.EnumArray;
const Key = ray.KeyboardKey;

const Action = enum {
    toggle,
    move_up,
    move_down,
    move_left,
    move_right,
    delete_last_row,
    step_simulation,
    reset,
    quit,
};

const ActionState = struct {
    pressed: bool = false,
    down: bool = false,
    released: bool = false,
};

const Bindings = EnumArray(Action, []const Key);
const bindings: Bindings = Bindings.init(.{
    .toggle = &.{.space},
    .step_simulation = &.{ .enter, .o },
    .delete_last_row = &.{ .backspace, .d },
    .reset = &.{.r},

    .move_left = &.{ .left, .h },
    .move_right = &.{ .right, .l },
    .move_up = &.{ .up, .k },
    .move_down = &.{ .down, .j },

    .quit = &.{.q},
});

const ActionStates = struct {
    action_states: EnumArray(Action, ActionState) =
        EnumArray(Action, ActionState).initFill(.{}),

    fn update_action_states(self: *ActionStates) void {
        inline for (std.meta.fields(Action)) |field| {
            const action: Action = @enumFromInt(field.value);
            const keys = bindings.get(action);
            var new_state: ActionState = .{};

            for (keys) |key| {
                new_state.pressed = new_state.pressed or ray.isKeyPressed(key);
                new_state.down = new_state.down or ray.isKeyDown(key);
                new_state.released = new_state.released or ray.isKeyReleased(key);
            }

            self.action_states.set(action, new_state);
        }
    }

    fn pressed(self: ActionStates, action: Action) bool {
        return self.action_states.get(action).pressed;
    }

    fn down(self: ActionStates, action: Action) bool {
        return self.action_states.get(action).down;
    }

    fn released(self: ActionStates, action: Action) bool {
        return self.action_states.get(action).released;
    }
};

pub fn handle_input(state: *State, sfx: Sfx, dt_ns: i128) error{OutOfMemory}!void {
    state.input_state.tick_ns(dt_ns);
    const input_state = &state.input_state;
    const action_states: *ActionStates = &input_state.action_states;
    action_states.update_action_states();

    if (action_states.pressed(.toggle)) {
        sfx.play(.blip);
        state.grid.toggle_selection();
    }

    if (action_states.pressed(.step_simulation)) {
        sfx.play(.startup);
        try state.grid.append_step();
        state.grid.move_selection(.{ .y = 1 });
    }
    if (action_states.pressed(.delete_last_row)) {
        sfx.play(.poweroff);
        state.grid.delete_latest_row();
    }

    if (action_states.pressed(.reset)) {
        sfx.play(.poweroff);
        try state.grid.reset();
    }

    // TODO abstract this timeout logic
    if (action_states.down(.move_left) and
        input_state.move_left_timeout.elapsed)
    {
        input_state.move_left_timeout.reset();
        state.grid.move_selection(IVec2{ .x = -1, .y = 0 });
        sfx.play(.plip);
    }
    if (action_states.down(.move_right) and
        input_state.move_right_timeout.elapsed)
    {
        input_state.move_right_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 1, .y = 0 });
        sfx.play(.plip);
    }
    if (action_states.down(.move_up) and
        input_state.move_up_timeout.elapsed)
    {
        input_state.move_up_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 0, .y = -1 });
        sfx.play(.plip);
    }
    if (action_states.down(.move_down) and
        input_state.move_down_timeout.elapsed)
    {
        input_state.move_down_timeout.reset();
        state.grid.move_selection(IVec2{ .x = 0, .y = 1 });
        sfx.play(.plip);
    }

    state.quit = action_states.pressed(.quit);
}

pub const InputState = struct {
    // TODO make this start slow and speed up while held
    const move_timeout_ms = 80;

    move_left_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_right_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_up_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),
    move_down_timeout: CountdownTimer = CountdownTimer.new_elapsed_ms(move_timeout_ms),

    action_states: ActionStates = .{},

    pub fn tick_ns(self: *InputState, dt_ns: i128) void {
        self.move_left_timeout.tick_ns(dt_ns);
        self.move_right_timeout.tick_ns(dt_ns);
        self.move_up_timeout.tick_ns(dt_ns);
        self.move_down_timeout.tick_ns(dt_ns);
    }
};
