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
};

const Balls = std.ArrayList(Ball);

const State = struct {
    balls: Balls,
    lastFrameTime: f64,
};

const INIT_BALL_COUNT = 60;

fn randomBall() Ball {
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

fn renderBall(ball: *const Ball) void {
    r.DrawCircleV(ball.pos, ball.radius, ball.color);
}

fn tickBall(ball: *Ball, dt: f32) void {
    const screen_height: f32 = @floatFromInt(r.GetScreenHeight());
    const screen_width: f32 = @floatFromInt(r.GetScreenWidth());

    ball.pos.x += ball.velocity.x * dt;
    ball.pos.y += ball.velocity.y * dt;

    if (ball.pos.x < 0 or ball.pos.x >= screen_width) {
        ball.velocity.x *= -1;
    } else if (ball.pos.y < 0 or ball.pos.y >= screen_height) {
        ball.velocity.y *= -1;
    }
}

fn renderState(state: *State) void {
    const time = r.GetTime();
    const dt: f32 = @floatCast(time - state.lastFrameTime);
    state.lastFrameTime = time;
    for (state.balls.items) |*ball| {
        tickBall(ball, dt);
        renderBall(ball);
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    r.SetRandomSeed(42069);

    r.InitWindow(800, 600, "Hello World");

    var state = State{ .balls = Balls.empty, .lastFrameTime = 0.0 };

    var i: u8 = 0;
    while (i <= INIT_BALL_COUNT) : (i += 1) {
        try state.balls.append(allocator, randomBall());
    }

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();

        r.ClearBackground(r.Color{
            .r = 0x19,
            .g = 0x19,
            .b = 0x19,
            .a = 0xFF,
        });

        renderState(&state);

        r.EndDrawing();
    }
}
