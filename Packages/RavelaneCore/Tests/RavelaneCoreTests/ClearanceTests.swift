import XCTest
@testable import RavelaneCore

final class ClearanceTests: XCTestCase {
    private let catalog = PieceCatalog.cache

    func testParallelSegmentsDistance() {
        let a0 = Vec3(.zero, .zero, .zero)
        let a1 = Vec3(Fixed(10), .zero, .zero)
        let b0 = Vec3(.zero, Fixed(3), .zero)
        let b1 = Vec3(Fixed(10), Fixed(3), .zero)
        let squared = SegmentDistance.closestSquared(a0, a1, b0, b1)
        XCTAssertEqual(squared.approximateDouble, 9.0, accuracy: 1e-4)
    }

    func testCrossingSegmentsTouch() {
        let a0 = Vec3(Fixed(-5), .zero, .zero)
        let a1 = Vec3(Fixed(5), .zero, .zero)
        let b0 = Vec3(.zero, Fixed(-5), .zero)
        let b1 = Vec3(.zero, Fixed(5), .zero)
        let squared = SegmentDistance.closestSquared(a0, a1, b0, b1)
        XCTAssertEqual(squared.approximateDouble, 0.0, accuracy: 1e-4)
    }

    func testDisjointSegmentsUseEndpoints() {
        let a0 = Vec3(.zero, .zero, .zero)
        let a1 = Vec3(Fixed(1), .zero, .zero)
        let b0 = Vec3(Fixed(5), .zero, .zero)
        let b1 = Vec3(Fixed(9), .zero, .zero)
        let squared = SegmentDistance.closestSquared(a0, a1, b0, b1)
        XCTAssertEqual(squared.approximateDouble, 16.0, accuracy: 1e-4)
    }

    func testDegenerateSegmentsBecomePointDistance() {
        let p = Vec3(.zero, .zero, .zero)
        let q = Vec3(Fixed(3), Fixed(4), .zero)
        let squared = SegmentDistance.closestSquared(p, p, q, q)
        XCTAssertEqual(squared.approximateDouble, 25.0, accuracy: 1e-4)
    }

    func testStraightTrackHasNoSelfConflict() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll(Array(repeating: PieceID("straight"), count: 12))
        let index = ClearanceBuilder.index(for: chain)
        for pieceIndex in 2..<chain.placed.count {
            let record = chain.placed[pieceIndex]
            for capsule in ClearanceBuilder.capsules(for: chain, pieceIndex: pieceIndex) {
                let conflict = index.firstConflict(
                    with: capsule,
                    ignoringArcBetween: record.startArcLength,
                    and: record.endArcLength,
                    window: ClearanceBuilder.selfContactWindow
                )
                XCTAssertNil(conflict, "unexpected conflict on piece \(pieceIndex)")
            }
        }
    }

    func testTightCircleCollidesWithItself() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll(Array(repeating: PieceID("hairpin_l"), count: 6))
        let index = ClearanceBuilder.index(for: chain)
        var conflicts = 0
        for pieceIndex in 2..<chain.placed.count {
            let record = chain.placed[pieceIndex]
            for capsule in ClearanceBuilder.capsules(for: chain, pieceIndex: pieceIndex) {
                if index.firstConflict(
                    with: capsule,
                    ignoringArcBetween: record.startArcLength,
                    and: record.endArcLength,
                    window: ClearanceBuilder.selfContactWindow
                ) != nil {
                    conflicts += 1
                }
            }
        }
        XCTAssertGreaterThan(conflicts, 0, "a track looping back on itself must be detected")
    }

    func testVerticallySeparatedCrossingIsAllowed() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("straight"), PieceID("straight")])
        let index = ClearanceBuilder.index(for: chain)

        let high = Capsule(
            start: Vec3(Fixed(-20), Fixed(20), Fixed(24)),
            end: Vec3(Fixed(20), Fixed(20), Fixed(24)),
            radius: Fixed(5)
        )
        XCTAssertNil(index.firstConflict(with: high, ignoringArcBetween: Fixed(500), and: Fixed(501), window: Fixed(1)))

        let low = Capsule(
            start: Vec3(Fixed(-20), .zero, Fixed(24)),
            end: Vec3(Fixed(20), .zero, Fixed(24)),
            radius: Fixed(5)
        )
        XCTAssertNotNil(index.firstConflict(with: low, ignoringArcBetween: Fixed(500), and: Fixed(501), window: Fixed(1)))
    }

    func testIndexCoversEveryPiece() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([
            PieceID("straight"), PieceID("gentle_curve_l"), PieceID("loop"),
            PieceID("spiral_up"), PieceID("corkscrew_r")
        ])
        let index = ClearanceBuilder.index(for: chain)
        XCTAssertGreaterThanOrEqual(index.capsuleCount, chain.placed.count)
    }
}
