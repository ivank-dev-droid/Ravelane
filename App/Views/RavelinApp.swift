import SwiftUI
import RavelinCore

@main
struct RavelinApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @State private var ready = false
    @State private var summaries: [LevelSummary] = []
    @State private var showTutorial = !GameSettings.shared.tutorialSeen

    var body: some View {
        Group {
            if ready && showTutorial {
                TutorialView { showTutorial = false }
                    .transition(.opacity)
            } else if ready {
                NavigationStack {
                    MainMenuView(summaries: summaries)
                }
                .tint(Theme.neon)
                .transition(.opacity)
            } else {
                LoadingView(caption: "unspooling the catalog")
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: ready)
        .animation(.easeInOut(duration: 0.35), value: showTutorial)
        .task {
            async let warm: [LevelSummary] = Task.detached(priority: .userInitiated) {
                LevelCatalog.summaries
            }.value
            async let floor: Void = Task.sleep(for: .milliseconds(2500))
            summaries = (try? await warm) ?? []
            _ = try? await floor
            ready = true
        }
    }
}

struct MainMenuView: View {
    let summaries: [LevelSummary]
    @State private var world: WorldID = .foundry

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GlowField()

            VStack(alignment: .leading, spacing: 0) {
                header
                worldStrip
                levelGrid
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RAVELIN")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .kerning(8)
                    .foregroundStyle(Theme.ink)
                    .shadow(color: Theme.neon.opacity(0.6), radius: 16)
                Text("you never steer")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(Theme.dim)
            }
            Spacer()
            HStack(spacing: 8) {
                MenuChip(icon: "book.closed") { CodexView() }
                MenuChip(icon: "chart.bar") { StatsView() }
                MenuChip(icon: "slider.horizontal.3") { SettingsView() }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 20)
    }

    private var worldStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(WorldID.allCases, id: \.self) { id in
                    WorldChip(world: id, selected: id == world)
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.25)) { world = id }
                        }
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 18)
    }

    private var levelGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                ForEach(summaries.filter { $0.world == world }) { summary in
                    NavigationLink {
                        BriefingView(summary: summary)
                    } label: {
                        LevelTile(summary: summary, stars: ProgressStore.shared.stars(for: summary.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
    }
}

private struct WorldChip: View {
    let world: WorldID
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(world.displayName.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(selected ? Theme.void : Theme.ink)
            Text(world.tagline)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(selected ? Theme.void.opacity(0.7) : Theme.dim)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(selected ? AnyShapeStyle(Theme.neon) : AnyShapeStyle(Theme.panel),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1)
        }
    }
}

struct MenuChip<Destination: View>: View {
    let icon: String
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
    }
}

private struct LevelTile: View {
    let summary: LevelSummary
    let stars: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(summary.number)")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Spacer()
                StarRow(count: stars)
            }
            Divider().overlay(Theme.hairline)
            HStack(spacing: 8) {
                Label("\(summary.parPieces)", systemImage: "square.stack.3d.up")
                Label("\(summary.coreCount)", systemImage: "circle.hexagongrid.fill")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.dim)
        }
        .padding(12)
        .frame(height: 92)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

private struct GlowField: View {
    var body: some View {
        Canvas { context, size in
            let spots: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (0.18, 0.12, 0.55, Theme.neon),
                (0.86, 0.30, 0.42, Theme.blue),
                (0.44, 0.82, 0.50, Theme.neon)
            ]
            for (x, y, scale, colour) in spots {
                let radius = size.width * scale
                let rect = CGRect(x: size.width * x - radius, y: size.height * y - radius,
                                  width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [colour.opacity(0.16), .clear]),
                        center: CGPoint(x: size.width * x, y: size.height * y),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension WorldID {
    var tagline: String {
        switch self {
        case .foundry: return "standard gravity"
        case .updraft: return "long, lazy air"
        case .magnetite: return "walls and ceilings"
        case .haze: return "build into fog"
        case .rundown: return "the track decays"
        case .overdrive: return "bank or die"
        }
    }
}
