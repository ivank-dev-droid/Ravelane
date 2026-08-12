import SwiftUI
import RavelaneCore

struct ShopView: View {
    @State private var bank = BankStore.shared
    @State private var settings = GameSettings.shared
    @State private var counter: Counter = .cars
    @Environment(\.dismiss) private var dismiss

    enum Counter: String, CaseIterable, Identifiable {
        case cars, parts, tuning
        var id: String { rawValue }
        var label: String {
            switch self {
            case .cars: return "Cars"
            case .parts: return "Parts"
            case .tuning: return "Tuning"
            }
        }
    }

    private var fitted: CarSpec {
        CarCatalog.spec(CarID(settings.selectedCar)) ?? CarCatalog.starting
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Picker("Counter", selection: $counter) {
                    ForEach(Counter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 10) {
                        switch counter {
                        case .cars: carCounter
                        case .parts: partCounter
                        case .tuning: tuningCounter
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            BackChip { dismiss() }
            Text("SHOP")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .kerning(4)
                .foregroundStyle(Theme.ink)
            Spacer()
            Wallet(credits: bank.credits)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var carCounter: some View {
        ForEach(CarCatalog.all.sorted { Shop.price(for: $0) < Shop.price(for: $1) }) { spec in
            let price = Shop.price(for: spec)
            let owned = bank.owns(car: spec.id)
            StockRow(
                title: spec.name,
                detail: CarCopy.note(for: spec),
                price: price,
                owned: owned,
                affordable: bank.canAfford(price),
                artwork: "car_\(spec.id.rawValue)"
            ) {
                if owned {
                    settings.selectedCar = spec.id.rawValue
                    Feedback.shared.play(.place)
                } else if bank.buy(car: spec) {
                    settings.selectedCar = spec.id.rawValue
                    Feedback.shared.play(.win)
                } else {
                    Feedback.shared.play(.reject)
                }
            }
            .overlay(alignment: .topTrailing) {
                if spec.id.rawValue == settings.selectedCar {
                    Text("FITTED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .kerning(1.5)
                        .foregroundStyle(Theme.void)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.cold, in: Capsule())
                        .padding(8)
                }
            }
        }
    }

    private var partCounter: some View {
        ForEach(PartGroup.allCases, id: \.self) { group in
            let parts = PartCatalog.all.filter { $0.group == group }
            if !parts.isEmpty {
                GroupHeader(title: group.rawValue, count: parts.count)
                ForEach(parts) { part in
                    let price = Shop.price(for: part)
                    let owned = bank.owns(part: part.id)
                    StockRow(
                        title: part.name,
                        detail: PartCopy.describe(part),
                        price: price,
                        owned: owned,
                        affordable: bank.canAfford(price),
                        glyph: PartGlyph.symbol(for: part.id)
                    ) {
                        if owned {
                            Feedback.shared.play(.discard)
                        } else if bank.buy(part: part) {
                            Feedback.shared.play(.win)
                        } else {
                            Feedback.shared.play(.reject)
                        }
                    }
                }
            }
        }
    }

    private var tuningCounter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image("car_\(fitted.id.rawValue)")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 78)
                VStack(alignment: .leading, spacing: 3) {
                    Text("TUNING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .kerning(3)
                        .foregroundStyle(Theme.dim)
                    Text(fitted.name)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text("upgrades stay with this car")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                Spacer()
            }
            .padding(16)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1)
            }

            ForEach(TuningTrack.allCases, id: \.self) { track in
                let level = bank.tuning(for: fitted.id).level(track)
                let maxed = level >= Tuning.maxLevel
                let price = Tuning.cost(level + 1)
                TuningRow(
                    track: track,
                    level: level,
                    price: maxed ? nil : price,
                    affordable: bank.canAfford(price)
                ) {
                    if bank.upgrade(car: fitted.id, track: track) {
                        Feedback.shared.play(.win)
                    } else {
                        Feedback.shared.play(.reject)
                    }
                }
            }
        }
    }
}

struct Wallet: View {
    let credits: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.gold)
            Text("\(credits)")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.panelStrong, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1) }
    }
}

private struct StockRow: View {
    let title: String
    let detail: String
    let price: Int
    let owned: Bool
    let affordable: Bool
    var artwork: String?
    var glyph: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let glyph {
                    Image(systemName: glyph)
                        .font(.system(size: 16))
                        .frame(width: 26)
                        .foregroundStyle(owned ? Theme.gold : Theme.dim)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Tag(owned: owned, price: price, affordable: affordable)
                }
                Spacer(minLength: 4)
                if let artwork {
                    Image(artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 92, height: 66)
                        .saturation(owned ? 1 : 0.3)
                        .opacity(owned ? 1 : 0.6)
                }
            }
            .padding(12)
            .background(owned ? Theme.panelStrong : Theme.panel,
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(owned ? Theme.cold.opacity(0.4) : Theme.hairline, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct Tag: View {
    let owned: Bool
    let price: Int
    let affordable: Bool

    var body: some View {
        Group {
            if owned {
                Text(price == 0 ? "INCLUDED" : "OWNED")
                    .foregroundStyle(Theme.cold)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "circle.hexagongrid.fill").font(.system(size: 8))
                    Text("\(price)")
                }
                .foregroundStyle(affordable ? Theme.gold : Theme.dim)
            }
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .kerning(1.2)
    }
}

private struct TuningRow: View {
    let track: TuningTrack
    let level: Int
    let price: Int?
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .kerning(2)
                        .foregroundStyle(Theme.ink)
                    Text(track.detail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                    HStack(spacing: 4) {
                        ForEach(0..<Tuning.maxLevel, id: \.self) { step in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(step < level ? Theme.gold : Theme.hairline)
                                .frame(width: 26, height: 4)
                        }
                    }
                }
                Spacer()
                if let price {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.hexagongrid.fill").font(.system(size: 9))
                        Text("\(price)")
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(affordable ? Theme.gold : Theme.dim)
                } else {
                    Text("MAX")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .kerning(1.5)
                        .foregroundStyle(Theme.cold)
                }
            }
            .padding(14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(price == nil)
    }
}
