public struct RibbonSample: Sendable, Hashable {
    public var arcLength: Fixed
    public var frame: Transform3
    public var curvature: Fixed
    public var bank: Fixed
    public var lateralCurvature: Fixed
    public var verticalCurvature: Fixed

    public init(
        arcLength: Fixed,
        frame: Transform3,
        curvature: Fixed,
        bank: Fixed,
        lateralCurvature: Fixed = .zero,
        verticalCurvature: Fixed = .zero
    ) {
        self.arcLength = arcLength
        self.frame = frame
        self.curvature = curvature
        self.bank = bank
        self.lateralCurvature = lateralCurvature
        self.verticalCurvature = verticalCurvature
    }

    public var position: Vec3 { frame.position }
    public var tangent: Vec3 { frame.forward }
    public var normal: Vec3 { frame.up }
    public var lateral: Vec3 { frame.right }
}

public enum RibbonSampling {
    public static func interpolate(_ samples: [RibbonSample], at arcLength: Fixed) -> RibbonSample? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if arcLength <= first.arcLength { return first }
        if arcLength >= last.arcLength { return last }

        var low = 0
        var high = samples.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if samples[mid].arcLength <= arcLength { low = mid } else { high = mid }
        }

        let a = samples[low]
        let b = samples[high]
        let span = b.arcLength - a.arcLength
        if span.raw == 0 { return a }
        let t = (arcLength - a.arcLength) / span

        return RibbonSample(
            arcLength: arcLength,
            frame: Transform3(
                position: a.frame.position.lerp(to: b.frame.position, t),
                rotation: a.frame.rotation
            ),
            curvature: a.curvature + (b.curvature - a.curvature) * t,
            bank: a.bank + (b.bank - a.bank) * t,
            lateralCurvature: a.lateralCurvature,
            verticalCurvature: a.verticalCurvature
        )
    }
}

public struct PieceGeometry: Sendable {
    struct SegmentPlan: Sendable {
        let segment: PieceSegment
        let steps: Int
        let stepLength: Fixed
        let bodyHalfYaw: Fixed
        let worldHalfYaw: Fixed
        let halfPitch: Fixed
        let halfRoll: Fixed
        let curvature: Fixed
        let lateralCurvature: Fixed
        let verticalCurvature: Fixed
    }

    public let piece: Piece
    public let length: Fixed
    let plan: [SegmentPlan]

    static let samplesPerMetre = 4
    static let minimumSamples = 12
    static let maximumSamples = 320

    public init(piece: Piece) {
        self.piece = piece
        self.length = piece.length
        self.plan = piece.segments.map { segment in
            let steps = PieceGeometry.stepCount(for: segment.length)
            let halfYaw = segment.yaw / Fixed(steps * 2)
            return SegmentPlan(
                segment: segment,
                steps: steps,
                stepLength: segment.length / Fixed(steps),
                bodyHalfYaw: segment.yawAxis == .body ? halfYaw : .zero,
                worldHalfYaw: segment.yawAxis == .world ? halfYaw : .zero,
                halfPitch: segment.pitch / Fixed(steps * 2),
                halfRoll: segment.roll / Fixed(steps * 2),
                curvature: segment.curvature,
                lateralCurvature: segment.lateralCurvature,
                verticalCurvature: segment.verticalCurvature
            )
        }
    }

    static func bankAngle(of frame: Transform3) -> Fixed {
        let right = frame.right
        let up = frame.up
        if right.y.raw == 0 && up.y.raw == 0 { return .zero }
        return Trig.atan2(y: right.y, x: up.y)
    }

    static func stepCount(for length: Fixed) -> Int {
        let raw = length.whole * samplesPerMetre
        return Swift.max(minimumSamples, Swift.min(maximumSamples, raw))
    }

    public var sampleCount: Int {
        plan.reduce(1) { $0 + $1.steps }
    }

    public func samples(from entry: Transform3) -> [RibbonSample] {
        var result: [RibbonSample] = []
        result.reserveCapacity(sampleCount)

        var frame = entry
        var travelled = Fixed.zero

        result.append(
            RibbonSample(
                arcLength: .zero,
                frame: frame,
                curvature: plan.first?.curvature ?? .zero,
                bank: PieceGeometry.bankAngle(of: frame),
                lateralCurvature: plan.first?.lateralCurvature ?? .zero,
                verticalCurvature: plan.first?.verticalCurvature ?? .zero
            )
        )

        for segmentPlan in plan {
            for _ in 0..<segmentPlan.steps {
                frame = frame.rotated(
                    yaw: segmentPlan.bodyHalfYaw,
                    pitch: segmentPlan.halfPitch,
                    roll: segmentPlan.halfRoll
                )
                frame = frame.rotatedAboutWorldUp(segmentPlan.worldHalfYaw)
                frame = frame.advanced(along: segmentPlan.stepLength)
                frame = frame.rotated(
                    yaw: segmentPlan.bodyHalfYaw,
                    pitch: segmentPlan.halfPitch,
                    roll: segmentPlan.halfRoll
                )
                frame = frame.rotatedAboutWorldUp(segmentPlan.worldHalfYaw)
                travelled += segmentPlan.stepLength
                result.append(
                    RibbonSample(
                        arcLength: travelled,
                        frame: frame,
                        curvature: segmentPlan.curvature,
                        bank: PieceGeometry.bankAngle(of: frame),
                        lateralCurvature: segmentPlan.lateralCurvature,
                        verticalCurvature: segmentPlan.verticalCurvature
                    )
                )
            }
        }

        return result
    }

    public func exit(from entry: Transform3) -> Transform3 {
        var frame = entry
        for segmentPlan in plan {
            for _ in 0..<segmentPlan.steps {
                frame = frame.rotated(
                    yaw: segmentPlan.bodyHalfYaw,
                    pitch: segmentPlan.halfPitch,
                    roll: segmentPlan.halfRoll
                )
                frame = frame.rotatedAboutWorldUp(segmentPlan.worldHalfYaw)
                frame = frame.advanced(along: segmentPlan.stepLength)
                frame = frame.rotated(
                    yaw: segmentPlan.bodyHalfYaw,
                    pitch: segmentPlan.halfPitch,
                    roll: segmentPlan.halfRoll
                )
                frame = frame.rotatedAboutWorldUp(segmentPlan.worldHalfYaw)
            }
        }
        return frame
    }

    public var exitTransform: Transform3 { exit(from: .identity) }

    public var localSamples: [RibbonSample] { samples(from: .identity) }
}

public struct PieceCatalogCache: Sendable {
    private let geometries: [PieceID: PieceGeometry]
    public let pieces: [Piece]

    public init(pieces: [Piece]) {
        self.pieces = pieces
        var built: [PieceID: PieceGeometry] = [:]
        for piece in pieces {
            built[piece.id] = PieceGeometry(piece: piece)
        }
        self.geometries = built
    }

    public func geometry(_ id: PieceID) -> PieceGeometry? { geometries[id] }

    public func piece(_ id: PieceID) -> Piece? { geometries[id]?.piece }

    public var count: Int { pieces.count }
}
