const std = @import("std");
const r = @import("raylib.zig").c;

// Global PRNG state that we'll seed at runtime on first use
var g_prng: std.Random.DefaultPrng = undefined;
var g_rng: std.Random = undefined;
var g_seeded: bool = false;

fn rng() *std.Random {
    if (!g_seeded) {
        var seed: u64 = undefined;
        // getrandom is runtime-only; that's fine here
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        g_prng = std.Random.DefaultPrng.init(seed);
        g_rng = g_prng.random();
        g_seeded = true;
    }
    return &g_rng;
}

pub const Random = struct {
    pub fn randomFloat(min: f32, max: f32) f32 {
        return rng().float(f32) * (max - min) + min;
    }

    pub fn randomVector2(min: r.Vector2, max: r.Vector2) r.Vector2 {
        return r.Vector2{
            .x = Random.randomFloat(min.x, max.x),
            .y = Random.randomFloat(min.y, max.y),
        };
    }
};
