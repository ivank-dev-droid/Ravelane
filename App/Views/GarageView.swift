import SwiftUI
import RavelaneCore

struct GarageView: View {
    @State private var settings = GameSettings.shared
    @Environment(\.dismiss) private var dismiss

    private var fitted: Set<String> { Set(settings.selectedParts) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    BackChip { dismiss() }
                    Text("GARAGE")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .kerning(4)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(fitted.count)/\(PartCatalog.slotLimit) parts")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 10) {
                        GroupHeader(title: "Car", count: CarCatalog.all.count)
                        ForEach(CarCatalog.all) { car in
                            CarRow(car: car, selected: car.id.rawValue == settings.selectedCar) {
                                settings.selectedCar = car.id.rawValue
                                Feedback.shared.play(.place)
                            }
                        }

                        ForEach(PartGroup.allCases, id: \.self) { group in
                            let parts = PartCatalog.all.filter { $0.group == group }
                            if !parts.isEmpty {
                                GroupHeader(title: group.rawValue, count: parts.count)
                                ForEach(parts) { part in
                                    PartRow(
                                        part: part,
                                        fitted: fitted.contains(part.id.rawValue),
                                        canFit: fitted.count < PartCatalog.slotLimit
                                    ) {
                                        toggle(part)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func toggle(_ part: Part) {
        var list = settings.selectedParts
        if let index = list.firstIndex(of: part.id.rawValue) {
            list.remove(at: index)
            Feedback.shared.play(.discard)
        } else if list.count < PartCatalog.slotLimit {
            list.append(part.id.rawValue)
            Feedback.shared.play(.place)
        } else {
            Feedback.shared.play(.reject)
            return
        }
        settings.selectedParts = list
    }
}

private struct CarRow: View {
    let car: CarSpec
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Theme.cold : Theme.dim)
                VStack(alignment: .leading, spacing: 3) {
                    Text(car.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(CarCopy.note(for: car))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image("car_\(car.id.rawValue)")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 62)
                    .saturation(selected ? 1 : 0.55)
                    .opacity(selected ? 1 : 0.72)
            }
            .padding(12)
            .background(selected ? Theme.panelStrong : Theme.panel,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Theme.cold.opacity(0.5) : Theme.hairline, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct PartRow: View {
    let part: Part
    let fitted: Bool
    let canFit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: PartGlyph.symbol(for: part.id))
                    .font(.system(size: 15))
                    .frame(width: 22)
                    .foregroundStyle(fitted ? Theme.gold : Theme.dim)
                VStack(alignment: .leading, spacing: 3) {
                    Text(part.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(fitted || canFit ? Theme.ink : Theme.dim)
                    Text(PartCopy.describe(part))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                Spacer()
            }
            .padding(12)
            .background(fitted ? Theme.panelStrong : Theme.panel,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(fitted ? Theme.gold.opacity(0.45) : Theme.hairline, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
