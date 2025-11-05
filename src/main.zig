const std = @import("std");
const r = @import("raylib.zig").c;
const stateZig = @import("state.zig");
const render = @import("render.zig");

const State = stateZig.State;
const Ball = render.Ball;

const INIT_BALL_COUNT = 60;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

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
        if (r.IsKeyPressed(r.KEY_Q) or r.IsKeyPressed(r.KEY_ESCAPE)) {
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
