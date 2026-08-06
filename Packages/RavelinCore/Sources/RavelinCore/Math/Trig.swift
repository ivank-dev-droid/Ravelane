public enum Trig {
    public static let pi = Fixed(raw: 13493037705)
    public static let halfPi = Fixed(raw: 6746518852)
    public static let twoPi = Fixed(raw: 26986075409)

    static let cordicGain = Fixed(raw: 2608131496)

    static let arctanTable: [Int64] = [
        3373259426, 1991351318, 1052175346, 534100635,
        268086748, 134174063, 67103403, 33553749,
        16777131, 8388597, 4194303, 2097152,
        1048576, 524288, 262144, 131072,
        65536, 32768, 16384, 8192,
        4096, 2048, 1024, 512,
        256, 128, 64, 32,
        16, 8, 4, 2
    ]

    public static func normalizedAngle(_ angle: Fixed) -> Fixed {
        var value = angle.raw
        if value >= twoPi.raw || value <= -twoPi.raw {
            value -= (value / twoPi.raw) * twoPi.raw
        }
        if value > pi.raw { value -= twoPi.raw }
        if value < -pi.raw { value += twoPi.raw }
        return Fixed(raw: value)
    }

    static let guardBits: Int64 = 14

    public static func sinCos(_ angle: Fixed) -> (sin: Fixed, cos: Fixed) {
        var residual = normalizedAngle(angle).raw
        var negateCosine = false

        if residual > halfPi.raw {
            residual = pi.raw - residual
            negateCosine = true
        } else if residual < -halfPi.raw {
            residual = -pi.raw - residual
            negateCosine = true
        }

        var x = cordicGain.raw << guardBits
        var y: Int64 = 0

        for index in 0..<arctanTable.count {
            let shift = Int64(index)
            let deltaX = x >> shift
            let deltaY = y >> shift
            if residual >= 0 {
                x -= deltaY
                y += deltaX
                residual -= arctanTable[index]
            } else {
                x += deltaY
                y -= deltaX
                residual += arctanTable[index]
            }
        }

        let sine = roundedShift(y, by: guardBits)
        let cosine = roundedShift(x, by: guardBits)
        return (Fixed(raw: sine), Fixed(raw: negateCosine ? -cosine : cosine))
    }

    static func roundedShift(_ value: Int64, by bits: Int64) -> Int64 {
        let half: Int64 = 1 << (bits - 1)
        return value >= 0 ? (value + half) >> bits : -((-value + half) >> bits)
    }

    public static func sin(_ angle: Fixed) -> Fixed { sinCos(angle).sin }
    public static func cos(_ angle: Fixed) -> Fixed { sinCos(angle).cos }

    public static func tan(_ angle: Fixed) -> Fixed {
        let (s, c) = sinCos(angle)
        if c.raw == 0 { return s.raw >= 0 ? .max : .min }
        return s / c
    }

    public static func atan2(y: Fixed, x: Fixed) -> Fixed {
        if y.raw == 0 { return x.raw >= 0 ? .zero : pi }
        if x.raw == 0 { return y.raw > 0 ? halfPi : -halfPi }

        var vx = x.raw
        var vy = y.raw
        var quadrantOffset: Int64 = 0

        if vx < 0 {
            quadrantOffset = vy > 0 ? pi.raw : -pi.raw
            vx = -vx
            vy = -vy
        }

        let target: Int64 = 1 << 46
        while vx.magnitude < target && vy.magnitude < target {
            vx <<= 1
            vy <<= 1
        }
        while vx.magnitude > target || vy.magnitude > target {
            vx >>= 1
            vy >>= 1
        }

        var accumulated: Int64 = 0
        for index in 0..<arctanTable.count {
            let shift = Int64(index)
            let deltaX = vx >> shift
            let deltaY = vy >> shift
            if vy > 0 {
                vx += deltaY
                vy -= deltaX
                accumulated += arctanTable[index]
            } else {
                vx -= deltaY
                vy += deltaX
                accumulated -= arctanTable[index]
            }
        }

        let total = quadrantOffset + accumulated
        if total > pi.raw { return Fixed(raw: pi.raw) }
        if total < -pi.raw { return Fixed(raw: -pi.raw) }
        return Fixed(raw: total)
    }
}
