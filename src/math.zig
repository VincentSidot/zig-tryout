pub fn DataType(
    comptime valueType: type,
    comptime addValue: fn (valueType, valueType) valueType,
    comptime valueProduct: fn (valueType, f64) valueType,
) type {
    return struct {
        const value: type = valueType;

        pub fn add(self: value, other: value) value {
            return addValue(self, other);
        }

        pub fn scale(self: value, factor: f64) value {
            return valueProduct(self, factor);
        }
    };
}

pub fn SystemType(comptime T: type) type {
    comptime {
        if (!@hasDecl(T, "value"))
            @compileError("Type T must conform to DataType interface (missing type decls)");

        if (!@hasDecl(T, "add") or !@hasDecl(T, "scale"))
            @compileError("Type T must conform to DataType interface (missing function decls)");

        // Optional: verify exact signatures
        if (@TypeOf(T.add) != fn (T.value, T.value) T.value)
            @compileError("T.add must be fn (T.value, T.value) T.value");
        if (@TypeOf(T.scale) != fn (T.value, f64) T.value)
            @compileError("T.scale must be fn (T.value, f64) T.value");
    }

    return struct {
        t: f64,
        x: T.value,
        f: *const fn (t: f64, x: T.value) T.value,

        /// Integrate the system forward by dt using the RK4 method.
        pub fn integrate(self: *@This(), dt: f64) void {
            const dt_2 = dt / 2.0;

            const k1: T.value = self.f(self.t, self.x); // f(t_n, x_n)
            const k2: T.value = self.f(self.t + dt_2, T.add(self.x, T.scale(k1, dt_2))); // f(t_n + dt/2, x_n + dt/2 * k1)
            const k3: T.value = self.f(self.t + dt_2, T.add(self.x, T.scale(k2, dt_2))); // f(t_n + dt/2, x_n + dt/2 * k2)
            const k4: T.value = self.f(self.t + dt, T.add(self.x, T.scale(k3, dt))); // f(t_n + dt, x_n + dt * k3)

            self.x = T.add(self.x, T.scale(T.add(
                T.add(k1, T.scale(k2, 2.0)),
                T.add(T.scale(k3, 2.0), k4),
            ), dt / 6.0)); // x_{n+1} = x_n + dt/6 * (k1 + 2*k2 + 2*k3 + k4)

            self.t += dt; // t_{n+1} = t_n + dt
        }
    };
}

const std = @import("std");

test "gravity velocity" {
    const DT = 0.1;
    const g = -9.81;

    const fns = struct {
        pub fn addValue(a: f64, b: f64) f64 {
            return a + b;
        }

        pub fn scalarProduct(a: f64, b: f64) f64 {
            return a * b;
        }

        pub fn f(t: f64, x: f64) f64 {
            _ = t;
            _ = x;
            return g;
        }
    };

    const dataType = DataType(f64, fns.addValue, fns.scalarProduct);

    const systemType = SystemType(dataType);

    var sys = systemType{
        .t = 0,
        .x = 0,
        .f = fns.f,
    };

    var time: f64 = 0;
    while (time < 2.0) : (time += DT) {
        sys.integrate(DT);
    }

    std.debug.print("Final time: {d}\n", .{sys.t});
    std.debug.print("Final velocity: {d}\n", .{sys.x});

    const expected_velocity = g * sys.t; // g*t
    const epsilon = 0.01;

    std.debug.print("Expected velocity: {d}\n", .{expected_velocity});

    try std.testing.expect(std.math.approxEqAbs(f64, sys.x, expected_velocity, epsilon));

    std.debug.print("Test passed!\n", .{});
}

test "gravity position + velocity" {
    // The idea is the use a T.value that holds both position and velocity,
    // and define the system's derivative function accordingly.

    const DT = 0.1;
    const g = -9.81;

    const Vector = struct {
        pos: f64,
        vel: f64,

        fn add(self: @This(), other: @This()) @This() {
            return @This(){
                .pos = self.pos + other.pos,
                .vel = self.vel + other.vel,
            };
        }

        fn scale(self: @This(), factor: f64) @This() {
            return @This(){
                .pos = self.pos * factor,
                .vel = self.vel * factor,
            };
        }
    };

    const data = struct {
        pub fn f(t: f64, x: Vector) Vector {
            _ = t;
            return Vector{
                .pos = x.vel,
                .vel = g,
            };
        }
    };

    const dataType = DataType(Vector, Vector.add, Vector.scale);
    const systemType = SystemType(dataType);

    var sys = systemType{
        .f = data.f,
        .t = 0,
        .x = Vector{
            .pos = 0,
            .vel = 0,
        },
    };

    var time: f64 = 0;
    while (time < 2.0) : (time += DT) {
        sys.integrate(DT);
    }

    std.debug.print("Final time: {d}\n", .{sys.t});
    std.debug.print("Final position: {d}\n", .{sys.x.pos});
    std.debug.print("Final velocity: {d}\n", .{sys.x.vel});

    const expected_velocity = g * sys.t; // g*t
    const expected_position = 0.5 * g * sys.t * sys.t; // 0.5*g*t^2
    const epsilon = 0.01;

    std.debug.print("Expected velocity: {d}\n", .{expected_velocity});
    std.debug.print("Expected position: {d}\n", .{expected_position});

    try std.testing.expect(std.math.approxEqAbs(f64, sys.x.vel, expected_velocity, epsilon));
    try std.testing.expect(std.math.approxEqAbs(f64, sys.x.pos, expected_position, epsilon));

    std.debug.print("Test passed!\n", .{});
}
