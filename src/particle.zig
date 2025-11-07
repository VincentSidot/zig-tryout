const std = @import("std");
const r = @import("raylib.zig").c;
const math = @import("math.zig");

const World = @import("world.zig").World;

const Random = struct {
    fn random() std.Random {
        const state = struct {
            var prng = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
                break :blk seed;
            });

            const rand = prng.random();
        };

        return state.rand;
    }

    pub fn randomFloat(min: f32, max: f32) f32 {
        return Random.random().float(f32) * (max - min) + min;
    }

    pub fn randomVector2(min: r.Vector2, max: r.Vector2) r.Vector2 {
        return r.Vector2{
            .x = Random.random().randomFloat(min.x, max.x),
            .y = Random.random().randomFloat(min.y, max.y),
        };
    }
};

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
    mass: f32 = 1, // kg
    linear_drag: f32 = 0, // k in N*s/m (set > 0 to enable drag)
    quad_drag_coeff: f32 = 0, // c in N*s^2/m^2 (set > 0 to enable quadratic drag)
};

const ParticleDataSystem = math.SystemType(f32, ParticleData, ParticleInfo, ParticleData.add, ParticleData.scale);

fn updateParticleSystem(t: f32, data: ParticleData, info: *const ParticleInfo) ParticleData {
    _ = t;
    // Describe how the particle's data changes over time
    // Gravity affects velocity, velocity affects position
    // radius does not change

    var acc = info.gravity.*;

    if (info.linear_drag != 0) {
        const k_over_m = info.linear_drag / info.mass;
        const lin = r.Vector2Scale(data.velocity, k_over_m); // F_drag = -k*v  => a_drag = F_drag/m = - (k/m)*v
        acc = r.Vector2Subtract(acc, lin);
    }

    if (info.quad_drag_coeff != 0) {
        const speed = r.Vector2Length(data.velocity);
        const quad = r.Vector2Scale(data.velocity, (info.quad_drag_coeff * speed) / info.mass); // F_drag = -c*v*|v| => a_drag = F_drag/m = - (c/m)*v*|v|
        acc = r.Vector2Subtract(acc, quad);
    }

    return ParticleData{
        .pos = data.velocity, // d(pos)/dt
        .velocity = acc, // d(vel)/dt
    };
}

pub const ParticleConfig = struct {
    min_radius: f32 = 0.25,
    max_radius: f32 = 1.0,

    min_velocity: f32 = -5.0,
    max_velocity: f32 = 5.0,
};

/// A Particle in the simulation
///
/// All units are in pixels space (for position) and pixels per second (for velocity)
pub const ParticleInit = struct {
    /// Position of the particle (on screen)
    pos: ?r.Vector2 = null,
    /// Initial velocity of the particle (in pixels per second)
    velocity: ?r.Vector2 = null,
    /// Radius of the particle (in pixels)
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
            boundary: World.Direction,
        };

        const MIN_RADIUS = config.min_radius;
        const MAX_RADIUS = config.max_radius;

        const MAX_VELOCITY = config.max_velocity;
        const MIN_VELOCITY = config.min_velocity;

        // Fields
        system: ParticleDataSystem,
        selected: bool = false,
        world: *const World,

        // Colors
        const selectedColor: r.Color = r.RED;
        const unselectedColor: r.Color = r.BLUE;

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
        pub fn init(world: *const World, gravity: *const r.Vector2, data: ?ParticleInit) Self {
            var particle_data: ParticleData = .{};
            var particle_info: ParticleInfo = .{
                .gravity = gravity,
            };

            const d = data orelse ParticleInit{};

            if (d.radius) |radius| {
                // Convert radius from pixels to world units (choseen arbitrarily to work on width)
                particle_info.radius = world.distanceFromPixelToWorld(radius, true);
            } else {
                particle_info.radius = Random.randomFloat(Self.MIN_RADIUS, Self.MAX_RADIUS);
            }

            if (d.pos) |pos| {
                particle_data.pos = pos;
            } else {
                particle_data.pos = Random.randomVector2(
                    r.Vector2Add(world.min(), .{ .x = particle_info.radius, .y = particle_info.radius }),
                    r.Vector2Subtract(world.max(), .{ .x = particle_info.radius, .y = particle_info.radius }),
                );
            }

            if (d.velocity) |velocity| {
                // Convert velocity from pixels to world units (choseen arbitrarily to work on width)
                particle_data.velocity = world.vectorFromWorldToPixels(velocity);
            } else {
                particle_data.velocity = Random.randomVector2(
                    .{ .x = Self.MIN_VELOCITY, .y = Self.MIN_VELOCITY },
                    .{ .x = Self.MAX_VELOCITY, .y = Self.MAX_VELOCITY },
                );
            }

            // const rho: f32 = 1.225; // air density ~ kg/m^3
            // const Cd: f32 = 0.47; // sphere
            // const area = std.math.pi * particle_info.radius * particle_info.radius;

            // particle_info.quad_drag_coeff = 0.5 * rho * Cd * area;
            particle_info.linear_drag = 0.1; // Example linear drag coefficient

            particle_info.mass = (4.0 / 3.0) * std.math.pi * std.math.pow(f32, particle_info.radius, 3) * 0.001; // assuming density of 1000 kg/m^3

            return Self{
                .system = ParticleDataSystem{
                    .f = updateParticleSystem,
                    .t = 0,
                    .x = particle_data,
                    .info = particle_info,
                },
                .world = world,
            };
        }

        pub fn deinit(self: *Self) void {
            _ = self;
            // No dynamic resources to free for now
        }

        inline fn renderVelocity(self: *const Self) void {
            const start_pos = self.system.x.pos;
            const end_pos = r.Vector2Add(start_pos, self.system.x.velocity);

            self.world.drawLine(start_pos, end_pos, r.GREEN);
        }

        pub fn render(self: *const Self, shouldRenderVelocity: bool) void {
            const color = if (self.selected) Self.selectedColor else Self.unselectedColor;

            self.world.drawCircle(self.system.x.pos, self.system.info.radius, color);

            if (shouldRenderVelocity) {
                self.renderVelocity();
            }
        }

        fn clampPosition(self: *Self) Self.ParticleCollisionType {
            const collision = self.world.collisionBall(self.system.x.pos, self.system.info.radius);

            if (collision.bits() != 0) {
                return Self.ParticleCollisionType{ .boundary = collision };
            } else {
                return Self.ParticleCollisionType{ .none = {} };
            }
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
                    if (boundary.north or boundary.south) {
                        self.system.x.velocity.y = -self.system.x.velocity.y;
                    }
                    if (boundary.east or boundary.west) {
                        self.system.x.velocity.x = -self.system.x.velocity.x;
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
            // collision.debugPrint(true);

            return collision;
        }
    };
}
