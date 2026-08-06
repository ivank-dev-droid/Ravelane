import XCTest
@testable import RavelinCore

final class TrackTests: XCTestCase {
    private let catalog = PieceCatalog.cache

    func testCatalogLoadsEveryPiece() {
        XCTAssertEqual(catalog.count, PieceCatalog.all.count)
        XCTAssertGreaterThanOrEqual(catalog.count, 40)
        for piece in PieceCatalog.all {
            XCTAssertNotNil(catalog.geometry(piece.id), "missing geometry for \(piece.id)")
        }
    }

    func testCatalogIdentifiersAreUnique() {
        var seen = Set<String>()
        for piece in PieceCatalog.all {
            XCTAssertTrue(seen.insert(piece.id.rawValue).inserted, "duplicate id \(piece.id)")
        }
    }

    func testEverySegmentHasPositiveLength() {
        for piece in PieceCatalog.all {
            XCTAssertFalse(piece.segments.isEmpty, "\(piece.id) has no segments")
            for segment in piece.segments {
                XCTAssertGreaterThan(segment.length, .zero, "\(piece.id) has a zero segment")
            }
        }
    }

    func testMirroredPairsAreExactNegations() {
        let pairs = [
            ("gentle_curve_l", "gentle_curve_r"),
            ("sharp_curve_l", "sharp_curve_r"),
            ("hairpin_l", "hairpin_r"),
            ("banked_curve_l", "banked_curve_r"),
            ("bank_l", "bank_r"),
            ("corkscrew_l", "corkscrew_r")
        ]
        for (leftID, rightID) in pairs {
            guard let left = catalog.piece(PieceID(leftID)),
                  let right = catalog.piece(PieceID(rightID)) else {
                return XCTFail("missing mirror pair \(leftID)/\(rightID)")
            }
            XCTAssertEqual(left.segments.count, right.segments.count)
            for (a, b) in zip(left.segments, right.segments) {
                XCTAssertEqual(a.length, b.length)
                XCTAssertEqual(a.yaw.raw, -b.yaw.raw)
                XCTAssertEqual(a.roll.raw, -b.roll.raw)
                XCTAssertEqual(a.pitch.raw, b.pitch.raw)
            }
            XCTAssertEqual(left.cost, right.cost)
            XCTAssertEqual(left.width, right.width)
        }
    }

    func testGeometryArcLengthMatchesDeclaredLength() {
        for piece in PieceCatalog.all {
            guard let geometry = catalog.geometry(piece.id) else { continue }
            let last = geometry.localSamples.last!.arcLength
            XCTAssertEqual(last.approximateDouble, piece.length.approximateDouble,
                           accuracy: 1e-4, "\(piece.id) arc length drift")
        }
    }

    func testStraightPieceTravelsAlongForwardAxis() {
        let geometry = catalog.geometry(PieceID("straight"))!
        let exit = geometry.exitTransform
        XCTAssertEqual(exit.position.x.approximateDouble, 0.0, accuracy: 1e-6)
        XCTAssertEqual(exit.position.y.approximateDouble, 0.0, accuracy: 1e-6)
        XCTAssertEqual(exit.position.z.approximateDouble, 24.0, accuracy: 1e-5)
    }

    func testCurveExitAngleMatchesDeclaredYaw() {
        for id in ["gentle_curve_l", "sharp_curve_l", "hairpin_l"] {
            let geometry = catalog.geometry(PieceID(id))!
            let piece = geometry.piece
            let forward = geometry.exitTransform.forward
            let recovered = Trig.atan2(y: forward.x, x: forward.z)
            XCTAssertEqual(recovered.approximateDouble, piece.totalYaw.approximateDouble,
                           accuracy: 1e-4, "\(id) exit heading drift")
        }
    }

    func testCurveRadiusMatchesArcGeometry() {
        let geometry = catalog.geometry(PieceID("sharp_curve_l"))!
        let piece = geometry.piece
        let chord = geometry.exitTransform.position.length
        let radius = piece.length / piece.totalYaw.magnitude
        let expectedChord = Fixed(2) * radius * Trig.sin(piece.totalYaw.magnitude / Fixed(2))
        XCTAssertEqual(chord.approximateDouble, expectedChord.approximateDouble, accuracy: 1e-3)
    }

    func testLoopReturnsToStartingHeight() {
        let geometry = catalog.geometry(PieceID("loop"))!
        XCTAssertEqual(geometry.exitTransform.position.y.approximateDouble, 0.0, accuracy: 1e-2)
        let forward = geometry.exitTransform.forward
        XCTAssertEqual(forward.z.approximateDouble, 1.0, accuracy: 1e-3)
    }

    func testCrestReturnsToLevelPitch() {
        let geometry = catalog.geometry(PieceID("crest"))!
        let forward = geometry.exitTransform.forward
        XCTAssertEqual(forward.y.approximateDouble, 0.0, accuracy: 1e-4)
        XCTAssertGreaterThan(geometry.exitTransform.position.y, .zero)
    }

    func testSpiralUpGainsAltitudeAndReturnsHeading() {
        let geometry = catalog.geometry(PieceID("spiral_up"))!
        XCTAssertGreaterThan(geometry.exitTransform.position.y, Fixed(5))
        let forward = geometry.exitTransform.forward
        XCTAssertEqual(forward.z.approximateDouble, 1.0, accuracy: 1e-2)
    }

    func testChainAppendAccumulatesLength() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("straight"), PieceID("straight"), PieceID("stub")])
        XCTAssertEqual(chain.placed.count, 3)
        XCTAssertEqual(chain.totalLength.approximateDouble, 24 + 24 + 8, accuracy: 1e-4)
        XCTAssertEqual(chain.headFrame.position.z.approximateDouble, 56.0, accuracy: 1e-4)
    }

    func testChainRejectsUnknownPiece() {
        var chain = TrackChain(catalog: catalog)
        XCTAssertNil(chain.append(PieceID("does_not_exist")))
        XCTAssertEqual(chain.placed.count, 0)
    }

    func testProjectedHeadMatchesActualAppend() {
        var chain = TrackChain(catalog: catalog)
        chain.append(PieceID("straight"))
        let projected = chain.projectedHead(afterAppending: PieceID("sharp_curve_l"))!
        chain.append(PieceID("sharp_curve_l"))
        XCTAssertEqual(chain.headFrame.position.x, projected.position.x)
        XCTAssertEqual(chain.headFrame.position.z, projected.position.z)
        XCTAssertEqual(chain.headFrame.rotation, projected.rotation)
    }

    func testSampleAtBoundaryMatchesPieceEntryFrame() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("straight"), PieceID("gentle_curve_l"), PieceID("straight")])
        let boundary = chain.placed[1].startArcLength
        let sample = chain.sample(atArcLength: boundary)!
        let entry = chain.placed[1].entryFrame
        XCTAssertEqual(sample.frame.position.x.approximateDouble,
                       entry.position.x.approximateDouble, accuracy: 1e-4)
        XCTAssertEqual(sample.frame.position.z.approximateDouble,
                       entry.position.z.approximateDouble, accuracy: 1e-4)
    }

    func testSampleIsContinuousAcrossJoins() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([
            PieceID("straight"), PieceID("sharp_curve_l"), PieceID("rise_shallow"),
            PieceID("bank_r"), PieceID("gentle_curve_r")
        ])
        var previous = chain.sample(atArcLength: .zero)!.frame.position
        var cursor = Fixed(1, over: 2)
        while cursor < chain.totalLength {
            let current = chain.sample(atArcLength: cursor)!.frame.position
            let step = current.distance(to: previous)
            XCTAssertLessThan(step.approximateDouble, 1.0, "discontinuity at \(cursor)")
            previous = current
            cursor += Fixed(1, over: 2)
        }
    }

    func testPieceIndexLookupCoversWholeChain() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("stub"), PieceID("straight"), PieceID("long_run")])
        XCTAssertEqual(chain.pieceIndex(atArcLength: Fixed(1)), 0)
        XCTAssertEqual(chain.pieceIndex(atArcLength: Fixed(10)), 1)
        XCTAssertEqual(chain.pieceIndex(atArcLength: Fixed(40)), 2)
        XCTAssertNil(chain.pieceIndex(atArcLength: Fixed(-1)))
    }

    func testJunctionLeavesLooseSocket() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("straight"), PieceID("junction")])
        XCTAssertEqual(chain.looseSockets.count, 1)
        XCTAssertEqual(chain.looseSockets[0].originPieceIndex, 1)
    }

    func testSurfaceAndWidthLookup() {
        var chain = TrackChain(catalog: catalog)
        chain.appendAll([PieceID("straight"), PieceID("booster_strip"), PieceID("narrow_bridge")])
        XCTAssertEqual(chain.surface(atArcLength: Fixed(30)), .boost)
        XCTAssertEqual(chain.width(atArcLength: Fixed(50)), PieceCatalog.narrowWidth)
    }
}
