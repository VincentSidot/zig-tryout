const std = @import("std");
const r = @import("raylib.zig").c;
const render = @import("render.zig");

const Balls = render.Balls;
const Ball = render.Ball;

pub const State = struct {
    balls: Balls = Balls.empty,

    // Time information
    lastFrameTime: f64,
    lastTickTime: f64 = 0,

    // Simulation parameters
    gravity: r.Vector2 = r.Vector2{ .x = 0, .y = 9.81 },

    // Allocator
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !State {
        return State{
            .allocator = allocator,
            .lastFrameTime = r.GetTime(),
        };
    }

    pub fn addBall(self: *State, ball: Ball) !void {
        try self.balls.append(self.allocator, ball);
    }

    pub fn deinit(self: *State) void {
        self.balls.deinit(self.allocator);
    }

    fn renderBalls(self: *State) void {
        const time = r.GetTime();
        const dt: f32 = @floatCast(time - self.lastFrameTime);
        self.lastFrameTime = time;

        var tickTime: f64 = 0;
        defer self.lastTickTime = tickTime;

        for (self.balls.items) |*ball| {
            ball.tick(dt, &tickTime);
            ball.render();
        }
    }

    fn renderText(self: *State) void {
        var buf: [255]u8 = undefined;

        const base_x = 10;
        var base_y: c_int = 10;
        const font_size = 20;

        if (std.fmt.bufPrint(&buf, "Ball count: {d}\x00", .{self.balls.items.len})) |_| {
            r.DrawText(&buf, base_x, base_y, font_size, r.RAYWHITE);
            base_y += font_size + 5;
        } else |_| {
            // Ignore formatting errors
        }

        if (std.fmt.bufPrint(&buf, "FPS: {d}\x00", .{@as(i32, r.GetFPS())})) |_| {
            r.DrawText(&buf, base_x, base_y, font_size, r.RAYWHITE);
            base_y += font_size + 5;
        } else |_| {
            // Ignore formatting errors
        }

        if (std.fmt.bufPrint(&buf, "Last Tick Time (ms): {d:.2}\x00", .{(self.lastTickTime * 1000)})) |_| {
            r.DrawText(&buf, base_x, base_y, font_size, r.RAYWHITE);
        } else |_| {
            // Ignore formatting errors
        }
    }

    pub fn render(self: *State) void {
        self.renderBalls();
        self.renderText();
    }
};
