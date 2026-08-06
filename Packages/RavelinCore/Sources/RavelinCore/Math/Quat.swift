public struct Quat: Sendable, Hashable, Codable {
    public var x: Fixed
    public var y: Fixed
    public var z: Fixed
    public var w: Fixed

    public init(x: Fixed, y: Fixed, z: Fixed, w: Fixed) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let identity = Quat(x: .zero, y: .zero, z: .zero, w: .one)

    public init(axis: Vec3, angle: Fixed) {
        let unit = axis.normalized
        let (s, c) = Trig.sinCos(Fixed(raw: angle.raw >> 1))
        x = unit.x * s
        y = unit.y * s
        z = unit.z * s
        w = c
    }

    public init(yaw: Fixed, pitch: Fixed, roll: Fixed) {
        if yaw.raw == 0 && pitch.raw == 0 && roll.raw == 0 {
            self = .identity
            return
        }
        let (sy, cy) = Trig.sinCos(Fixed(raw: yaw.raw / 2))
        let (sp, cp) = Trig.sinCos(Fixed(raw: -pitch.raw / 2))
        let (sr, cr) = Trig.sinCos(Fixed(raw: roll.raw / 2))
        x = sp * cy * cr + cp * sy * sr
        y = cp * sy * cr - sp * cy * sr
        z = cp * cy * sr - sp * sy * cr
        w = cp * cy * cr + sp * sy * sr
    }

    public static func * (a: Quat, b: Quat) -> Quat {
        Quat(
            x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
            w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
        )
    }

    public var conjugate: Quat { Quat(x: -x, y: -y, z: -z, w: w) }

    public var lengthSquared: Fixed { x * x + y * y + z * z + w * w }

    public var normalized: Quat {
        let magnitude = lengthSquared.squareRoot
        if magnitude.raw == 0 { return .identity }
        return Quat(x: x / magnitude, y: y / magnitude, z: z / magnitude, w: w / magnitude)
    }

    public func rotate(_ v: Vec3) -> Vec3 {
        let u = Vec3(x, y, z)
        let uv = u.cross(v)
        let uuv = u.cross(uv)
        let two = Fixed(2)
        return v + ((uv * w) + uuv) * two
    }

    public var forward: Vec3 { rotate(.unitZ) }
    public var up: Vec3 { rotate(.unitY) }
    public var right: Vec3 { rotate(.unitX) }
}
