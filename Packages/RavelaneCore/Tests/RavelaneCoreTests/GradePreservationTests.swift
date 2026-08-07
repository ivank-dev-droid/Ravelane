import XCTest
import Foundation
@testable import RavelaneCore

final class GradePreservationTests: XCTestCase {
    private let catalog = PieceCatalog.cache

    private func grade(of frame: Transform3) -> Double {
        let forward = frame.forward
        return Trig.atan2(y: forward.y, x: (forward.x * forward.x + forward.z * forward.z).squareRoot)
            .approximateDouble
    }

    func testTurningWhileClimbingKeepsTheGrade() {
        var chain = TrackChain(catalog: catalog)
        chain.append(PieceID("rise_shallow"))
        let beforeTurn = grade(of: chain.headFrame)

        for id in ["hairpin_l", "sharp_curve_r", "gentle_curve_l", "banked_curve_r"] {
            chain.append(PieceID(id))
            XCTAssertEqual(grade(of: chain.headFrame), beforeTurn, accuracy: 1e-4,
                           "\(id) changed the grade")
        }
    }

    func testClimbHeightMatchesGradeTimesDistance() {
        var chain = TrackChain(catalog: catalog)
        chain.append(PieceID("rise_shallow"))
        let startHeight = chain.headFrame.position.y.approximateDouble
        let gradeRadians = grade(of: chain.headFrame)

        chain.append(PieceID("long_run"))
        let climbed = chain.headFrame.position.y.approximateDouble - startHeight
        let expected = 48.0 * Foundation.sin(gradeRadians)
        XCTAssertEqual(climbed, expected, accuracy: 1e-3)
    }

    func testCrestAndDipCancelEachOther() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("crest"), PieceID("dip")])
        XCTAssertEqual(grade(of: chain.headFrame), 0.0, accuracy: 1e-4)
    }

    func testRiseAndDropCancelToLevel() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("rise_steep"), PieceID("drop_steep")])
        XCTAssertEqual(grade(of: chain.headFrame), 0.0, accuracy: 1e-4)
        XCTAssertGreaterThan(chain.headFrame.position.y, .zero)
    }

    func testSpiralUpProducesAHelix() {
        let geometry = catalog.geometry(PieceID("spiral_up"))!
        let exit = geometry.exitTransform
        XCTAssertGreaterThan(exit.position.y, Fixed(12))

        let rampHorizontal = 2.0 * 4.0 * Foundation.cos(Double.pi * 12.0 / 180.0)
        let horizontalDrift = Vec3(exit.position.x, .zero, exit.position.z).length
        XCTAssertEqual(horizontalDrift.approximateDouble, rampHorizontal, accuracy: 1.0)

        let helixSamples = geometry.localSamples.filter {
            $0.arcLength > Fixed(4) && $0.arcLength < Fixed(40)
        }
        let radii = helixSamples.map {
            Vec3($0.position.x, .zero, $0.position.z - Fixed(4)).length.approximateDouble
        }
        XCTAssertGreaterThan(radii.max()!, 4.0)
        XCTAssertLessThan(radii.max()!, 14.0)
    }

    func testDemoTrackReturnsToGroundLevel() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([
            "straight", "gentle_curve_l", "rise_shallow", "banked_curve_r",
            "long_run", "hairpin_l", "drop_shallow", "spiral_up",
            "straight", "sharp_curve_r", "corkscrew_l", "loop",
            "drop_steep", "chicane_lr", "booster_strip", "straight"
        ].map { PieceID($0) })
        XCTAssertEqual(chain.placed.count, 16)
        XCTAssertEqual(chain.totalLength.approximateDouble, 418.0, accuracy: 1e-3)
        XCTAssertEqual(chain.headFrame.position.y.approximateDouble, 0.0, accuracy: 0.5)
    }

    func testBodyAxisYawStillAvailableForMagnetite() {
        let piece = Piece(
            id: PieceID("test_body_turn"), name: "Body Turn", pieceClass: .turn,
            segments: [PieceSegment(length: Fixed(16), yaw: degrees(90), yawAxis: .body)],
            cost: 0)
        let cache = PieceCatalogCache(pieces: [piece])
        var chain = TrackChain(catalog: cache, origin: Transform3(
            position: .zero,
            rotation: Quat(yaw: .zero, pitch: degrees(30), roll: .zero)
        ))
        chain.append(piece.id)
        XCTAssertNotEqual(grade(of: chain.headFrame), Double.pi / 6, accuracy: 1e-6)
    }
}
