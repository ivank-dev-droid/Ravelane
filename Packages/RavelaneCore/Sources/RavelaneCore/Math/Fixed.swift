public struct Fixed: Sendable, Hashable, Comparable, Codable {
    public var raw: Int64

    public static let fractionalBits: Int = 32
    public static let scale: Int64 = 1 << 32

    @inlinable public init(raw: Int64) { self.raw = raw }

    public init(_ value: Int) {
        raw = Int64(value) &* Fixed.scale
    }

    public init(_ numerator: Int, over denominator: Int) {
        precondition(denominator != 0)
        raw = (Int64(numerator) &* Fixed.scale) / Int64(denominator)
    }

    public init(approximating value: Double) {
        raw = Int64((value * 4294967296.0).rounded())
    }

    public var approximateDouble: Double { Double(raw) / 4294967296.0 }

    public var whole: Int { Int(raw >> Fixed.fractionalBits) }

    public static let zero = Fixed(raw: 0)
    public static let one = Fixed(raw: Fixed.scale)
    public static let half = Fixed(raw: Fixed.scale >> 1)
    public static let min = Fixed(raw: Int64.min)
    public static let max = Fixed(raw: Int64.max)
    public static let epsilon = Fixed(raw: 1)

    public static func < (a: Fixed, b: Fixed) -> Bool { a.raw < b.raw }

    @inlinable public static func + (a: Fixed, b: Fixed) -> Fixed {
        Fixed(raw: a.raw.addingReportingOverflow(b.raw).overflow
            ? (a.raw > 0 ? Int64.max : Int64.min)
            : a.raw &+ b.raw)
    }

    @inlinable public static func - (a: Fixed, b: Fixed) -> Fixed {
        Fixed(raw: a.raw.subtractingReportingOverflow(b.raw).overflow
            ? (a.raw > 0 ? Int64.max : Int64.min)
            : a.raw &- b.raw)
    }

    @inlinable public static prefix func - (a: Fixed) -> Fixed {
        Fixed(raw: a.raw == Int64.min ? Int64.max : -a.raw)
    }

    public static func * (a: Fixed, b: Fixed) -> Fixed {
        let negative = (a.raw < 0) != (b.raw < 0)
        let (high, low) = UInt64(a.raw.magnitude).multipliedFullWidth(by: UInt64(b.raw.magnitude))
        if high >> 31 != 0 { return Fixed(raw: negative ? Int64.min : Int64.max) }
        let magnitude = (high << 32) | (low >> 32)
        if magnitude > UInt64(Int64.max) { return Fixed(raw: negative ? Int64.min : Int64.max) }
        return Fixed(raw: negative ? -Int64(magnitude) : Int64(magnitude))
    }

    public static func / (a: Fixed, b: Fixed) -> Fixed {
        precondition(b.raw != 0)
        let negative = (a.raw < 0) != (b.raw < 0)
        let dividendMagnitude = UInt64(a.raw.magnitude)
        let divisorMagnitude = UInt64(b.raw.magnitude)
        let high = dividendMagnitude >> 32
        let low = dividendMagnitude << 32
        if high >= divisorMagnitude { return Fixed(raw: negative ? Int64.min : Int64.max) }
        let (quotient, _) = divisorMagnitude.dividingFullWidth((high: high, low: low))
        if quotient > UInt64(Int64.max) { return Fixed(raw: negative ? Int64.min : Int64.max) }
        return Fixed(raw: negative ? -Int64(quotient) : Int64(quotient))
    }

    @inlinable public static func += (a: inout Fixed, b: Fixed) { a = a + b }
    @inlinable public static func -= (a: inout Fixed, b: Fixed) { a = a - b }
    @inlinable public static func *= (a: inout Fixed, b: Fixed) { a = a * b }
    @inlinable public static func /= (a: inout Fixed, b: Fixed) { a = a / b }

    public var magnitude: Fixed { raw < 0 ? -self : self }

    public var sign: Int { raw > 0 ? 1 : (raw < 0 ? -1 : 0) }

    public var squareRoot: Fixed {
        precondition(raw >= 0)
        if raw == 0 { return .zero }
        let value = UInt64(raw)
        let high = value >> 32
        let low = value << 32
        return Fixed(raw: Int64(Fixed.integerSquareRoot128(high: high, low: low)))
    }

    static func integerSquareRoot128(high: UInt64, low: UInt64) -> UInt64 {
        var result: UInt64 = 0
        var bit: UInt64 = 1 << 63
        while bit > 0 {
            let candidate = result | bit
            let (squareHigh, squareLow) = candidate.multipliedFullWidth(by: candidate)
            if squareHigh < high || (squareHigh == high && squareLow <= low) {
                result = candidate
            }
            bit >>= 1
        }
        return result
    }

    public func clamped(to range: ClosedRange<Fixed>) -> Fixed {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Fixed: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self.init(value) }
}

extension Fixed: CustomStringConvertible {
    public var description: String {
        let negative = raw < 0
        let magnitude = UInt64(raw.magnitude)
        let integerPart = magnitude >> 32
        let fraction = magnitude & 0xFFFF_FFFF
        let thousandths = (fraction &* 1000) >> 32
        let digits = String(thousandths)
        let padded = String(repeating: "0", count: 3 - digits.count) + digits
        return (negative ? "-" : "") + "\(integerPart).\(padded)"
    }
}
