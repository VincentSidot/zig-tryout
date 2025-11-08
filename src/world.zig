const r = @import("raylib.zig").c;

const Utils = @import("utils.zig").Utils;

pub const World = struct {
    bounds: r.Rectangle = .{
        .x = 0,
        .y = 0,
        .width = 5,
        .height = 5,
    },

    pub const Direction = packed struct(u4) {
        north: bool = false,
        south: bool = false,
        east: bool = false,
        west: bool = false,

        pub fn bits(self: @This()) u4 {
            return @as(u4, @bitCast(self));
        }

        pub fn fromBits(raw: u4) @This() {
            return @bitCast(@as(u4, raw));
        }

        pub fn merge(self: *@This(), other: *const @This()) void {
            self.north = self.north or other.north;
            self.south = self.south or other.south;
            self.east = self.east or other.east;
            self.west = self.west or other.west;
        }

        pub const North: u4 = 1 << 0;
        pub const South: u4 = 1 << 1;
        pub const East: u4 = 1 << 2;
        pub const West: u4 = 1 << 3;
    };

    pub fn collisionBall(self: *const World, position: r.Vector2, radius: f32) Direction {
        var collision: Direction = .{};

        if (position.x - radius < self.bounds.x) {
            collision.west = true;
        } else if (position.x + radius > self.bounds.x + self.bounds.width) {
            collision.east = true;
        }

        if (position.y - radius < self.bounds.y) {
            collision.north = true;
        } else if (position.y + radius > self.bounds.y + self.bounds.height) {
            collision.south = true;
        }

        return collision;
    }

    pub fn min(self: *const World) r.Vector2 {
        return r.Vector2{
            .x = self.bounds.x,
            .y = self.bounds.y,
        };
    }

    pub fn max(self: *const World) r.Vector2 {
        return r.Vector2{
            .x = self.bounds.x + self.bounds.width,
            .y = self.bounds.y + self.bounds.height,
        };
    }

    pub fn distanceFromWorldToPixel(self: *const World, worldDist: f32, isWidth: bool) f32 {
        var screenSize: f32 = 0.0;
        if (isWidth) {
            screenSize = @floatFromInt(r.GetScreenWidth());
        } else {
            screenSize = @floatFromInt(r.GetScreenHeight());
        }

        var worldSize: f32 = 0.0;
        if (isWidth) {
            worldSize = self.bounds.width;
        } else {
            worldSize = self.bounds.height;
        }

        return (worldDist / worldSize) * screenSize;
    }

    pub fn distanceFromPixelToWorld(self: *const World, pixelDist: f32, isWidth: bool) f32 {
        var screenSize: f32 = 0.0;
        if (isWidth) {
            screenSize = @floatFromInt(r.GetScreenWidth());
        } else {
            screenSize = @floatFromInt(r.GetScreenHeight());
        }

        var worldSize: f32 = 0.0;
        if (isWidth) {
            worldSize = self.bounds.width;
        } else {
            worldSize = self.bounds.height;
        }

        return (pixelDist / screenSize) * worldSize;
    }

    pub fn locationFromWorldToPixels(self: *const World, worldPos: r.Vector2) r.Vector2 {
        const screenWidth: f32 = @floatFromInt(r.GetScreenWidth());
        const screenHeight: f32 = @floatFromInt(r.GetScreenHeight());

        const translatedX = worldPos.x - self.bounds.x;
        const translatedY = worldPos.y - self.bounds.y;

        return r.Vector2{
            .x = (translatedX / self.bounds.width) * screenWidth,
            .y = (translatedY / self.bounds.height) * screenHeight,
        };
    }

    pub fn locationFromPixelsToWorld(self: *const World, pixelPos: r.Vector2) r.Vector2 {
        const screenWidth: f32 = @floatFromInt(r.GetScreenWidth());
        const screenHeight: f32 = @floatFromInt(r.GetScreenHeight());

        const worldX = (pixelPos.x / screenWidth) * self.bounds.width + self.bounds.x;
        const worldY = (pixelPos.y / screenHeight) * self.bounds.height + self.bounds.y;

        return r.Vector2{
            .x = worldX,
            .y = worldY,
        };
    }

    pub fn vectorFromWorldToPixels(self: *const World, worldVec: r.Vector2) r.Vector2 {
        const screenWidth: f32 = @floatFromInt(r.GetScreenWidth());
        const screenHeight: f32 = @floatFromInt(r.GetScreenHeight());

        return r.Vector2{
            .x = (worldVec.x / self.bounds.width) * screenWidth,
            .y = (worldVec.y / self.bounds.height) * screenHeight,
        };
    }

    pub fn vectorFromPixelsToWorld(self: *const World, pixelVec: r.Vector2) r.Vector2 {
        const screenWidth: f32 = @floatFromInt(r.GetScreenWidth());
        const screenHeight: f32 = @floatFromInt(r.GetScreenHeight());

        return r.Vector2{
            .x = (pixelVec.x / screenWidth) * self.bounds.width,
            .y = (pixelVec.y / screenHeight) * self.bounds.height,
        };
    }

    pub fn vectorGetX(T: anytype, vec: r.Vector2) T {
        switch (@typeInfo(T)) {
            .int => {
                return @as(T, @intFromFloat(vec.x));
            },
            .float => {
                return @as(T, @floatCast(vec.x));
            },
            else => @compileError("Unsupported type for vectorGetX"),
        }
    }

    pub fn vectorGetY(T: anytype, vec: r.Vector2) T {
        switch (@typeInfo(T)) {
            .int => {
                return @as(T, @intFromFloat(vec.y));
            },
            .float => {
                return @as(T, @floatCast(vec.y));
            },
            else => @compileError("Unsupported type for vectorGetY"),
        }
    }

    // Draw primitive shapes in the world coordinates

    pub fn drawLine(self: *const World, start: r.Vector2, end: r.Vector2, color: r.Color) void {
        const pixelStart = self.locationFromWorldToPixels(start);
        const pixelEnd = self.locationFromWorldToPixels(end);
        r.DrawLineV(pixelStart, pixelEnd, color);
    }

    pub fn drawCircle(self: *const World, center: r.Vector2, radius: f32, color: r.Color) void {
        const pixelCenter = self.locationFromWorldToPixels(center);
        const pixelRadiusWidth = self.distanceFromWorldToPixel(radius, true);
        const pixelRadiusHeight = self.distanceFromWorldToPixel(radius, false);

        Utils.println("Pixels Center: {any}, radius: ({d}, {d})", .{ pixelCenter, pixelRadiusWidth, pixelRadiusHeight });

        const centerX = World.vectorGetX(c_int, pixelCenter);
        const centerY = World.vectorGetY(c_int, pixelCenter);

        r.DrawEllipse(centerX, centerY, pixelRadiusHeight, pixelRadiusWidth, color);
    }
};
