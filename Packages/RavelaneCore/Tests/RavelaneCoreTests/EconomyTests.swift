import Testing
@testable import RavelaneCore

@Suite("Economy")
struct EconomyTests {
    @Test("The starting car costs nothing and every other car costs something")
    func startingCarIsFree() {
        #expect(Shop.price(for: CarCatalog.starting) == 0)
        for spec in CarCatalog.all where spec.id != CarCatalog.starting.id {
            #expect(Shop.price(for: spec) >= 200)
        }
    }

    @Test("Prices land on clean fifties")
    func pricesAreRounded() {
        for spec in CarCatalog.all {
            #expect(Shop.price(for: spec) % 50 == 0)
        }
        for part in PartCatalog.all {
            #expect(Shop.price(for: part) % 50 == 0)
            #expect(Shop.price(for: part) > 0)
        }
    }

    @Test("A stronger car costs more than a weaker one")
    func strengthDrivesPrice() {
        let cinder = CarCatalog.spec(CarID("cinder"))!
        let loom = CarCatalog.spec(CarID("loom"))!
        #expect(Shop.price(for: cinder) > Shop.price(for: loom))
    }

    @Test("Tuning stops at the cap and never regresses a stat")
    func tuningRaisesAndCaps() {
        var tuning = Tuning()
        for _ in 0..<10 { tuning.raise(.grip) }
        #expect(tuning.level(.grip) == Tuning.maxLevel)

        let base = CarCatalog.starting
        let tuned = tuning.apply(to: base)
        #expect(tuned.grip > base.grip)
        #expect(tuned.topSpeed == base.topSpeed)
    }

    @Test("Each tuning track moves only what it claims to")
    func tracksAreDistinct() {
        let base = CarCatalog.starting

        var power = Tuning()
        power.raise(.power)
        let quick = power.apply(to: base)
        #expect(quick.acceleration > base.acceleration)
        #expect(quick.topSpeed > base.topSpeed)
        #expect(quick.grip == base.grip)

        var frame = Tuning()
        frame.raise(.frame)
        let tough = frame.apply(to: base)
        #expect(tough.maxIntegrity > base.maxIntegrity)
        #expect(tough.mass < base.mass)
    }

    @Test("Fully tuning one track costs the sum of its steps")
    func spentAddsUp() {
        var tuning = Tuning()
        tuning.raise(.grip)
        tuning.raise(.grip)
        #expect(tuning.spent == Tuning.cost(1) + Tuning.cost(2))
    }

    @Test("A failed run pays nothing, a first clear pays a bonus")
    func payoutRespectsOutcome() {
        let summary = LevelCatalog.summaries[0]
        let lost = LevelResult(completed: false, piecesUsed: 4, elapsed: .zero,
                               coresCollected: 1, coreTotal: 2, crashReason: nil)
        #expect(Payout.credits(summary: summary, result: lost, stars: 0, firstClear: true) == 0)

        let won = LevelResult(completed: true, piecesUsed: 4, elapsed: .zero,
                              coresCollected: 2, coreTotal: 2, crashReason: nil)
        let repeated = Payout.credits(summary: summary, result: won, stars: 3, firstClear: false)
        let first = Payout.credits(summary: summary, result: won, stars: 3, firstClear: true)
        #expect(first - repeated == Payout.firstClearBonus)
        #expect(repeated > 0)
    }

    @Test("Collecting more cores pays more")
    func coresPay() {
        let summary = LevelCatalog.summaries[0]
        func credits(cores: Int) -> Int {
            let result = LevelResult(completed: true, piecesUsed: 4, elapsed: .zero,
                                     coresCollected: cores, coreTotal: 3, crashReason: nil)
            return Payout.credits(summary: summary, result: result, stars: 1, firstClear: false)
        }
        #expect(credits(cores: 3) > credits(cores: 1))
    }
}
