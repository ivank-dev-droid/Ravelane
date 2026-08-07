import XCTest
@testable import RavelaneCore

final class PhysicsTests: XCTestCase {
    private let catalog = PieceCatalog.cache
    private let spec = CarCatalog.starting
    private let world = WorldRules.foundry

    private func chain(_ ids: [String]) -> TrackChain {
        var built = TrackChain(catalog: catalog)
        built.appendAll(ids.map { PieceID($0) })
        return built
    }

    private func run(
        _ track: TrackChain,
        spec: CarSpec? = nil,
        world: WorldRules? = nil,
        startSpeed: Fixed? = nil,
        maxSteps: Int = 6000
    ) -> (car: CarState, events: [SimEvent], steps: Int) {
        let carSpec = spec ?? self.spec
        let rules = world ?? self.world
        var car = CarState.starting(spec: carSpec, world: rules)
        if let startSpeed { car.speed = startSpeed }
        var events: [SimEvent] = []
        var steps = 0
        while car.isRunning && steps < maxSteps {
            let result = Physics.step(car: car, chain: track, spec: carSpec, world: rules)
            car = result.car
            events.append(contentsOf: result.events)
            steps += 1
        }
        return (car, events, steps)
    }

    func testCarAcceleratesOnFlatTrack() {
        let track = chain(Array(repeating: "long_run", count: 6))
        let outcome = run(track, startSpeed: Fixed(12))
        XCTAssertEqual(outcome.car.mode, .finished)
        XCTAssertGreaterThan(outcome.car.speed, Fixed(12))
        XCTAssertLessThan(outcome.car.speed, spec.absoluteTopSpeed)
    }

    func testSpeedApproachesButNeverExceedsTopSpeed() {
        let track = chain(Array(repeating: "long_run", count: 60))
        let outcome = run(track, startSpeed: Fixed(10), maxSteps: 40000)
        XCTAssertLessThanOrEqual(outcome.car.speed, spec.absoluteTopSpeed)
        XCTAssertGreaterThan(outcome.car.speed, spec.absoluteTopSpeed * Fixed(8, over: 10))
    }

    func testDownhillGainsSpeedAndUphillLosesIt() {
        let downhill = run(chain(["drop_steep", "long_run", "long_run"]), startSpeed: Fixed(20))
        let uphill = run(chain(["rise_steep", "long_run", "long_run"]), startSpeed: Fixed(20))
        XCTAssertGreaterThan(downhill.car.speed, uphill.car.speed)
    }

    func testUphillCanStallAHeavyCar() {
        let ballast = CarCatalog.spec(CarID("ballast"))!
        let track = chain(["rise_steep", "rise_steep", "rise_steep", "long_run"])
        let outcome = run(track, spec: ballast, startSpeed: Fixed(8))
        XCTAssertLessThan(outcome.car.speed, Fixed(20))
    }

    func testGentleCurveIsSurvivableAtModerateSpeed() {
        let track = chain(["straight", "gentle_curve_l", "straight"])
        let outcome = run(track, startSpeed: Fixed(18))
        XCTAssertEqual(outcome.car.mode, .finished, "a gentle curve at 18 m/s must not throw the car off")
    }

    func testHairpinAtHighSpeedThrowsTheCarOff() {
        let track = chain(["straight", "hairpin_l", "straight"])
        let outcome = run(track, startSpeed: Fixed(42))
        XCTAssertEqual(outcome.car.mode, .crashed)
        XCTAssertEqual(outcome.car.crashReason, .ranOffTheEdge)
    }

    func testBankingRescuesACurveThatWouldOtherwiseFail() {
        let unbanked = run(chain(["sharp_curve_l", "sharp_curve_l", "straight"]), startSpeed: Fixed(30))
        let banked = run(chain(["banked_curve_l", "banked_curve_l", "straight"]), startSpeed: Fixed(30))
        XCTAssertEqual(unbanked.car.mode, .crashed)
        XCTAssertEqual(banked.car.mode, .finished)
    }

    func testBankCarriesIntoTheFollowingCurve() {
        var wrongWay = TrackChain(catalog: catalog)
        wrongWay.appendAll([PieceID("bank_r"), PieceID("sharp_curve_l"),
                            PieceID("sharp_curve_l"), PieceID("straight")])
        var rightWay = TrackChain(catalog: catalog)
        rightWay.appendAll([PieceID("bank_l"), PieceID("sharp_curve_l"),
                            PieceID("sharp_curve_l"), PieceID("straight")])

        let bad = run(wrongWay, startSpeed: Fixed(30))
        let good = run(rightWay, startSpeed: Fixed(30))
        XCTAssertGreaterThan(good.car.arcLength, bad.car.arcLength,
                             "a Bank piece must still be helping when the curve arrives")
    }

    func testBankAngleIsMeasuredFromTheRibbonNotAccumulated() {
        var track = TrackChain(catalog: catalog)
        track.appendAll([PieceID("bank_l"), PieceID("straight")])
        let insideBank = track.sample(atArcLength: Fixed(13))!
        let afterBank = track.sample(atArcLength: Fixed(20))!
        XCTAssertLessThan(insideBank.bank, -degrees(20))
        XCTAssertEqual(afterBank.bank.approximateDouble, insideBank.bank.approximateDouble,
                       accuracy: 0.05, "roll must persist past the piece that created it")
    }

    func testGripCarSurvivesWhatASlipperyCarDoesNot() {
        let spindle = CarCatalog.spec(CarID("spindle"))!
        let kite = CarCatalog.spec(CarID("kite"))!
        let track = chain(["sharp_curve_l", "sharp_curve_l", "straight"])
        let grippy = run(track, spec: spindle, startSpeed: Fixed(30))
        let slippery = run(track, spec: kite, startSpeed: Fixed(30))
        XCTAssertGreaterThan(grippy.car.arcLength, slippery.car.arcLength)
    }

    func testCrestLaunchesTheCarAtSpeed() {
        let track = chain(["long_run", "crest", "long_run", "long_run"])
        let outcome = run(track, startSpeed: Fixed(45))
        let launched = outcome.events.contains { if case .launched = $0 { return true }; return false }
        XCTAssertTrue(launched, "a crest taken at 45 m/s must unload the car")
    }

    func testCrestDoesNotLaunchAtLowSpeed() {
        let track = chain(["crest", "straight"])
        let outcome = run(track, startSpeed: Fixed(8))
        let launched = outcome.events.contains { if case .launched = $0 { return true }; return false }
        XCTAssertFalse(launched)
    }

    func testLaunchedCarLandsBackOnTheRibbon() {
        let track = chain(["long_run", "crest", "long_run", "long_run", "long_run"])
        let outcome = run(track, startSpeed: Fixed(45))
        let landed = outcome.events.contains { if case .landed = $0 { return true }; return false }
        XCTAssertTrue(landed, "the car must come back down onto the track")
        XCTAssertNotEqual(outcome.car.mode, .crashed)
    }

    func testBoosterAddsSpeedAndBrakeRemovesIt() {
        let boosted = run(chain(["straight", "booster_strip", "straight"]), startSpeed: Fixed(20))
        let braked = run(chain(["straight", "brake_strip", "straight"]), startSpeed: Fixed(20))
        XCTAssertGreaterThan(boosted.car.speed, braked.car.speed + Fixed(4))
    }

    func testRumbleStripCostsIntegrity() {
        let plain = run(chain(["straight", "straight", "straight"]), startSpeed: Fixed(20))
        let rumble = run(chain(["straight", "rumble_strip", "straight"]), startSpeed: Fixed(20))
        XCTAssertLessThanOrEqual(rumble.car.speed, plain.car.speed)
    }

    func testLowGravityWorldHoldsSpeedUphill() {
        let track = chain(["rise_steep", "long_run"])
        let foundry = run(track, world: .foundry, startSpeed: Fixed(25))
        let updraft = run(track, world: .updraft, startSpeed: Fixed(25))
        XCTAssertGreaterThan(updraft.car.speed, foundry.car.speed)
    }

    func testRunwayClockCountsDownInSeconds() {
        var track = TrackChain(catalog: catalog)
        track.appendAll(Array(repeating: PieceID("long_run"), count: 4))
        var car = CarState.starting(spec: spec, world: world)
        car.speed = Fixed(24)

        let start = Clocks.measure(car: car, chain: track, material: 100)
        XCTAssertEqual(start.runway.approximateDouble, 192.0, accuracy: 1e-3)
        XCTAssertEqual(start.runwaySeconds.approximateDouble, 8.0, accuracy: 1e-3)

        for _ in 0..<240 {
            car = Physics.step(car: car, chain: track, spec: spec, world: world).car
        }
        let later = Clocks.measure(car: car, chain: track, material: 100)
        XCTAssertLessThan(later.runway, start.runway)
    }

    func testRunningPastTheEndFinishesRatherThanCrashing() {
        let track = chain(["straight", "straight"])
        let outcome = run(track, startSpeed: Fixed(20))
        XCTAssertEqual(outcome.car.mode, .finished)
        XCTAssertEqual(outcome.car.arcLength, track.totalLength)
        XCTAssertTrue(outcome.events.contains(.reachedEnd))
    }

    func testSimulationIsReproducible() {
        let track = chain([
            "straight", "gentle_curve_l", "drop_shallow", "banked_curve_r",
            "long_run", "crest", "booster_strip", "sharp_curve_r", "long_run"
        ])
        let first = run(track, startSpeed: Fixed(22))
        let second = run(track, startSpeed: Fixed(22))
        XCTAssertEqual(first.car, second.car)
        XCTAssertEqual(first.steps, second.steps)
        XCTAssertEqual(first.events.count, second.events.count)
    }

    func testEveryCarCompletesAGentleTrack() {
        let track = chain(["straight", "gentle_curve_l", "long_run", "gentle_curve_r", "straight"])
        for carSpec in CarCatalog.all {
            let outcome = run(track, spec: carSpec, startSpeed: Fixed(14))
            XCTAssertEqual(outcome.car.mode, .finished, "\(carSpec.name) failed a gentle track")
        }
    }
}
