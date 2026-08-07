public struct PartID: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public enum PartGroup: String, Sendable, Hashable, Codable, CaseIterable {
    case hand
    case economy
    case physics
    case survival
}

public enum PartEffect: Sendable, Hashable, Codable {
    case extraHandSlot(Int)
    case drawDelayScale(Fixed)
    case discardCostScale(Fixed)
    case discardCooldownScale(Fixed)
    case sorterBias
    case previewNext
    case reserveSlot
    case twinDraw
    case straightCostScale(Fixed)
    case salvageFraction(Fixed)
    case gripScale(Fixed)
    case massScale(Fixed)
    case topSpeedScale(Fixed)
    case downforceBonus(Fixed)
    case landingToleranceBonus(Fixed)
    case bankEffectScale(Fixed)
    case widthToleranceScale(Fixed)
    case integrityBonus(Fixed)
    case scrapeCostScale(Fixed)
}

public struct Part: Sendable, Hashable, Codable, Identifiable {
    public var id: PartID
    public var name: String
    public var group: PartGroup
    public var effects: [PartEffect]

    public init(id: PartID, name: String, group: PartGroup, effects: [PartEffect]) {
        self.id = id
        self.name = name
        self.group = group
        self.effects = effects
    }
}

public struct PartEffects: Sendable, Hashable {
    public var extraHandSlots = 0
    public var drawDelayScale = Fixed.one
    public var discardCostScale = Fixed.one
    public var discardCooldownScale = Fixed.one
    public var straightCostScale = Fixed.one
    public var salvageFraction = Fixed(3, over: 10)
    public var gripScale = Fixed.one
    public var massScale = Fixed.one
    public var topSpeedScale = Fixed.one
    public var downforceBonus = Fixed.zero
    public var landingToleranceBonus = Fixed.zero
    public var bankEffectScale = Fixed.one
    public var widthToleranceScale = Fixed.one
    public var integrityBonus = Fixed.zero
    public var scrapeCostScale = Fixed.one
    public var sorter = false
    public var previewNext = false
    public var reserveSlot = false
    public var twinDraw = false

    public init() {}

    public static func aggregate(_ parts: [Part]) -> PartEffects {
        var result = PartEffects()
        for part in parts {
            for effect in part.effects {
                switch effect {
                case .extraHandSlot(let n): result.extraHandSlots += n
                case .drawDelayScale(let x): result.drawDelayScale *= x
                case .discardCostScale(let x): result.discardCostScale *= x
                case .discardCooldownScale(let x): result.discardCooldownScale *= x
                case .straightCostScale(let x): result.straightCostScale *= x
                case .salvageFraction(let x): result.salvageFraction = x
                case .gripScale(let x): result.gripScale *= x
                case .massScale(let x): result.massScale *= x
                case .topSpeedScale(let x): result.topSpeedScale *= x
                case .downforceBonus(let x): result.downforceBonus += x
                case .landingToleranceBonus(let x): result.landingToleranceBonus += x
                case .bankEffectScale(let x): result.bankEffectScale *= x
                case .widthToleranceScale(let x): result.widthToleranceScale *= x
                case .integrityBonus(let x): result.integrityBonus += x
                case .scrapeCostScale(let x): result.scrapeCostScale *= x
                case .sorterBias: result.sorter = true
                case .previewNext: result.previewNext = true
                case .reserveSlot: result.reserveSlot = true
                case .twinDraw: result.twinDraw = true
                }
            }
        }
        return result
    }

    public func applied(to spec: CarSpec) -> CarSpec {
        var tuned = spec
        tuned.grip *= gripScale
        tuned.mass *= massScale
        tuned.topSpeed *= topSpeedScale
        tuned.downforce += downforceBonus
        tuned.widthTolerance *= widthToleranceScale
        tuned.maxIntegrity += integrityBonus
        return tuned
    }
}

public enum PartCatalog {
    public static let all: [Part] = [
        Part(id: PartID("sixth_slot"), name: "Sixth Slot", group: .hand,
             effects: [.extraHandSlot(1)]),
        Part(id: PartID("fast_feed"), name: "Fast Feed", group: .hand,
             effects: [.drawDelayScale(Fixed(7, over: 10))]),
        Part(id: PartID("twin_draw"), name: "Twin Draw", group: .hand,
             effects: [.twinDraw]),
        Part(id: PartID("preview_next"), name: "Preview Next", group: .hand,
             effects: [.previewNext]),
        Part(id: PartID("free_discard"), name: "Free Discard", group: .hand,
             effects: [.discardCostScale(.zero)]),
        Part(id: PartID("rapid_discard"), name: "Rapid Discard", group: .hand,
             effects: [.discardCooldownScale(Fixed(1, over: 2))]),
        Part(id: PartID("sorter"), name: "Sorter", group: .hand,
             effects: [.sorterBias]),
        Part(id: PartID("sticky_hand"), name: "Sticky Hand", group: .hand,
             effects: [.reserveSlot]),

        Part(id: PartID("thrift"), name: "Thrift", group: .economy,
             effects: [.straightCostScale(Fixed(7, over: 10))]),
        Part(id: PartID("salvage"), name: "Salvage", group: .economy,
             effects: [.salvageFraction(Fixed(6, over: 10))]),

        Part(id: PartID("soft_compound"), name: "Soft Compound", group: .physics,
             effects: [.gripScale(Fixed(108, over: 100)), .topSpeedScale(Fixed(95, over: 100))]),
        Part(id: PartID("ballast_tune"), name: "Ballast Tune", group: .physics,
             effects: [.massScale(Fixed(9, over: 10))]),
        Part(id: PartID("wing"), name: "Wing", group: .physics,
             effects: [.downforceBonus(Fixed(15, over: 100))]),
        Part(id: PartID("landing_gear"), name: "Landing Gear", group: .physics,
             effects: [.landingToleranceBonus(degrees(10))]),
        Part(id: PartID("anti_roll"), name: "Anti-roll", group: .physics,
             effects: [.bankEffectScale(Fixed(14, over: 10))]),
        Part(id: PartID("wide_tyres"), name: "Wide Tyres", group: .physics,
             effects: [.widthToleranceScale(Fixed(12, over: 10)),
                       .topSpeedScale(Fixed(93, over: 100))]),

        Part(id: PartID("plating"), name: "Plating", group: .survival,
             effects: [.integrityBonus(Fixed(30)), .massScale(Fixed(105, over: 100))]),
        Part(id: PartID("scrape_guard"), name: "Scrape Guard", group: .survival,
             effects: [.scrapeCostScale(Fixed(1, over: 2))])
    ]

    public static let slotLimit = 3

    public static func part(_ id: PartID) -> Part? { all.first { $0.id == id } }

    public static func effects(_ ids: [PartID]) -> PartEffects {
        PartEffects.aggregate(ids.compactMap(part))
    }
}
