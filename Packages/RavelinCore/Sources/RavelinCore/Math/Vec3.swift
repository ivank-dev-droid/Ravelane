public struct Vec3: Sendable, Hashable, Codable {
    public var x: Fixed
    public var y: Fixed
    public var z: Fixed

    public init(_ x: Fixed, _ y: Fixed, _ z: Fixed) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(approximating x: Double, _ y: Double, _ z: Double) {
        self.init(Fixed(approximating: x), Fixed(approximating: y), Fixed(approximating: z))
    }

    public static let zero = Vec3(.zero, .zero, .zero)
    public static let unitX = Vec3(.one, .zero, .zero)
    public static let unitY = Vec3(.zero, .one, .zero)
    public static let unitZ = Vec3(.zero, .zero, .one)

    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static prefix func - (a: Vec3) -> Vec3 { Vec3(-a.x, -a.y, -a.z) }
    public static func * (a: Vec3, s: Fixed) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public static func * (s: Fixed, a: Vec3) -> Vec3 { a * s }
    public static func / (a: Vec3, s: Fixed) -> Vec3 { Vec3(a.x / s, a.y / s, a.z / s) }

    public static func += (a: inout Vec3, b: Vec3) { a = a + b }
    public static func -= (a: inout Vec3, b: Vec3) { a = a - b }

    public func dot(_ other: Vec3) -> Fixed { x * other.x + y * other.y + z * other.z }

    public func cross(_ other: Vec3) -> Vec3 {
        Vec3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    public var lengthSquared: Fixed { dot(self) }

    public var length: Fixed { lengthSquared.squareRoot }

    public var normalized: Vec3 {
        let magnitude = length
        if magnitude.raw == 0 { return .zero }
        return self / magnitude
    }

    public func distance(to other: Vec3) -> Fixed { (self - other).length }

    public func lerp(to other: Vec3, _ t: Fixed) -> Vec3 {
        self + (other - self) * t
    }
}

extension Vec3: CustomStringConvertible {
    public var description: String { "(\(x), \(y), \(z))" }
}
