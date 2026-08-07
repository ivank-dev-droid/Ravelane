import XCTest
@testable import RavelaneCore

final class LevelTests: XCTestCase {
    func testEveryWorldIsFullyPopulated() {
        XCTAssertEqual(LevelCatalog.summaries.count, WorldID.allCases.count * LevelForge.levelsPerWorld)
        for world in WorldID.allCases {
            XCTAssertEqual(LevelCatalog.summaries(in: world).count, LevelForge.levelsPerWorld,
                           "\(world) is short of levels")
        }
    }

    func testLevelIdentifiersAreUnique() {
        var seen = Set<String>()
        for level in LevelCatalog.all {
            XCTAssertTrue(seen.insert(level.id.rawValue).inserted, "duplicate \(level.id)")
        }
    }

    func testEveryLevelHasAStoredSolution() {
        for level in LevelCatalog.all {
            XCTAssertFalse(level.solution.isEmpty, "\(level.id) has no stored solution")
        }
    }

    func testEverySolutionUsesOnlyAllowedPieces() {
        for level in LevelCatalog.all {
            let allowed = Set(level.allowedPieces)
            for id in level.solution {
                XCTAssertTrue(allowed.contains(id), "\(level.id) uses \(id), which is not in its palette")
            }
        }
    }

    func testEverySolutionDrivesToTheGoal() {
        for level in LevelCatalog.all {
            let problem = LevelRunner.verify(level: level)
            XCTAssertNil(problem, "\(level.id): \(String(describing: problem))")
        }
    }

    func testEverySolutionEarnsAtLeastOneStar() {
        for level in LevelCatalog.all {
            let played = LevelRunner.play(level: level)
            XCTAssertGreaterThanOrEqual(played.result.stars(for: level), 1, "\(level.id) scored nothing")
        }
    }

    func testSolutionsAreWithinPar() {
        for level in LevelCatalog.all {
            XCTAssertLessThanOrEqual(level.solution.count, level.parPieces,
                                     "\(level.id) cannot be completed within its own par")
        }
    }

    func testDifficultyRisesWithinAWorld() {
        for world in WorldID.allCases {
            let levels = LevelCatalog.levels(in: world)
            XCTAssertEqual(levels.map(\.parPieces), levels.map(\.parPieces).sorted(),
                           "\(world) par counts are not monotonic")
            XCTAssertGreaterThan(levels.last!.solution.count, levels.first!.solution.count,
                                 "\(world) does not get longer")
        }
    }

    func testCheckpointsAndCoresGrowWithProgress() {
        let first = LevelCatalog.levels(in: .foundry).first!
        let last = LevelCatalog.levels(in: .foundry).last!
        XCTAssertEqual(first.checkpoints.count, 0)
        XCTAssertGreaterThanOrEqual(last.checkpoints.count, 2)
        XCTAssertGreaterThan(last.cores.count, first.cores.count)
    }

    func testForbiddenVolumesDoNotSitOnTheSolution() {
        for level in LevelCatalog.all {
            var chain = TrackChain(catalog: PieceCatalog.cache)
            chain.appendAll(level.plinth)
            chain.appendAll(level.solution)
            for index in 0..<chain.placed.count {
                for capsule in ClearanceBuilder.capsules(for: chain, pieceIndex: index) {
                    for volume in level.forbidden {
                        XCTAssertFalse(volume.intersects(capsule),
                                       "\(level.id) blocks its own solution at piece \(index)")
                    }
                }
            }
        }
    }

    func testGateDetectsAPassingSegment() {
        let gate = Gate(position: Vec3(.zero, .zero, Fixed(10)), radius: Fixed(5))
        XCTAssertTrue(gate.isCrossed(from: Vec3(.zero, .zero, Fixed(8)), to: Vec3(.zero, .zero, Fixed(12))))
        XCTAssertFalse(gate.isCrossed(from: Vec3(Fixed(40), .zero, Fixed(8)), to: Vec3(Fixed(40), .zero, Fixed(12))))
    }

    func testVolumeContainmentAndDistance() {
        let box = Volume.box(center: .zero, halfExtents: Vec3(Fixed(5), Fixed(5), Fixed(5)))
        XCTAssertTrue(box.contains(Vec3(Fixed(1), Fixed(1), Fixed(1))))
        XCTAssertFalse(box.contains(Vec3(Fixed(9), .zero, .zero)))

        let sphere = Volume.sphere(center: .zero, radius: Fixed(4))
        XCTAssertTrue(sphere.contains(Vec3(Fixed(3), .zero, .zero)))
        XCTAssertEqual(sphere.distanceSquared(to: Vec3(Fixed(8), .zero, .zero)).approximateDouble,
                       16.0, accuracy: 1e-3)
    }

    func testPulseHazardTurnsOnAndOff() {
        let hazard = Hazard(
            volume: .sphere(center: .zero, radius: Fixed(5)),
            motion: .pulse(period: Fixed(4), dutyCycle: Fixed(1, over: 2), phase: .zero)
        )
        XCTAssertTrue(hazard.isActive(at: Fixed(1)))
        XCTAssertFalse(hazard.isActive(at: Fixed(3)))
        XCTAssertTrue(hazard.isActive(at: Fixed(5)))
    }

    func testStarsRequireParAndCores() {
        let level = LevelCatalog.all.first!
        let bare = LevelResult(completed: true, piecesUsed: level.parPieces + 5,
                               elapsed: Fixed(10), coresCollected: 0,
                               coreTotal: level.cores.count, crashReason: nil)
        XCTAssertEqual(bare.stars(for: level), 1)

        let perfect = LevelResult(completed: true, piecesUsed: level.parPieces,
                                  elapsed: Fixed(1), coresCollected: level.cores.count,
                                  coreTotal: level.cores.count, crashReason: nil)
        XCTAssertEqual(perfect.stars(for: level), 3)

        let failed = LevelResult(completed: false, piecesUsed: 1, elapsed: .zero,
                                 coresCollected: 0, coreTotal: 1, crashReason: .fell)
        XCTAssertEqual(failed.stars(for: level), 0)
    }

    func testSummariesAreCheapAndComplete() {
        for summary in LevelCatalog.summaries {
            XCTAssertTrue(summary.isSolved, "\(summary.id) has no stored solution")
            XCTAssertGreaterThan(summary.parPieces, 0)
            XCTAssertGreaterThan(summary.coreCount, 0)
            XCTAssertNotNil(LevelCatalog.level(summary.id), "\(summary.id) cannot be rebuilt")
        }
    }

    func testRebuiltLevelMatchesItsSummary() {
        for summary in LevelCatalog.summaries {
            guard let level = LevelCatalog.level(summary.id) else { continue }
            XCTAssertEqual(level.id, summary.id)
            XCTAssertEqual(level.cores.count, summary.coreCount)
            XCTAssertEqual(level.checkpoints.count, summary.checkpointCount)
            XCTAssertEqual(level.parPieces, summary.parPieces)
        }
    }

    func testLevelPlaythroughIsDeterministic() {
        let level = LevelCatalog.levels(in: .foundry)[4]
        let first = LevelRunner.play(level: level)
        let second = LevelRunner.play(level: level)
        XCTAssertEqual(first.result, second.result)
        XCTAssertEqual(first.session.chain.pieceIDs, second.session.chain.pieceIDs)
    }

    func testStalledCarIsDetectedRatherThanFrozen() {
        var chain = TrackChain(catalog: PieceCatalog.cache)
        chain.appendAll(Array(repeating: PieceID("rise_steep"), count: 4))
        var car = CarState.starting(spec: CarCatalog.starting, world: .foundry)
        car.speed = Fixed(6)
        var steps = 0
        while car.isRunning && steps < 20000 {
            car = Physics.step(car: car, chain: chain, spec: CarCatalog.starting, world: .foundry).car
            steps += 1
        }
        XCTAssertEqual(car.mode, .crashed)
        XCTAssertEqual(car.crashReason, .stalled)
    }

    func testCoresSitOnTheRouteAtOneHeight() {
        for summary in LevelCatalog.summaries.prefix(30) {
            guard let level = LevelCatalog.level(summary.id) else { continue }
            var chain = TrackChain(catalog: PieceCatalog.cache)
            chain.appendAll(level.plinth)
            chain.appendAll(level.solution)

            for core in level.cores {
                var nearestFlat = Fixed(99999)
                var liftAtNearest = Fixed.zero
                var cursor = Fixed.zero
                while cursor <= chain.totalLength {
                    if let sample = chain.sample(atArcLength: cursor) {
                        let flat = Vec3(core.position.x - sample.position.x, .zero,
                                        core.position.z - sample.position.z).length
                        if flat < nearestFlat {
                            nearestFlat = flat
                            liftAtNearest = core.position.y - sample.position.y
                        }
                    }
                    cursor += Fixed(1)
                }
                XCTAssertLessThan(nearestFlat, Fixed(3),
                                  "\(level.id): a core is not centred on the route")
                XCTAssertEqual(liftAtNearest.approximateDouble,
                               Core.hoverHeight.approximateDouble,
                               accuracy: 0.6,
                               "\(level.id): a core is not at the standard height above the track")
            }
        }
    }

    func testDrivingTheSolutionCollectsEveryCore() {
        for summary in LevelCatalog.summaries.prefix(30) {
            guard let level = LevelCatalog.level(summary.id) else { continue }
            let played = LevelRunner.play(level: level)
            XCTAssertEqual(played.result.coresCollected, played.result.coreTotal,
                           "\(level.id): driving its own route missed \(played.result.coreTotal - played.result.coresCollected) cores")
        }
    }
}
