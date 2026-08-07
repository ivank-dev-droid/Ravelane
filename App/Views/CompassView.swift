import SwiftUI
import RavelaneCore

struct CompassView: View {
    let bearing: SessionViewModel.Bearing

    private var tint: Color { bearing.isGoal ? Theme.gold : Theme.blue }

    private var turnHint: String {
        let degrees = bearing.yaw * 180 / .pi
        if abs(degrees) < 12 { return "STRAIGHT ON" }
        if degrees > 0 { return "BEAR RIGHT \(Int(abs(degrees)))" }
        return "BEAR LEFT \(Int(abs(degrees)))"
    }

    private var climbHint: String? {
        if bearing.climb > 12 { return "ABOVE YOU" }
        if bearing.climb < -12 { return "BELOW YOU" }
        return nil
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
                Circle()
                    .fill(Color.black.opacity(0.4))
                Image(systemName: "location.north.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .rotationEffect(.radians(bearing.yaw))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(bearing.isGoal ? "GOAL" : "CHECKPOINT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(tint)
                Text("\(Int(bearing.distance)) m")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text(climbHint ?? turnHint)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        }
    }
}

struct GhostVerdict: View {
    let piece: Piece
    let endsCloser: Bool?
    let allowed: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .kerning(1)
        }
        .foregroundStyle(colour)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.4), in: Capsule())
        .overlay { Capsule().strokeBorder(colour.opacity(0.35), lineWidth: 1) }
    }

    private var symbol: String {
        if !allowed { return "xmark.circle.fill" }
        guard let endsCloser else { return "questionmark.circle" }
        return endsCloser ? "arrow.down.right.circle.fill" : "arrow.up.left.circle"
    }

    private var label: String {
        if !allowed { return "WILL NOT FIT" }
        guard let endsCloser else { return piece.name.uppercased() }
        return endsCloser ? "CLOSER" : "FURTHER AWAY"
    }

    private var colour: Color {
        if !allowed { return Theme.alarm }
        guard let endsCloser else { return Theme.dim }
        return endsCloser ? Theme.cold : Theme.gold
    }
}
