import SwiftUI
import RavelaneCore

struct CodexView: View {
    @State private var section: Section = .pieces
    @Environment(\.dismiss) private var dismiss

    enum Section: String, CaseIterable, Identifiable {
        case pieces, cars, parts
        var id: String { rawValue }
        var label: String {
            switch self {
            case .pieces: return "Pieces"
            case .cars: return "Cars"
            case .parts: return "Parts"
            }
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    BackChip { dismiss() }
                    Text("CODEX")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .kerning(4)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(20)

                ScrollView {
                    VStack(spacing: 10) {
                        switch section {
                        case .pieces: pieceList
                        case .cars: carList
                        case .parts: partList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(Theme.neon)
    }

    private var pieceList: some View {
        ForEach(PieceClass.allCases, id: \.self) { pieceClass in
            let pieces = PieceCatalog.all.filter { $0.pieceClass == pieceClass }
            if !pieces.isEmpty {
                GroupHeader(title: pieceClass.rawValue, count: pieces.count)
                ForEach(pieces) { piece in
                    Card {
                        HStack(spacing: 12) {
                        PieceShapeView(piece: piece, lineWidth: 2.2)
                            .frame(width: 52, height: 44)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(piece.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(piece.cost)◈")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.gold)
                            }
                            Text(PieceCopy.line(for: piece))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.cold)
                            Text(PieceCopy.role(for: piece))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.dim)
                        }
                        }
                    }
                }
            }
        }
    }

    private var carList: some View {
        ForEach(CarCatalog.all) { car in
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(car.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 14) {
                        Bar(label: "GRIP", value: car.grip.approximateDouble / 1.4)
                        Bar(label: "ACCEL", value: car.acceleration.approximateDouble / 1.7)
                        Bar(label: "TOP", value: car.topSpeed.approximateDouble / 1.4)
                        Bar(label: "MASS", value: car.mass.approximateDouble / 2.5)
                    }
                    Text(CarCopy.note(for: car))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.dim)
                }
            }
        }
    }

    private var partList: some View {
        ForEach(PartGroup.allCases, id: \.self) { group in
            let parts = PartCatalog.all.filter { $0.group == group }
            if !parts.isEmpty {
                GroupHeader(title: group.rawValue, count: parts.count)
                ForEach(parts) { part in
                    Card {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(part.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(PartCopy.describe(part))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.cold)
                        }
                    }
                }
            }
        }
    }
}

struct GroupHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .kerning(3)
                .foregroundStyle(Theme.neon)
            Spacer()
            Text("\(count)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.dim)
        }
        .padding(.top, 10)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1)
            }
    }
}

private struct Bar: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.dim)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.panelStrong)
                    Capsule().fill(Theme.neon)
                        .frame(width: geo.size.width * min(1, max(0.05, value)))
                }
            }
            .frame(height: 4)
        }
    }
}

enum CarCopy {
    static func note(for car: CarSpec) -> String {
        switch car.id.rawValue {
        case "fettle": return "The baseline. Nothing to learn around."
        case "shim": return "Light and twitchy. Climbs anything, slides everywhere."
        case "ballast": return "Heavy. Stalls on a steep rise, unshakeable in a corner."
        case "kite": return "Floats on jumps, huge air, awful grip."
        case "anvil": return "Ignores scrapes. Hopeless uphill."
        case "sliver": return "Fastest top speed, narrowest margin."
        case "burr": return "Grip grows with speed."
        case "tack": return "Forgiving. The car to learn a world on."
        case "cinder": return "Explosive acceleration, poor grip."
        case "loom": return "Slow and wide, which means more time to think."
        case "spindle": return "Banking specialist."
        case "ravelane": return "An extra hand slot and half the draw delay."
        default: return ""
        }
    }
}

enum PartCopy {
    static func describe(_ part: Part) -> String {
        part.effects.map { effect in
            switch effect {
            case .extraHandSlot(let n): return "+\(n) hand slot"
            case .drawDelayScale(let x): return "draw delay ×\(trim(x))"
            case .discardCostScale(let x): return "discard cost ×\(trim(x))"
            case .discardCooldownScale(let x): return "discard cooldown ×\(trim(x))"
            case .sorterBias: return "draws bias toward what you lack"
            case .previewNext: return "see the next piece"
            case .reserveSlot: return "one slot never auto-refills"
            case .twinDraw: return "two slots refill at once"
            case .straightCostScale(let x): return "straights cost ×\(trim(x))"
            case .salvageFraction(let x): return "discard refunds \(Int(x.approximateDouble * 100))%"
            case .gripScale(let x): return "grip ×\(trim(x))"
            case .massScale(let x): return "mass ×\(trim(x))"
            case .topSpeedScale(let x): return "top speed ×\(trim(x))"
            case .downforceBonus(let x): return "downforce +\(trim(x))"
            case .landingToleranceBonus: return "wider landing angle"
            case .bankEffectScale(let x): return "banking ×\(trim(x))"
            case .widthToleranceScale(let x): return "usable width ×\(trim(x))"
            case .integrityBonus(let x): return "+\(x.whole) integrity"
            case .scrapeCostScale(let x): return "scrapes cost ×\(trim(x))"
            }
        }.joined(separator: " · ")
    }

    private static func trim(_ value: Fixed) -> String {
        let rounded = (value.approximateDouble * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
