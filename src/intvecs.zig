pub const UVec2 = struct {
    x: u32,
    y: u32,

    pub fn mul_pointwise(self: UVec2, other: UVec2) UVec2 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    pub fn plus(self: UVec2, other: UVec2) UVec2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }
};

pub const IVec2 = struct {
    x: i32 = 0,
    y: i32 = 0,

    pub fn mul_pointwise(self: IVec2, other: IVec2) IVec2 {
        return .{ .x = self.x * other.x, .y = self.y * other.y };
    }

    pub fn plus(self: IVec2, other: IVec2) IVec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn minus(self: IVec2, other: IVec2) IVec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn plusU(self: IVec2, other: UVec2) IVec2 {
        return .{
            .x = self.x + @as(i32, @intCast(other.x)),
            .y = self.y + @as(i32, @intCast(other.y)),
        };
    }
};
