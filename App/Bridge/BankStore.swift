import Foundation
import Observation
import RavelaneCore

@MainActor
@Observable
final class BankStore {
    static let shared = BankStore()

    static let openingBalance = 250

    private(set) var credits: Int
    private(set) var ownedCars: Set<String>
    private(set) var ownedParts: Set<String>
    private(set) var tuning: [String: Tuning]

    private let store = UserDefaults.standard

    private enum Keys {
        static let credits = "ravelane.credits"
        static let cars = "ravelane.ownedCars"
        static let parts = "ravelane.ownedParts"
        static let tuning = "ravelane.tuning"
        static let opened = "ravelane.bankOpened"
    }

    private init() {
        if !store.bool(forKey: Keys.opened) {
            store.set(true, forKey: Keys.opened)
            store.set(BankStore.openingBalance, forKey: Keys.credits)
            store.set([CarCatalog.starting.id.rawValue], forKey: Keys.cars)
        }
        var garage = Set(store.stringArray(forKey: Keys.cars) ?? [])
        garage.insert(CarCatalog.starting.id.rawValue)

        var stored: [String: Tuning] = [:]
        if let raw = store.data(forKey: Keys.tuning),
           let decoded = try? JSONDecoder().decode([String: Tuning].self, from: raw) {
            stored = decoded
        }

        credits = store.integer(forKey: Keys.credits)
        ownedCars = garage
        ownedParts = Set(store.stringArray(forKey: Keys.parts) ?? [])
        tuning = stored
    }

    func owns(car id: CarID) -> Bool { ownedCars.contains(id.rawValue) }
    func owns(part id: PartID) -> Bool { ownedParts.contains(id.rawValue) }

    func tuning(for id: CarID) -> Tuning { tuning[id.rawValue] ?? Tuning() }

    func canAfford(_ price: Int) -> Bool { credits >= price }

    @discardableResult
    func buy(car spec: CarSpec) -> Bool {
        let price = Shop.price(for: spec)
        guard !owns(car: spec.id), canAfford(price) else { return false }
        credits -= price
        ownedCars.insert(spec.id.rawValue)
        persist()
        return true
    }

    @discardableResult
    func buy(part: Part) -> Bool {
        let price = Shop.price(for: part)
        guard !owns(part: part.id), canAfford(price) else { return false }
        credits -= price
        ownedParts.insert(part.id.rawValue)
        persist()
        return true
    }

    @discardableResult
    func upgrade(car id: CarID, track: TuningTrack) -> Bool {
        var current = tuning(for: id)
        let next = current.level(track) + 1
        guard next <= Tuning.maxLevel, canAfford(Tuning.cost(next)) else { return false }
        credits -= Tuning.cost(next)
        current.raise(track)
        tuning[id.rawValue] = current
        persist()
        return true
    }

    func deposit(_ amount: Int) {
        guard amount > 0 else { return }
        credits += amount
        persist()
    }

    private func persist() {
        store.set(credits, forKey: Keys.credits)
        store.set(Array(ownedCars), forKey: Keys.cars)
        store.set(Array(ownedParts), forKey: Keys.parts)
        if let raw = try? JSONEncoder().encode(tuning) {
            store.set(raw, forKey: Keys.tuning)
        }
    }
}
