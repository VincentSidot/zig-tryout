const std = @import("std");
const r = @import("raylib.zig").c;
const math = @import("math.zig");

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

const ParticleData = struct {
    pos: r.Vector2 = .{ .x = 0, .y = 0 },
    velocity: r.Vector2 = .{ .x = 0, .y = 0 },

    fn add(self: @This(), other: @This()) @This() {
        return @This(){
            // Added fields
            .pos = r.Vector2Add(self.pos, other.pos),
            .velocity = r.Vector2Add(self.velocity, other.velocity),
        };
    }

    fn scale(self: @This(), factor: f32) @This() {
        return @This(){
            // Scaled fields
            .pos = r.Vector2Scale(self.pos, factor),
            .velocity = r.Vector2Scale(self.velocity, factor),
        };
    }
};

const ParticleInfo = struct {
    gravity: *const r.Vector2,
    radius: f32 = 0,
};

const ParticleDataSystem = math.SystemType(f32, ParticleData, ParticleInfo, ParticleData.add, ParticleData.scale);

fn updateParticleSystem(t: f32, data: ParticleData, info: *const ParticleInfo) ParticleData {
    _ = t;
    // Describe how the particle's data changes over time
    // Gravity affects velocity, velocity affects position
    // radius does not change
    return ParticleData{
        .pos = data.velocity,
        .velocity = info.*.gravity.*,
    };
}

fn randomVector2(min: r.Vector2, max: r.Vector2) r.Vector2 {
    return r.Vector2{
        .x = @floatFromInt(r.GetRandomValue(@intFromFloat(min.x), @intFromFloat(max.x))),
        .y = @floatFromInt(r.GetRandomValue(@intFromFloat(min.y), @intFromFloat(max.y))),
    };
}

pub const ParticleConfig = struct {
    min_radius: f32 = 3,
    max_radius: f32 = 8,

    min_velocity: f32 = -45,
    max_velocity: f32 = 45,
};

pub const ParticleInit = struct {
    pos: ?r.Vector2 = null,
    velocity: ?r.Vector2 = null,
    radius: ?f32 = null,
};

pub const Boundary = enum {
    top,
    bottom,
    left,
    right,

    pub fn toString(self: Boundary) []const u8 {
        return switch (self) {
            .top => "top",
            .bottom => "bottom",
            .left => "left",
            .right => "right",
        };
    }
};

pub fn Particle(comptime config: ParticleConfig) type {
    return struct {
        const Self = @This();
        pub const Array: type = std.ArrayList(Self);
        pub const ParticleCollisionType = union(enum) {
            none,
            particle: *const Self,
            boundary: Boundary,

            pub fn debugPrint(self: ParticleCollisionType, ignoreNone: bool) void {
                switch (self) {
                    .none => {
                        if (!ignoreNone) std.debug.print("No collision\n", .{});
                    },
                    .particle => |other| {
                        std.debug.print("Collided with another particle at position: ({d}, {d})\n", .{ other.system.x.pos.x, other.system.x.pos.y });
                    },
                    .boundary => |boundary| {
                        std.debug.print("Collided with boundary: {s}\n", .{boundary.toString()});
                    },
                }
            }
        };

        const MIN_RADIUS = config.min_radius;
        const MAX_RADIUS = config.max_radius;

        const MAX_VELOCITY = config.max_velocity;
        const MIN_VELOCITY = config.min_velocity;

        system: ParticleDataSystem,
        color: r.Color = r.RED,

        /// Create a new Particle with random position and velocity
        ///
        /// # Arguments
        ///
        /// - `gravity`: A pointer to the gravity vector to be used by the particle
        /// - `data`: Optional ParticleInit data to initialize the particle with specific values. If not provided, random values will be used.
        ///
        /// # Returns
        ///
        /// A new Particle instance
        pub fn init(gravity: *const r.Vector2, data: ?ParticleInit) Self {
            var particle_data: ParticleData = .{};
            var particle_info: ParticleInfo = .{
                .gravity = gravity,
            };

            const d = data orelse ParticleInit{};

            if (d.radius) |radius| {
                particle_info.radius = radius;
            } else {
                particle_info.radius = @floatFromInt(r.GetRandomValue(@intFromFloat(MIN_RADIUS), @intFromFloat(MAX_RADIUS)));
            }

            if (d.pos) |pos| {
                particle_data.pos = pos;
            } else {
                const screen_height: f32 = @floatFromInt(r.GetScreenHeight());
                const screen_width: f32 = @floatFromInt(r.GetScreenWidth());

                particle_data.pos = randomVector2(
                    .{ .x = particle_info.radius, .y = particle_info.radius },
                    .{ .x = screen_width - particle_info.radius, .y = screen_height - particle_info.radius },
                );
            }

            if (d.velocity) |velocity| {
                particle_data.velocity = velocity;
            } else {
                particle_data.velocity = randomVector2(
                    .{ .x = MIN_VELOCITY, .y = MIN_VELOCITY },
                    .{ .x = MAX_VELOCITY, .y = MAX_VELOCITY },
                );
            }

            return Self{
                .system = ParticleDataSystem{
                    .f = updateParticleSystem,
                    .t = 0,
                    .x = particle_data,
                    .info = particle_info,
                },
                .color = ColorMap[@intCast(r.GetRandomValue(0, ColorMap.len - 1))],
            };
        }

        pub fn deinit(self: *Self) void {
            _ = self;
            // No dynamic resources to free for now
        }

        pub fn render(self: *const Self) void {
            r.DrawCircleV(self.system.x.pos, self.system.info.radius, self.color);
        }

        fn clampPosition(self: *Self) Self.ParticleCollisionType {
            const screen_height: f32 = @floatFromInt(r.GetScreenHeight());
            const screen_width: f32 = @floatFromInt(r.GetScreenWidth());

            const radius = self.system.info.radius;

            if (self.system.x.pos.x < radius) {
                self.system.x.pos.x = radius;
                return Self.ParticleCollisionType{
                    .boundary = .left,
                };
            } else if (self.system.x.pos.x > screen_width - radius) {
                self.system.x.pos.x = screen_width - radius;
                return Self.ParticleCollisionType{
                    .boundary = .right,
                };
            }

            if (self.system.x.pos.y < radius) {
                self.system.x.pos.y = radius;
                return Self.ParticleCollisionType{
                    .boundary = .top,
                };
            } else if (self.system.x.pos.y > screen_height - radius) {
                self.system.x.pos.y = screen_height - radius;
                return Self.ParticleCollisionType{
                    .boundary = .bottom,
                };
            }

            return Self.ParticleCollisionType{ .none = {} };
        }

        /// Handle collision with another particle or boundary
        pub fn handleCollision(self: *Self, col: Self.ParticleCollisionType) void {
            switch (col) {
                .none => {},
                .particle => |other| {
                    // Simple elastic collision response
                    _ = other;
                },
                .boundary => |boundary| {
                    switch (boundary) {
                        .top, .bottom => {
                            self.system.x.velocity.y = -self.system.x.velocity.y;
                        },
                        .left, .right => {
                            self.system.x.velocity.x = -self.system.x.velocity.x;
                        },
                    }
                },
            }
        }

        pub fn debugPrint(self: *const Self) void {
            std.debug.print("Particle at position: ({d}, {d}) with velocity: ({d}, {d}) and radius: {d}\n", .{ self.system.x.pos.x, self.system.x.pos.y, self.system.x.velocity.x, self.system.x.velocity.y, self.system.info.radius });
        }

        pub fn tick(self: *Self, dt: f32, tickTime: *f64) Self.ParticleCollisionType {
            const start = r.GetTime();
            defer {
                const end = r.GetTime();
                tickTime.* += (end - start);
            }

            self.system.integrate(dt);

            const collision = self.clampPosition();
            collision.debugPrint(true);

            return collision;
        }
    };
}
