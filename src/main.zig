const std = @import("std");
const r = @import("raylib.zig").c;
const stateZig = @import("state.zig");
const particle = @import("particle.zig");

const State = stateZig.State;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    r.SetRandomSeed(42069);

    r.InitWindow(800, 600, "Hello World");
    defer r.CloseWindow();

    var state = try State.init(allocator);
    defer state.deinit();

    while (!r.WindowShouldClose()) {
        if (r.IsKeyPressed(r.KEY_Q) or r.IsKeyPressed(r.KEY_ESCAPE)) {
            // End simulation
            break;
        }

        if (r.IsKeyPressed(r.KEY_U)) {
            // Remove last particle
            state.popParticle();
        }

        if (r.IsMouseButtonPressed(r.MOUSE_LEFT_BUTTON)) {
            // Add a particle at mouse position
            const mousePos = r.GetMousePosition();
            try state.addParticle(.{ .pos = mousePos, .velocity = .{} });
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
