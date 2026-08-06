import SwiftUI
import RavelinCore

struct DeckBuilderView: View {
    let world: WorldID
    let palette: [PieceID]
    var onDone: (Deck) -> Void

    @State private var counts: [PieceID: Int] = [:]
    @Environment(\.dismiss) private var dismiss

    private var chosen: [PieceID] { palette.filter { (counts[$0] ?? 0) > 0 } }
    private var totalPieces: Int { counts.values.reduce(0, +) }
    private var slotsUsed: Int { chosen.count }
    private var isValid: Bool { slotsUsed >= 4 && slotsUsed <= Deck.slotLimit }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                presets
                summary
                list
                confirmBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
    }

    private func load() {
        let current = DeckStore.shared.deck(for: world, palette: palette)
        var table: [PieceID: Int] = [:]
        for entry in current.entries where palette.contains(entry.piece) {
            table[entry.piece] = entry.count
        }
        counts = table
    }

    private func apply(_ archetype: Archetype) {
        let deck = archetype.deck(from: palette)
        var table: [PieceID: Int] = [:]
        for entry in deck.entries { table[entry.piece] = entry.count }
        counts = table
        Feedback.shared.play(.place)
    }

    private var header: some View {
        HStack {
            BackChip { dismiss() }
            Text("DECK")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .kerning(4)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(world.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .kerning(2)
                .foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Archetype.allCases, id: \.self) { archetype in
                    Button { apply(archetype) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(archetype.displayName.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .kerning(1.5)
                                .foregroundStyle(Theme.ink)
                            Text(archetype.summary)
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.dim)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(width: 150, alignment: .leading)
                        }
                        .padding(12)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 14)
    }

    private var summary: some View {
        HStack(spacing: 16) {
            Meter(label: "SLOTS", value: "\(slotsUsed)/\(Deck.slotLimit)",
                  tint: isValid ? Theme.cold : Theme.alarm)
            Meter(label: "PIECES", value: "\(totalPieces)", tint: Theme.gold)
            Meter(label: "TURNS", value: "\(turnCount)",
                  tint: turnCount >= 3 ? Theme.cold : Theme.alarm)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var turnCount: Int {
        chosen.compactMap { PieceCatalog.cache.piece($0) }
            .filter { $0.totalYaw.magnitude > .zero }
            .count
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(palette, id: \.self) { id in
                    if let piece = PieceCatalog.cache.piece(id) {
                        DeckRow(
                            piece: piece,
                            count: counts[id] ?? 0,
                            canAdd: (counts[id] ?? 0) < Deck.countLimit
                                && ((counts[id] ?? 0) > 0 || slotsUsed < Deck.slotLimit),
                            onAdd: {
                                counts[id, default: 0] += 1
                                Feedback.shared.play(.place)
                            },
                            onRemove: {
                                let value = (counts[id] ?? 0) - 1
                                if value <= 0 { counts[id] = nil } else { counts[id] = value }
                                Feedback.shared.play(.discard)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var confirmBar: some View {
        VStack(spacing: 8) {
            if !isValid {
                Text(slotsUsed < 4 ? "Pick at least four kinds of piece"
                                   : "Too many kinds — twelve at most")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.alarm)
            } else if turnCount < 3 {
                Text("A deck with almost no turns cannot navigate")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.gold)
            }

            Button {
                let deck = Deck(entries: chosen.map { DeckEntry(piece: $0, count: counts[$0] ?? 1) })
                DeckStore.shared.save(deck, for: world)
                onDone(deck)
                dismiss()
            } label: {
                Text("USE THIS DECK")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .kerning(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(isValid ? Theme.neon : Theme.panel,
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(isValid ? Theme.void : Theme.dim)
            }
            .disabled(!isValid)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }
}

private struct DeckRow: View {
    let piece: Piece
    let count: Int
    let canAdd: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(piece.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(count > 0 ? Theme.ink : Theme.dim)
                Text(PieceCopy.line(for: piece))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Theme.panelStrong, in: Circle())
                }
                .disabled(count == 0)
                .foregroundStyle(count == 0 ? Theme.dim : Theme.ink)

                Text("\(count)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(count > 0 ? Theme.cold : Theme.dim)
                    .frame(width: 20)

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Theme.panelStrong, in: Circle())
                }
                .disabled(!canAdd)
                .foregroundStyle(canAdd ? Theme.ink : Theme.dim)
            }
        }
        .padding(12)
        .background(count > 0 ? Theme.panelStrong : Theme.panel,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(count > 0 ? Theme.neon.opacity(0.4) : Theme.hairline, lineWidth: 1)
        }
    }
}

struct Meter: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(Theme.dim)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
    }
}

struct BackChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .background(Theme.panel, in: Circle())
        }
    }
}

enum PieceCopy {
    static func line(for piece: Piece) -> String {
        var bits: [String] = ["\(piece.length.whole)m", "\(piece.cost)◈"]
        let yaw = degreesValue(piece.totalYaw)
        let pitch = degreesValue(piece.totalPitch)
        let roll = degreesValue(piece.totalRoll)
        if yaw != 0 { bits.append("\(yaw > 0 ? "right" : "left") \(abs(yaw))°") }
        if pitch != 0 { bits.append("\(pitch > 0 ? "up" : "down") \(abs(pitch))°") }
        if roll != 0 { bits.append("bank \(abs(roll))°") }
        if piece.isGap { bits.append("gap \(piece.gapLength.whole)m") }
        switch piece.surface {
        case .boost: bits.append("faster")
        case .brake: bits.append("slower")
        case .rumble: bits.append("rough")
        case .magnet: bits.append("magnetic")
        case .scaffold: bits.append("collapses")
        case .normal: break
        }
        return bits.joined(separator: " · ")
    }

    static func degreesValue(_ radians: Fixed) -> Int {
        Int((radians.approximateDouble * 180 / Double.pi).rounded())
    }

    static func role(for piece: Piece) -> String {
        if piece.tags.contains(.runwayBuy) { return "Buys thinking time" }
        if piece.tags.contains(.navigation) { return "Changes where you are going" }
        if piece.tags.contains(.speedGain) { return "Adds speed" }
        if piece.tags.contains(.speedLoss) { return "Sheds speed" }
        if piece.tags.contains(.forgiving) { return "Wide and forgiving" }
        if piece.tags.contains(.branching) { return "Leaves a second socket" }
        return "Utility"
    }
}
