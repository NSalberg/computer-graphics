const std = @import("std");
const Writer = std.Io.Writer;
const Random = std.Random;
const assert = std.debug.assert;

pub const Vec3 = @Vector(3, f64);

pub const zero: Vec3 = .{ 0, 0, 0 };
pub const one: Vec3 = .{ 1, 1, 1 };

// Getters
pub fn x(v: Vec3) f64 {
    return v[0];
}

pub fn y(v: Vec3) f64 {
    return v[1];
}

pub fn z(v: Vec3) f64 {
    return v[2];
}

pub fn magnitude(v: Vec3) f64 {
    //const sqsum: f64 = v[0]*v[0] + v[2]*v[2] + v[1]*v[1];
    //return @sqrt(sqsum);
    return @sqrt(magnitude2(v));
}

// conventions reads magnitude squared
pub fn magnitude2(v: Vec3) f64 {
    return @reduce(.Add, v * v);
}

pub fn dot(lhs: Vec3, rhs: Vec3) f64 {
    return @reduce(.Add, lhs * rhs);
}

pub fn cross(lhs: Vec3, rhs: Vec3) Vec3 {
    return .{
        lhs[1] * rhs[2] - lhs[2] * rhs[1],
        lhs[2] * rhs[0] - lhs[0] * rhs[2],
        lhs[0] * rhs[1] - lhs[1] * rhs[0],
    };
}

pub fn unit(v: Vec3) Vec3 {
    // Magnitude is a f64 scalar value
    const mag = magnitude(v);
    // so we check for zero and return a zero unit vector.
    if (mag == 0) return zero;

    // get the length vector and divide each dim x, y, z
    // like normalize the vecor
    const mag3: Vec3 = @splat(mag);
    return v / mag3;
}

pub fn splat(n: anytype) Vec3 {
    switch (@TypeOf(n)) {
        usize, comptime_int => return @splat(@floatFromInt(n)),
        f64, comptime_float => return @splat(n),
        else => unreachable,
    }
}

pub fn random(r: Random) Vec3 {
    return .{
        r.float(f64),
        r.float(f64),
        r.float(f64),
    };
}

pub fn randomRange(r: Random, min: f64, max: f64) Vec3 {
    assert(max >= min);
    return .{
        r.float(f64) * (max - min) + min,
        r.float(f64) * (max - min) + min,
        r.float(f64) * (max - min) + min,
    };
}

pub fn randomUnit(r: Random) Vec3 {
    while (true) {
        const v = randomRange(r, -1.0, 1.0);
        const m2 = magnitude2(v);
        if (std.math.floatEpsAt(f64, 0) < m2 and m2 <= 1) {
            return v / @sqrt(splat(m2));
        }
    }
}

pub fn randomHemisphere(r: Random, normal: Vec3) Vec3 {
    const v = randomUnit(r);
    return if (dot(v, normal) > 0) v else -v;
}

//Generate random point inside unit disk
pub fn randomUnitDisk(r: Random) Vec3 {
    while (true) {
        var p: Vec3 = randomRange(r, -1, 1);
        p[2] = 0;
        if (magnitude2(p) < 1) return p;
    }
}

pub fn nearZero(v: Vec3) bool {
    const s = 1e-8;
    return @reduce(.And, @abs(v) < splat(s));
}

pub fn reflect(v: Vec3, normal: Vec3) Vec3 {
    return v - splat(2 * dot(v, normal)) * normal;
}

// etai_over_etat = relative refractive index

pub fn refract(uv: Vec3, n: Vec3, relative_refraction: f64) Vec3 {
    const cos_t = if (dot(-uv, n) < 1.0) dot(-uv, n) else 1.0;
    const r_out_perp: Vec3 = splat(relative_refraction) * (uv + splat(cos_t) * n);
    const r_out_parallel = -splat(@sqrt(@abs(1.0 - magnitude2(r_out_perp)))) * n;
    return r_out_perp + r_out_parallel;
}

pub const Fmt = std.fmt.Alt(Vec3, format);
fn format(v: Vec3, w: *Writer) !void {
    try w.print("{d} {d} {d}", .{ v[0], v[1], v[2] });
}
