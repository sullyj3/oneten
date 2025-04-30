const ray = @import("raylib");

const State = @import("state.zig").State;

const intvecs = @import("intvecs.zig");

const OneTenGrid = @import("grid.zig").OneTenGrid;

const UVec2 = intvecs.UVec2;
const IVec2 = intvecs.IVec2;

pub const WIN_WIDTH = 1080;
pub const WIN_HEIGHT = 720;

const GRID_PADDING = 20;
const WIN_PADDING = 20;

const CELL_SIDE = 35;
const CELL_GAP = 4;
const CELL_BORDER_WIDTH = 2;

const BG_COLOR = ray.Color.sky_blue;
const FG_COLOR = ray.Color.dark_blue;
const SEL_COLOR = ray.Color.green;

fn draw_cell(on: bool, x: i32, y: i32) void {
    const rect: ray.Rectangle = .{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = CELL_SIDE,
        .height = CELL_SIDE,
    };

    if (on) {
        ray.drawRectangleRec(rect, FG_COLOR);
    } else {
        ray.drawRectangleLinesEx(rect, CELL_BORDER_WIDTH, FG_COLOR);
    }
}

fn cell_screenspace_dimensions(cell_space_dims: struct { usize, usize }) UVec2 {
    const cs_width, const cs_height = cell_space_dims;
    const row_width: u32 = @truncate(cs_width);
    const n_rows_u: u32 = @truncate(cs_height);

    const width: u32 = row_width * CELL_SIDE + (row_width - 1) * CELL_GAP;
    const height: u32 = n_rows_u * CELL_SIDE + (n_rows_u - 1) * CELL_GAP;

    return .{
        .x = width,
        .y = height,
    };
}

fn draw_cell_row(cell_states: []bool, x: i32, y: i32) void {
    var x_offs: i32 = 0;
    for (cell_states) |cell| {
        draw_cell(cell, x + x_offs, y);
        x_offs += CELL_SIDE + CELL_GAP;
    }
}

fn top_left_from_center(center: IVec2, dimensions: UVec2) IVec2 {
    const half_width: i32 = @intCast(dimensions.x / 2);
    const half_height: i32 = @intCast(dimensions.y / 2);
    return .{
        .x = center.x - half_width,
        .y = center.y - half_height,
    };
}

fn draw_oneten_grid(grid: OneTenGrid) void {
    // todo get a proper layout algorithm this is already a bit fucked
    const win_center = IVec2{ .x = WIN_WIDTH / 2, .y = WIN_HEIGHT / 2 };
    const cells_dims = cell_screenspace_dimensions(grid.cellspace_dimensions());
    const border_dims = border_dimensions(cells_dims);
    var cells_pos = top_left_from_center(win_center, cells_dims);
    var border_pos = cells_pos.minus(.{ .x = GRID_PADDING, .y = GRID_PADDING });
    const border_max_y: i32 = WIN_HEIGHT - WIN_PADDING - @as(i32, @intCast(border_dims.y));
    border_pos.y = @min(border_pos.y, border_max_y);
    cells_pos.y = border_pos.y + GRID_PADDING;
    draw_grid_bg(border_pos, border_dims);
    for (grid.rows.items, 0..) |row, i| {
        const y_offs: i32 = @intCast(i * (CELL_SIDE + CELL_GAP));
        draw_cell_row(row, cells_pos.x, cells_pos.y + y_offs);
    }

    // draw selection
    const sel = (IVec2{
        .x = cells_pos.x,
        .y = cells_pos.y,
    }).plusU(cell_to_screen_offset(grid.selection));
    const rect: ray.Rectangle = .{
        .x = @floatFromInt(sel.x),
        .y = @floatFromInt(sel.y),
        .width = CELL_SIDE,
        .height = CELL_SIDE,
    };

    ray.drawRectangleLinesEx(rect, CELL_BORDER_WIDTH, SEL_COLOR);
}

pub fn draw(state: State) void {
    ray.beginDrawing();
    defer ray.endDrawing();
    ray.clearBackground(BG_COLOR);
    draw_oneten_grid(state.grid);
    ray.drawFPS(20, 20);
}

fn cell_to_screen_offset(cell: UVec2) UVec2 {
    return cell.mul_pointwise(.{
        .x = CELL_SIDE + CELL_GAP,
        .y = CELL_SIDE + CELL_GAP,
    });
}

fn border_dimensions(cell_dimensions: UVec2) UVec2 {
    return cell_dimensions.plus(.{
        .x = 2 * GRID_PADDING,
        .y = 2 * GRID_PADDING,
    });
}

fn draw_grid_bg(position: IVec2, dimensions: UVec2) void {
    const GRID_BORDER_THICKNESS = 5;
    const rect: ray.Rectangle = .{
        .x = @floatFromInt(position.x),
        .y = @floatFromInt(position.y),
        .width = @floatFromInt(dimensions.x),
        .height = @floatFromInt(dimensions.y),
    };
    ray.drawRectangleLinesEx(rect, GRID_BORDER_THICKNESS, FG_COLOR);
}
