const std = @import("std");
const r = @import("raylib.zig").Raylib;

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

const Ball = struct {
    pos: r.Vector2,
    radius: f32,
    velocity: r.Vector2,
    color: r.Color = r.RED,

    fn newRandom() Ball {
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

    fn render(self: *const Ball) void {
        r.DrawCircleV(self.pos, self.radius, self.color);
    }

    fn tick(self: *Ball, dt: f32) void {
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

const Balls = std.ArrayList(Ball);

const State = struct {
    balls: Balls,
    lastFrameTime: f64,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) !State {
        return State{
            .balls = Balls.empty,
            .lastFrameTime = 0,
            .allocator = allocator,
        };
    }

    fn addBall(self: *State, ball: Ball) !void {
        try self.balls.append(self.allocator, ball);
    }

    fn deinit(self: *State) void {
        self.balls.deinit(self.allocator);
    }

    fn render(self: *State) void {
        // Placeholder for potential future state rendering logic

        const time = r.GetTime();
        const dt: f32 = @floatCast(time - self.lastFrameTime);
        self.lastFrameTime = time;
        for (self.balls.items) |*ball| {
            ball.tick(dt);
            ball.render();
        }
    }
};

const INIT_BALL_COUNT = 60;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    r.SetRandomSeed(42069);

    r.InitWindow(800, 600, "Hello World");
    defer r.CloseWindow();

    var state = try State.init(allocator);
    defer state.deinit();

    var i: u8 = 0;
    while (i < INIT_BALL_COUNT) : (i += 1) {
        try state.addBall(Ball.newRandom());
    }

    while (!r.WindowShouldClose()) {
        if (r.IsKeyPressed(r.KEY_A) or r.IsKeyPressed(r.KEY_ESCAPE)) {
            // End simulation
            break;
        }

        r.BeginDrawing();

        r.ClearBackground(r.Color{
            .r = 0x19,
            .g = 0x19,
            .b = 0x19,
            .a = 0xFF,
        });

        state.render();

        r.EndDrawing();
    }
}
