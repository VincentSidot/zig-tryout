const std = @import("std");
const r = @import("raylib.zig").c;

const ColorMap = [_]r.Color{
    r.RED,
    r.GREEN,
    r.PURPLE,
    r.YELLOW,
    r.ORANGE,
    r.PINK,
    r.BLUE,
    r.MAGENTA,
};

pub const Ball = struct {
    pos: r.Vector2,
    radius: f32,
    velocity: r.Vector2,
    color: r.Color = r.RED,

    pub fn newRandom() Ball {
        const MIN_RADIUS = 3;
        const MAX_RADIUS = 8;

        const MAX_VELOCITY = 45;
        const MIN_VELOCITY = -MAX_VELOCITY;

        const screen_height = r.GetScreenHeight();
        const screen_width = r.GetScreenWidth();

        const radius = r.GetRandomValue(MIN_RADIUS, MAX_RADIUS);

        const position = r.Vector2{
            .x = @floatFromInt(r.GetRandomValue(0 + radius, screen_width - radius)),
            .y = @floatFromInt(r.GetRandomValue(0 + radius, screen_height - radius)),
        };

        const velocity = r.Vector2{
            .x = @floatFromInt(r.GetRandomValue(MIN_VELOCITY, MAX_VELOCITY)),
            .y = @floatFromInt(r.GetRandomValue(MIN_VELOCITY, MAX_VELOCITY)),
        };

        const color = ColorMap[@intCast(r.GetRandomValue(0, ColorMap.len - 1))];

        return Ball{ .pos = position, .velocity = velocity, .color = color, .radius = @floatFromInt(radius) };
    }

    pub fn render(self: *const Ball) void {
        r.DrawCircleV(self.pos, self.radius, self.color);
    }

    pub fn tick(self: *Ball, dt: f32, tickTime: *f64) void {
        const start = r.GetTime();
        defer {
            const end = r.GetTime();
            tickTime.* += (end - start);
        }

        const screen_height: f32 = @floatFromInt(r.GetScreenHeight());
        const screen_width: f32 = @floatFromInt(r.GetScreenWidth());

        self.pos.x += self.velocity.x * dt;
        self.pos.y += self.velocity.y * dt;

        if (self.pos.x < self.radius) {
            self.pos.x = self.radius;
            self.velocity.x *= -1;
        } else if (self.pos.x > screen_width - self.radius) {
            self.pos.x = screen_width - self.radius;
            self.velocity.x *= -1;
        } else if (self.pos.y < self.radius) {
            self.pos.y = self.radius;
            self.velocity.y *= -1;
        } else if (self.pos.y > screen_height - self.radius) {
            self.pos.y = screen_height - self.radius;
            self.velocity.y *= -1;
        }
    }
};

pub const Balls = std.ArrayList(Ball);
