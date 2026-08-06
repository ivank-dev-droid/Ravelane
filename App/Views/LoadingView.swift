import SwiftUI

struct LoadingView: View {
    let caption: String
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 34) {
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

                UnspoolingRibbon(phase: phase)
                    .frame(height: 92)
                    .padding(.horizontal, 34)

                Text(caption.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(Theme.dim)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

private struct UnspoolingRibbon: View {
    var phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let amplitude = size.height * 0.32
            let wavelength = size.width / 1.6

            func ribbon(offset: CGFloat, lift: CGFloat) -> Path {
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    let t = (x / wavelength) + offset
                    let y = midY + sin(t * .pi * 2) * amplitude + lift
                    if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                    x += 3
                }
                return path
            }

            let travel = phase
            let edgeGap = size.height * 0.13

            context.stroke(
                ribbon(offset: travel, lift: -edgeGap),
                with: .linearGradient(
                    Gradient(colors: [Theme.blue.opacity(0.15), Theme.neon, Theme.blue.opacity(0.15)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                lineWidth: 2.5
            )
            context.stroke(
                ribbon(offset: travel, lift: edgeGap),
                with: .linearGradient(
                    Gradient(colors: [Theme.blue.opacity(0.15), Theme.neon, Theme.blue.opacity(0.15)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                lineWidth: 2.5
            )

            var rungs = Path()
            var step: CGFloat = 0
            while step <= size.width {
                let t = (step / wavelength) + travel
                let base = midY + sin(t * .pi * 2) * amplitude
                rungs.move(to: CGPoint(x: step, y: base - edgeGap))
                rungs.addLine(to: CGPoint(x: step, y: base + edgeGap))
                step += 16
            }
            context.stroke(rungs, with: .color(Theme.neon.opacity(0.28)), lineWidth: 1)

            let headX = size.width * (0.12 + 0.76 * abs(sin(travel * .pi)))
            let headT = (headX / wavelength) + travel
            let headY = midY + sin(headT * .pi * 2) * amplitude
            let head = Path(ellipseIn: CGRect(x: headX - 5, y: headY - 5, width: 10, height: 10))
            context.fill(head, with: .color(Theme.cold))
            context.stroke(head, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        }
        .drawingGroup()
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
    static let hairline = Color.white.opacity(0.12)
    static let ink = Color(red: 0.929, green: 0.894, blue: 0.980)
    static let dim = Color(red: 0.612, green: 0.561, blue: 0.722)
    static let neon = Color(red: 0.706, green: 0.294, blue: 1.0)
    static let blue = Color(red: 0.180, green: 0.482, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.761, blue: 0.294)
    static let alarm = Color(red: 1.0, green: 0.239, blue: 0.431)
    static let cold = Color(red: 0.294, green: 0.890, blue: 1.0)
}
