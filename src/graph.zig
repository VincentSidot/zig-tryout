// graph.zig - Graph visualization module

const std = @import("std");

const math = @import("math.zig");
const r = @import("raylib.zig").c;

const Utils = @import("utils.zig").Utils;
const World = @import("world.zig").World;

fn myFunction(x: f32) f32 {
    return -x; // Example: f(x) = x^2
}

// Example function that will be integrated
fn myRawFunction2(x: f32, y: f32) f32 {
    _ = y;
    return -myFunction(x);
}

var systemRK4: ?SystemType = null;
var systemSimple: ?SystemType = null;
var systemEuler: ?SystemType = null;

const world = World{
    .bounds = r.Rectangle{
        .x = -10,
        .y = -10,
        .width = 20,
        .height = 60,
    },
};

fn computeIntegratedFunctionRK4(x: f32) f32 {
    if (systemRK4 == null) {
        systemRK4 = SystemType.init(
            -10.0,
            10.0,
            0.1,
        );
    }

    return systemRK4.?.get(x, SystemType.System.integrateRK4);
}

fn computeIntegratedFunctionEuler(x: f32) f32 {
    if (systemEuler == null) {
        systemEuler = SystemType.init(
            -10.0,
            10.0,
            0.1,
        );
    }

    return systemEuler.?.get(x, SystemType.System.integrateEuler);
}

fn computeIntegratedFunctionSimple(x: f32) f32 {
    if (systemSimple == null) {
        systemSimple = SystemType.init(
            -10.0,
            10.0,
            0.1,
        );
    }

    return systemSimple.?.get(x, SystemType.System.integrateSimple);
}

pub fn run() !void {
    r.InitWindow(800, 600, "Graph Visualization");
    defer r.CloseWindow();

    r.SetTargetFPS(60);

    while (!r.WindowShouldClose()) {
        if (r.IsKeyPressed(r.KEY_Q) or r.IsKeyPressed(r.KEY_ESCAPE)) {
            break;
        }

        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);

        drawGrid(0.5, r.Color{
            .r = 220,
            .g = 220,
            .b = 220,
            .a = 255,
        });
        drawGrid(1.0, r.Color{
            .r = 180,
            .g = 180,
            .b = 180,
            .a = 255,
        });

        // Draw axes
        world.drawLine(
            r.Vector2{
                .x = world.minX(),
                .y = 0,
            },
            r.Vector2{
                .x = world.maxX(),
                .y = 0,
            },
            r.BLACK,
        );
        world.drawLine(
            r.Vector2{
                .x = 0,
                .y = world.minY(),
            },
            r.Vector2{
                .x = 0,
                .y = world.maxY(),
            },
            r.BLACK,
        );

        drawFunction(
            &myFunction,
            0.1,
            r.RED,
        );

        drawFunction(
            &computeIntegratedFunctionEuler,
            0.1,
            r.GREEN,
        );

        drawFunction(
            &computeIntegratedFunctionSimple,
            0.1,
            r.ORANGE,
        );

        drawFunction(
            &computeIntegratedFunctionRK4,
            0.1,
            r.BLUE,
        );

        r.EndDrawing();
    }

    if (systemRK4 != null) {
        systemRK4.?.deinit();
    }

    if (systemSimple != null) {
        systemSimple.?.deinit();
    }

    if (systemEuler != null) {
        systemEuler.?.deinit();
    }
}

fn printUtils() void {
    Utils.println("Graph module loaded", .{});
    Utils.println("Press Q or ESCAPE to quit", .{});
}

/// Render a mathematical function within the given world bounds.
fn drawFunction(f: *const fn (f32) f32, step: f32, color: r.Color) void {
    var x = world.minX();
    const endX = world.maxX();

    var previousPoint = r.Vector2{
        .x = x,
        .y = f(x),
    };

    x += step;

    while (x <= endX) : (x += step) {
        const y = f(x);

        const currentPoint = r.Vector2{
            .x = x,
            .y = y,
        };

        world.drawLine(previousPoint, currentPoint, color);

        previousPoint = currentPoint;
    }
}

fn drawGrid(spacing: f32, color: r.Color) void {
    var x = world.min().x;
    const endX = world.max().x;

    // Draw vertical lines
    while (x <= endX) : (x += spacing) {
        const start = r.Vector2{
            .x = x,
            .y = world.min().y,
        };
        const end = r.Vector2{
            .x = x,
            .y = world.max().y,
        };

        world.drawLine(start, end, color);
    }

    var y = world.min().y;
    const endY = world.max().y;

    while (y <= endY) : (y += spacing) {
        const start = r.Vector2{
            .x = world.min().x,
            .y = y,
        };
        const end = r.Vector2{
            .x = world.max().x,
            .y = y,
        };
        world.drawLine(start, end, color);
    }
}

const SystemType = struct {
    fn addValue(a: f32, b: f32) f32 {
        return a + b;
    }

    fn scaleValue(v: f32, s: f32) f32 {
        return v * s;
    }

    const System = math.SystemType(
        f32,
        f32,
        void,
        addValue,
        scaleValue,
    );

    system: System,
    step: f32,
    start: f32,
    end: f32,
    computedValues: std.ArrayList(f32),

    const allocator = std.heap.c_allocator;

    fn init(start: f32, end: f32, step: f32) SystemType {
        var s = SystemType{
            .system = System{
                .t = start,
                .x = 50, // Initial value of the integral at start
                .f = myRawFunction2,
            },
            .start = start,
            .end = end,
            .step = step,
            .computedValues = std.ArrayList(f32).empty,
        };
        s.computedValues.append(SystemType.allocator, s.system.x) catch unreachable;

        return s;
    }

    fn deinit(self: *SystemType) void {
        self.computedValues.deinit(SystemType.allocator);
    }

    /// Convert a value between start and end to an index in computed_values
    fn valueToIndex(self: *const SystemType, x: f32) usize {
        const dx = x - self.start;
        if (dx <= 0) return 0;

        const idx_f = dx / self.step;
        const idx: usize = @intFromFloat(@floor(idx_f));
        return idx;
    }

    const IntegrationFnType = fn (ptr: *SystemType.System, f32) void;

    fn computeUpTo(self: *SystemType, idx_target: usize, integrationFn: *const IntegrationFnType) void {
        // We already have at least one sample (at t = start)
        while (self.computedValues.items.len <= idx_target) : (integrationFn(&self.system, self.step)) {
            const y = self.system.x;

            self.computedValues.append(SystemType.allocator, y) catch unreachable;
        }
    }

    fn get(self: *SystemType, x: f32, integrationFn: *const IntegrationFnType) f32 {
        var idx = self.valueToIndex(x);
        // Prevent chasing past the configured end
        const max_idx: usize = @intFromFloat(@floor((self.end - self.start) / self.step));
        if (idx > max_idx) idx = max_idx;

        if (idx >= self.computedValues.items.len) {
            self.computeUpTo(idx, integrationFn);
        }
        return self.computedValues.items[idx];
    }
};
