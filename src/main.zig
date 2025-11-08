const std = @import("std");
const r = @import("raylib.zig").c;
const stateZig = @import("state.zig");
const particle = @import("particle.zig");
const Utils = @import("utils.zig").Utils;

const State = stateZig.State;

const Constants = struct {
    const window_width: c_int = 800;
    const window_height: c_int = 800;
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    r.SetRandomSeed(42069);

    r.InitWindow(Constants.window_width, Constants.window_height, "Hello World");
    defer r.CloseWindow();

    r.SetTargetFPS(120);

    var state = try State.init(allocator, null);
    defer state.deinit();

    Utils.print("Press LEFT MOUSE BUTTON to add particles\n", .{});
    Utils.print("Press U to remove the last particle\n", .{});
    Utils.print("Press V to toggle velocity rendering\n", .{});
    Utils.print("Press P to pause/resume particle updates\n", .{});
    Utils.print("Press Q or ESCAPE to quit\n", .{});

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

        if (r.IsKeyPressed(r.KEY_V)) {
            state.toggleRenderVelocity();
        }

        if (r.IsKeyPressed(r.KEY_P)) {
            state.toggleUpdateParticles();
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
