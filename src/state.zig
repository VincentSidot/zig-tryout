const std = @import("std");
const r = @import("raylib.zig").c;
const particleZig = @import("particle.zig");

const World = @import("world.zig").World;
const Particle = particleZig.Particle(.{});
pub const ParticleConfig = particleZig.ParticleInit;

pub const State = struct {
    particles: Particle.Array = Particle.Array.empty,

    // Time information
    lastFrameTime: f64,
    lastTickTime: f64 = 0,

    // Simulation parameters
    gravity: r.Vector2 = r.Vector2{ .x = 0, .y = 9.81 },

    // Control flags
    shouldRenderVelocity: bool = false,
    shouldUpdateParticles: bool = true,

    // World
    world: World = .{},

    // Allocator
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, world: ?r.Rectangle) !State {
        var state = State{
            .allocator = allocator,
            .lastFrameTime = r.GetTime(),
        };

        if (world) |w| {
            state.world = .{
                .bounds = w,
            };
        }

        return state;
    }

    pub fn deinit(self: *State) void {
        for (self.particles.items) |*particle| {
            particle.deinit();
        }
        self.particles.deinit(self.allocator);
    }

    pub fn toggleRenderVelocity(self: *State) void {
        self.shouldRenderVelocity = !self.shouldRenderVelocity;
    }

    pub fn toggleUpdateParticles(self: *State) void {
        self.shouldUpdateParticles = !self.shouldUpdateParticles;
    }

    pub fn addParticle(self: *State, data: ?ParticleConfig) !void {
        const particle = Particle.init(&self.world, &self.gravity, data);

        std.debug.print("Added particle at position: ({d}, {d})\n", .{ particle.system.x.pos.x, particle.system.x.pos.y });

        try self.particles.append(self.allocator, particle);
    }

    pub fn popParticle(self: *State) void {
        var maybeParticle = self.particles.pop();

        if (maybeParticle) |*particle| {
            particle.deinit();
        }
    }

    fn renderParticles(self: *State) void {
        const time = r.GetTime();
        const dt: f32 = @floatCast(time - self.lastFrameTime);
        self.lastFrameTime = time;

        var tickTime: f64 = 0;
        defer self.lastTickTime = tickTime;

        for (self.particles.items) |*particle| {
            if (self.shouldUpdateParticles) {
                const collision = particle.tick(dt, &tickTime);
                particle.handleCollision(collision);
            }
            particle.render(self.shouldRenderVelocity);
        }
    }

    fn renderText(self: *State) void {
        var buf: [255]u8 = undefined;
        var base_y: c_int = 10;

        if (self.particles.items.len > 0) {
            const first_particle = &self.particles.items[0];
            writeText(&buf, "Time: {d:.2} s", .{first_particle.system.t}, &base_y);
        }

        writeText(&buf, "Particle count: {d}", .{self.particles.items.len}, &base_y);
        writeText(&buf, "FPS: {d}", .{@as(i32, r.GetFPS())}, &base_y);
        writeText(&buf, "Last Tick Time (ms): {d:.2}", .{(self.lastTickTime * 1000)}, &base_y);
    }

    pub fn render(self: *State) void {
        self.renderParticles();
        self.renderText();
    }
};

fn writeText(buf: []u8, comptime fmt: []const u8, args: anytype, base_y: *c_int) void {
    const base_x = 10;
    const font_size = 20;

    const fmt_fix = fmt ++ "\x00";

    if (std.fmt.bufPrint(buf, fmt_fix, args)) |_| {
        r.DrawText(@ptrCast(buf), base_x, base_y.*, font_size, r.RAYWHITE);
        base_y.* += font_size + 5;
    } else |_| {
        // Ignore formatting errors
    }
}
