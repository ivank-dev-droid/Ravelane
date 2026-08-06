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
    var body: some View {
        NavigationStack {
            LevelSelectView()
        }
        .tint(.purple)
    }
}

struct LevelSelectView: View {
    @State private var world: WorldID = .foundry

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.043, green: 0.016, blue: 0.094),
                         Color(red: 0.102, green: 0.043, blue: 0.200)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("RAVELIN")
                    .font(.system(size: 34, weight: .heavy, design: .monospaced))
                    .kerning(6)
                    .foregroundStyle(.white)

                Text("You never steer. You build the track ahead of the car.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Picker("World", selection: $world) {
                    ForEach(WorldID.allCases, id: \.self) { id in
                        Text(id.displayName).tag(id)
                    }
                }
                .pickerStyle(.menu)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(LevelCatalog.levels(in: world)) { level in
                            NavigationLink {
                                GameView(level: level)
                                    .navigationBarBackButtonHidden()
                            } label: {
                                LevelTile(level: level)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LevelTile: View {
    let level: Level

    var body: some View {
        VStack(spacing: 6) {
            Text(level.name.components(separatedBy: " ").last ?? "")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text("par \(level.parPieces)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text("\(level.cores.count) cores")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.yellow.opacity(0.7))
        }
        .frame(height: 84)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

