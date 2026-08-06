import SwiftUI

struct LoadingView: View {
    let caption: String

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Text("RAVELIN")
                    .font(.system(size: 40, weight: .heavy, design: .monospaced))
                    .kerning(10)
                    .foregroundStyle(Theme.ink)
                    .shadow(color: Theme.neon.opacity(0.7), radius: 22)

                Text("YOU NEVER STEER")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .kerning(4)
                    .foregroundStyle(Theme.dim)

                Spacer()

                UnspoolingRibbon()
                    .frame(height: 96)
                    .padding(.horizontal, 30)

                Text(caption.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(Theme.dim)

                Spacer()
            }
        }
    }
}

struct UnspoolingRibbon: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                draw(context: &context, size: size, time: now)
            }
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let midY = size.height / 2
        let amplitude = size.height * 0.30
        let wavelength = size.width / 1.5
        let travel = CGFloat(time.truncatingRemainder(dividingBy: 4) / 4)
        let edgeGap = size.height * 0.14

        func height(at x: CGFloat) -> CGFloat {
            let t = (x / wavelength) + travel * 2
            return midY + sin(t * .pi * 2) * amplitude
        }

        func rail(lift: CGFloat) -> Path {
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                let y = height(at: x) + lift
                if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                x += 3
            }
            return path
        }

        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Theme.neon.opacity(0.05), Theme.neon, Theme.blue, Theme.blue.opacity(0.05)]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: 0)
        )

        var deck = Path()
        deck.addPath(rail(lift: -edgeGap))
        var back = Path()
        var x = size.width
        while x >= 0 {
            let y = height(at: x) + edgeGap
            if x == size.width { back.move(to: CGPoint(x: x, y: y)) } else { back.addLine(to: CGPoint(x: x, y: y)) }
            x -= 3
        }
        deck.addPath(back)
        deck.closeSubpath()
        context.fill(deck, with: .color(Theme.neon.opacity(0.10)))

        var rungs = Path()
        var step = -(travel * 34)
        while step <= size.width {
            if step >= 0 {
                let base = height(at: step)
                rungs.move(to: CGPoint(x: step, y: base - edgeGap))
                rungs.addLine(to: CGPoint(x: step, y: base + edgeGap))
            }
            step += 17
        }
        context.stroke(rungs, with: .color(Theme.neon.opacity(0.30)), lineWidth: 1)

        context.stroke(rail(lift: -edgeGap), with: shading, lineWidth: 2.5)
        context.stroke(rail(lift: edgeGap), with: shading, lineWidth: 2.5)

        let cycle = time.truncatingRemainder(dividingBy: 2.4) / 2.4
        let headX = size.width * CGFloat(cycle)
        let headY = height(at: headX)

        for trail in 1...6 {
            let back = headX - CGFloat(trail) * 9
            guard back > 0 else { continue }
            let dot = Path(ellipseIn: CGRect(x: back - 3, y: height(at: back) - 3, width: 6, height: 6))
            context.fill(dot, with: .color(Theme.cold.opacity(0.5 - Double(trail) * 0.07)))
        }

        let head = Path(ellipseIn: CGRect(x: headX - 6, y: headY - 6, width: 12, height: 12))
        context.fill(head, with: .color(Theme.cold))
        let halo = Path(ellipseIn: CGRect(x: headX - 12, y: headY - 12, width: 24, height: 24))
        context.stroke(halo, with: .color(Theme.cold.opacity(0.35)), lineWidth: 1.5)
    }
}

enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.043, green: 0.016, blue: 0.094),
                 Color(red: 0.086, green: 0.035, blue: 0.180)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let void = Color(red: 0.043, green: 0.016, blue: 0.094)
    static let panel = Color.white.opacity(0.06)
    static let panelStrong = Color.white.opacity(0.11)
    static let hairline = Color.white.opacity(0.12)
    static let ink = Color(red: 0.929, green: 0.894, blue: 0.980)
    static let dim = Color(red: 0.612, green: 0.561, blue: 0.722)
    static let neon = Color(red: 0.706, green: 0.294, blue: 1.0)
    static let blue = Color(red: 0.180, green: 0.482, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.761, blue: 0.294)
    static let alarm = Color(red: 1.0, green: 0.239, blue: 0.431)
    static let cold = Color(red: 0.294, green: 0.890, blue: 1.0)
}
