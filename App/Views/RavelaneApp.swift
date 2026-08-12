import SwiftUI
import RavelaneCore

@main
struct RavelaneApp: App {
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
            KeyArtBackdrop()
            GlowField()

            VStack(alignment: .leading, spacing: 0) {
                header
                worldStrip
                WorldBanner(world: world)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                levelGrid
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RAVELANE")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .kerning(4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Theme.ink)
                    .shadow(color: Theme.neon.opacity(0.6), radius: 16)
                Text("you never steer")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(Theme.dim)
                NavigationLink { ShopView() } label: {
                    Wallet(credits: BankStore.shared.credits)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer()
            HStack(spacing: 6) {
                MenuChip(icon: "cart") { ShopView() }
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
                    Button {
                        Feedback.shared.play(.place)
                        withAnimation(.snappy(duration: 0.25)) { world = id }
                    } label: {
                        WorldChip(world: id, selected: id == world)
                    }
                    .buttonStyle(.plain)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 46)
        .background(selected ? AnyShapeStyle(Theme.neon) : AnyShapeStyle(Theme.panel),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
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
                .frame(width: 38, height: 38)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct LevelTile: View {
    let summary: LevelSummary
    let stars: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(summary.number)")
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.ink)
            StarRow(count: stars)
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
        .background(alignment: .trailing) {
            RouteSilhouette(levelID: summary.id, lineWidth: 1.6, showsMarkers: false)
                .frame(width: 84, height: 84)
                .opacity(0.5)
                .offset(x: 12)
                .allowsHitTesting(false)
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct WorldBanner: View {
    let world: WorldID

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("world_\(world.rawValue)")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 108)
                .clipped()

            LinearGradient(
                colors: [Color.clear, Theme.void.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(world.displayName.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(Theme.ink)
                Text(world.tagline)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
            .padding(12)
        }
        .frame(height: 108)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

struct KeyArtBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Image("MenuKeyArt")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            Theme.void.opacity(0.62),
                            Theme.void.opacity(0.86),
                            Theme.void
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
