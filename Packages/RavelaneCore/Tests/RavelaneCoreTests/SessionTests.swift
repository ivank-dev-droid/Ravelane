import XCTest
@testable import RavelaneCore

final class SessionTests: XCTestCase {
    private func session(
        deck: Deck = DeckPresets.runway,
        parts: [PartID] = [],
        spec: CarSpec = CarCatalog.starting,
        material: Int = Session.startingMaterial,
        seed: UInt64 = 42
    ) -> Session {
        Session(deck: deck, spec: spec, parts: parts, seed: seed, material: material)
    }

    private func greedyPolicy(_ s: inout Session) {
        guard s.clocks.runwaySeconds < Fixed(9) else { return }
        if let slot = s.placeableSlots.first { s.place(slot: slot) }
    }

    func testDeckPresetsAreValid() {
        for preset in DeckPresets.all {
            let problems = preset.deck.problems(against: PieceCatalog.cache)
            XCTAssertTrue(problems.isEmpty, "\(preset.name): \(problems)")
            XCTAssertLessThanOrEqual(preset.deck.entries.count, Deck.slotLimit)
        }
    }

    func testDeckRejectsBadEntries() {
        let bad = Deck([("straight", 9), ("straight", 1), ("nope", 1)])
        let problems = bad.problems(against: PieceCatalog.cache)
        XCTAssertTrue(problems.contains(.countOutOfRange(PieceID("straight"), 9)))
        XCTAssertTrue(problems.contains(.duplicateEntry(PieceID("straight"))))
        XCTAssertTrue(problems.contains(.unknownPiece(PieceID("nope"))))
    }

    func testHandStartsFull() {
        let s = session()
        XCTAssertEqual(s.handSize, Session.baseHandSize)
        XCTAssertTrue(s.hand.allSatisfy(\.isFilled))
    }

    func testSixthSlotPartWidensTheHand() {
        let s = session(parts: [PartID("sixth_slot")])
        XCTAssertEqual(s.handSize, Session.baseHandSize + 1)
        XCTAssertTrue(s.hand.allSatisfy(\.isFilled))
    }

    func testPlacingSpendsMaterialAndExtendsTheTrack() {
        var s = session()
        let before = s.chain.totalLength
        let money = s.material
        let id = s.hand[0].piece!
        XCTAssertNil(s.place(slot: 0))
        XCTAssertGreaterThan(s.chain.totalLength, before)
        XCTAssertEqual(s.material, money - s.cost(of: id))
        XCTAssertEqual(s.placedCount, 1)
        XCTAssertNil(s.hand[0].piece)
    }

    func testPlacingAnEmptySlotIsRejected() {
        var s = session()
        s.place(slot: 0)
        XCTAssertEqual(s.place(slot: 0), .slotEmpty)
        XCTAssertEqual(s.place(slot: 99), .slotOutOfRange)
    }

    func testPlacingIsRejectedWithoutMaterial() {
        var s = session(material: 1)
        let rejection = s.place(slot: 0)
        guard case .notEnoughMaterial = rejection else {
            return XCTFail("expected a material rejection, got \(String(describing: rejection))")
        }
    }

    func testSlotRefillsAfterTheDrawDelay() {
        var s = session()
        s.place(slot: 0)
        XCTAssertNil(s.hand[0].piece)
        for _ in 0..<40 { s.step() }
        XCTAssertNil(s.hand[0].piece, "the slot must not refill instantly")
        for _ in 0..<200 { s.step() }
        XCTAssertNotNil(s.hand[0].piece)
    }

    func testFastFeedRefillsSooner() {
        var slow = session()
        var fast = session(parts: [PartID("fast_feed")])
        slow.place(slot: 0)
        fast.place(slot: 0)
        for _ in 0..<130 {
            slow.step()
            fast.step()
        }
        XCTAssertNotNil(fast.hand[0].piece)
        XCTAssertNil(slow.hand[0].piece)
    }

    func testDiscardRefundsAndGoesOnCooldown() {
        var s = session()
        let money = s.material
        XCTAssertNil(s.discard(slot: 1))
        XCTAssertGreaterThan(s.material, money)
        XCTAssertEqual(s.discardCount, 1)
        guard case .onCooldown = s.discard(slot: 2) else {
            return XCTFail("a second discard must be blocked by the cooldown")
        }
    }

    func testFreeDiscardPartRemovesTheRefundCost() {
        var normal = session()
        var free = session(parts: [PartID("free_discard")])
        normal.discard(slot: 0)
        free.discard(slot: 0)
        XCTAssertGreaterThanOrEqual(free.material, normal.material)
    }

    func testReservedSlotCannotBeDiscarded() {
        var s = session(parts: [PartID("sticky_hand")])
        let last = s.handSize - 1
        XCTAssertEqual(s.discard(slot: last), .slotReserved)
    }

    func testThriftLowersStraightCostsOnly() {
        let plain = session()
        let thrifty = session(parts: [PartID("thrift")])
        XCTAssertLessThan(thrifty.cost(of: PieceID("long_run")), plain.cost(of: PieceID("long_run")))
        XCTAssertEqual(thrifty.cost(of: PieceID("hairpin_l")), plain.cost(of: PieceID("hairpin_l")))
    }

    func testPartsRetuneTheCar() {
        let plain = session()
        let soft = session(parts: [PartID("soft_compound")])
        XCTAssertGreaterThan(soft.spec.grip, plain.spec.grip)
        XCTAssertLessThan(soft.spec.topSpeed, plain.spec.topSpeed)
        let plated = session(parts: [PartID("plating")])
        XCTAssertGreaterThan(plated.spec.maxIntegrity, plain.spec.maxIntegrity)
        XCTAssertGreaterThan(plated.spec.mass, plain.spec.mass)
    }

    func testRunwayDrainsWhenNothingIsPlaced() {
        var s = session()
        let start = s.clocks.runwaySeconds
        for _ in 0..<200 { s.step() }
        XCTAssertLessThan(s.clocks.runwaySeconds, start)
    }

    func testCarRunsOutOfTrackIfTheBuilderDoesNothing() {
        var s = session()
        var steps = 0
        while s.isRunning && steps < 4000 {
            s.step()
            steps += 1
        }
        XCTAssertFalse(s.isRunning)
        XCTAssertEqual(s.car.mode, .finished)
    }

    func testGreedyBuilderKeepsTheCarAliveMuchLonger() {
        var idle = session()
        var builder = session()

        var idleSteps = 0
        while idle.isRunning && idleSteps < 8000 { idle.step(); idleSteps += 1 }

        let builtSteps = builder.run(maxSteps: 8000, policy: greedyPolicy)

        XCTAssertGreaterThan(builder.chain.totalLength, idle.chain.totalLength * Fixed(3))
        XCTAssertGreaterThan(builtSteps, idleSteps)
        XCTAssertGreaterThan(builder.placedCount, 8)
    }

    func testBuilderEarnsMaterialFromDistance() {
        var s = session()
        let start = s.material
        _ = s.run(maxSteps: 6000, policy: greedyPolicy)
        let earned = s.log.contains { if case .materialEarned(_, .distance) = $0 { return true }; return false }
        XCTAssertTrue(earned, "distance must pay something back")
        let spent = s.log.reduce(0) { total, event in
            if case .placed(_, let cost) = event { return total + cost }
            return total
        }
        XCTAssertGreaterThan(spent, 0)
        XCTAssertGreaterThan(s.material + spent, start, "earnings must exceed the starting purse plus nothing")
    }

    func testSelfIntersectionIsRejected() {
        var s = Session(deck: Deck([("hairpin_l", 5)]), seed: 7, material: 100000)
        var rejections = 0
        var placements = 0
        for _ in 0..<400 {
            for slot in 0..<s.handSize {
                switch s.canPlace(slot: slot) {
                case .wouldIntersect: rejections += 1
                case nil: s.place(slot: slot); placements += 1
                default: break
                }
            }
            s.step()
        }
        XCTAssertGreaterThan(placements, 0)
        XCTAssertGreaterThan(rejections, 0, "a deck of nothing but hairpins must eventually collide with itself")
    }

    func testSessionIsDeterministicForAGivenSeed() {
        var a = session(seed: 991)
        var b = session(seed: 991)
        _ = a.run(maxSteps: 3000, policy: greedyPolicy)
        _ = b.run(maxSteps: 3000, policy: greedyPolicy)
        XCTAssertEqual(a.car, b.car)
        XCTAssertEqual(a.material, b.material)
        XCTAssertEqual(a.placedCount, b.placedCount)
        XCTAssertEqual(a.chain.pieceIDs, b.chain.pieceIDs)
    }

    func testDifferentSeedsProduceDifferentTracks() {
        var a = session(seed: 1)
        var b = session(seed: 2)
        _ = a.run(maxSteps: 3000, policy: greedyPolicy)
        _ = b.run(maxSteps: 3000, policy: greedyPolicy)
        XCTAssertNotEqual(a.chain.pieceIDs, b.chain.pieceIDs)
    }

    func testEveryPresetDeckCanSustainARun() {
        guard let level = LevelCatalog.level(LevelID("foundry_05")) else {
            return XCTFail("missing level")
        }
        for preset in DeckPresets.all {
            var s = Session(deck: preset.deck, seed: 5, level: level)
            _ = s.run(maxSteps: 14000, policy: greedyPolicy)
            XCTAssertGreaterThan(s.placedCount, 5, "\(preset.name) built almost nothing")
            XCTAssertGreaterThan(s.chain.totalLength, Fixed(200), "\(preset.name) went nowhere")
        }
    }

    func testEveryLevelDeckKeepsTheCorePieces() {
        for summary in LevelCatalog.summaries {
            guard let level = LevelCatalog.level(summary.id) else { continue }
            let stripped = Deck(entries: [DeckEntry(piece: PieceID("stub"), count: 3)])
            let session = Session(deck: stripped, level: level)
            let core = Archetype.core(from: level.allowedPieces)
            for id in core {
                XCTAssertTrue(session.deck.contains(id),
                              "\(level.id): core piece \(id) was dropped from the deck")
            }
        }
    }

    func testHandAlwaysOffersSomethingPlayable() {
        for summary in LevelCatalog.summaries.prefix(24) {
            guard let level = LevelCatalog.level(summary.id) else { continue }
            var session = Session(deck: level.deck(), level: level)
            var steps = 0
            var starved = 0
            while session.isRunning && steps < 3000 {
                if session.isBoxedIn { starved += 1 }
                if let slot = session.placeableSlots.first,
                   session.clocks.runwaySeconds < Fixed(5) {
                    session.place(slot: slot)
                }
                session.step()
                steps += 1
            }
            XCTAssertLessThan(starved, 4,
                              "\(level.id) boxed the player in with Material still in hand")
        }
    }

    func testAUselessDeckIsRepairedIntoAPlayableOne() {
        guard let level = LevelCatalog.level(LevelCatalog.summaries[0].id) else {
            return XCTFail("no level")
        }
        let useless = Deck([("loop", 3)])
        XCTAssertFalse(useless.missingCore(from: level.allowedPieces,
                                           catalog: PieceCatalog.cache).isEmpty)

        let session = Session(deck: useless, level: level)
        XCTAssertTrue(useless.missingCore(from: level.allowedPieces, catalog: PieceCatalog.cache)
            .allSatisfy { session.deck.contains($0) },
            "a deck missing the core must be completed before play, not left unwinnable")
        XCTAssertFalse(session.playablePieces.isEmpty,
                       "there must always be something the player can place")
    }

    func testTheDeckCanAlwaysReachEveryLevelsGoal() {
        for summary in LevelCatalog.summaries {
            guard let level = LevelCatalog.level(summary.id) else { continue }
            let session = Session(deck: level.deck(), level: level)
            let held = Set(session.deck.pieceTypes)
            for id in level.solution {
                XCTAssertTrue(held.contains(id),
                              "\(level.id): the deck cannot supply \(id), which its own solution needs")
            }
        }
    }

    func testHandAlwaysOffersBothDirections() {
        for summary in LevelCatalog.summaries.prefix(18) {
            guard let level = LevelCatalog.level(summary.id) else { continue }
            var session = Session(deck: level.deck(), level: level)
            var oneSided = 0
            var steps = 0
            while session.isRunning && steps < 2500 {
                if session.hand.allSatisfy(\.isFilled) {
                    let roles = session.handRoles
                    if !roles.contains(.left) || !roles.contains(.right) { oneSided += 1 }
                }
                if let slot = session.placeableSlots.first,
                   session.clocks.runwaySeconds < Fixed(5) {
                    session.place(slot: slot)
                }
                session.step()
                steps += 1
            }
            XCTAssertLessThan(oneSided, 60,
                              "\(level.id) left the player unable to turn one way")
        }
    }

    func testTheOpeningLevelsAreReachableByAimingAlone() {
        for id in ["foundry_01", "foundry_02"] {
            guard let level = LevelCatalog.level(LevelID(id)) else {
                return XCTFail("missing \(id)")
            }
            var session = Session(deck: level.deck(), level: level)
            var steps = 0
            while session.isRunning && steps < 12000 {
                if session.clocks.runwaySeconds < Fixed(5) {
                    let gates = level.objectiveOrder
                    let target = gates[Swift.min(session.objectives.nextCheckpoint, gates.count - 1)]
                    let best = session.placeableSlots.min { left, right in
                        func score(_ slot: Int) -> Fixed {
                            guard let pieceID = session.hand[slot].piece,
                                  let samples = session.chain.projectedSamples(afterAppending: pieceID),
                                  let tail = samples.last else { return Fixed(99999) }
                            let toTarget = target.position - tail.frame.position
                            let distance = toTarget.length
                            let heading = distance.raw == 0
                                ? Fixed.one
                                : toTarget.normalized.dot(tail.frame.forward)
                            return distance + (.one - heading) * Fixed(70)
                        }
                        return score(left) < score(right)
                    }
                    if let best { session.place(slot: best) }
                }
                session.step()
                steps += 1
            }
            XCTAssertTrue(session.objectives.reachedGoal,
                          "\(id) must be reachable by simply aiming at the goal")
        }
    }

    func testTheCarNeverOutrunsTheBuilder() {
        let topSpeed = CarCatalog.starting.absoluteTopSpeed.approximateDouble
        let slots = Double(Session.baseHandSize)
        let refill = Session.baseDrawDelay.approximateDouble
        let averagePieceLength = 20.0
        let buildRate = slots / refill * averagePieceLength
        XCTAssertGreaterThan(buildRate, topSpeed * 1.4,
            "the hand can lay \(Int(buildRate)) m/s of track while the car does \(Int(topSpeed)) m/s")
    }
}
