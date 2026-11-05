import SwiftUI

/// A calm, cinematic selection carousel shown after the app has been idle.
/// It deliberately never launches a game; any input returns to the normal UI.
struct IdleCarouselView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette

    @State private var index = 0
    @State private var timer: Timer?

    private var games: [Game] { model.sortedGames }

    private var game: Game? {
        guard !games.isEmpty else { return nil }
        return games[ min(max(index, 0), games.count - 1) ]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                if let game {
                    GameArtwork(game: game)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .id(game.id)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 1.4), value: game.id)

                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.08), location: 0),
                            .init(color: .black.opacity(0.02), location: 0.42),
                            .init(color: .black.opacity(0.72), location: 0.78),
                            .init(color: .black.opacity(0.94), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    LinearGradient(
                        colors: [.black.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .center
                    )

                    content(for: game, size: proxy.size)
                }

                VStack {
                    HStack {
                        HStack(spacing: 9) {
                            LumenMark(size: 22, showsWordmark: false)
                            Text("LUMEN")
                                .font(LumenFont.display(15, weight: .medium))
                                .tracking(5)
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer()
                        Text("浏览模式")
                            .font(LumenFont.mono(9, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(.black.opacity(0.26))
                            }
                            .overlay {
                                Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 38)

                    Spacer()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture { model.endIdleCarousel() }
        }
        .ignoresSafeArea()
        .onAppear {
            if let selected = games.firstIndex(where: { $0.id == model.selectedGameID }) {
                index = selected
            }
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func content(for game: Game, size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack(alignment: .bottom, spacing: 26) {
                PosterArtwork(game: game)
                    .frame(width: 168, height: 252)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 18)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 9) {
                        Capsule()
                            .fill(palette.accent)
                            .frame(width: 26, height: 2)
                        Text(game.isShowcase ? "LUMEN SHOWCASE" : "你的游戏库")
                            .font(LumenFont.mono(9, weight: .medium))
                            .tracking(2.5)
                            .foregroundStyle(palette.accent.opacity(0.86))
                    }

                    Text(game.title)
                        .font(LumenFont.display(56, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    if !game.tagline.isEmpty {
                        Text(game.tagline)
                            .font(LumenFont.text(15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        if !game.metadataLine.isEmpty {
                            Text(game.metadataLine)
                                .font(LumenFont.label(9))
                                .foregroundStyle(.white.opacity(0.44))
                        }
                        if game.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(palette.accent.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
            }
            .padding(.horizontal, 66)

            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 7) {
                    ForEach(games.indices, id: \.self) { offset in
                        Capsule()
                            .fill(offset == index ? palette.accent : .white.opacity(0.2))
                            .frame(width: offset == index ? 22 : 5, height: 4)
                            .animation(.easeInOut(duration: 0.4), value: index)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 9))
                    Text("按任意键返回")
                        .font(LumenFont.label(8.5))
                        .tracking(0.6)
                }
                .foregroundStyle(.white.opacity(0.34))
            }
            .padding(.horizontal, 66)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        guard games.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { timer in
            Task { @MainActor in
                guard model.isIdleCarouselPresented else {
                    timer.invalidate()
                    return
                }
                guard !games.isEmpty else { return }
                let next = (index + 1) % games.count
                withAnimation(.easeInOut(duration: 1.15)) {
                    index = next
                }
                model.selectedGameID = games[next].id
            }
        }
    }
}
