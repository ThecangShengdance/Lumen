import SwiftUI

struct BootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette

    @State private var reveal = false
    @State private var spin: Double = 0
    @State private var progress: CGFloat = 0.035

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                RadialGradient(
                    colors: [
                        palette.accent.opacity(0.16),
                        palette.accent.opacity(0.04),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.48),
                    startRadius: 4,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.62
                )

                BootStarField()
                    .opacity(reveal ? 1 : 0)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    Spacer()

                    logo
                        .scaleEffect(reveal ? 1 : 0.9)
                        .opacity(reveal ? 1 : 0)

                    Text("LUMEN")
                        .font(LumenFont.display(32, weight: .light))
                        .tracking(19)
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.top, 30)
                        .padding(.leading, 19)
                        .opacity(reveal ? 1 : 0)
                        .offset(y: reveal ? 0 : 10)

                    Text("YOUR COLLECTION, REIMAGINED")
                        .font(LumenFont.mono(9, weight: .medium))
                        .tracking(4.2)
                        .foregroundStyle(.white.opacity(0.34))
                        .padding(.top, 13)
                        .opacity(reveal ? 1 : 0)

                    Spacer()

                    VStack(spacing: 14) {
                        GeometryReader { bar in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.09))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [palette.accent.opacity(0.65), palette.accent, .white],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, bar.size.width * progress))
                                    .shadow(color: palette.accent.opacity(0.7), radius: 6)
                            }
                        }
                        .frame(width: 232, height: 2)

                        Text("正在整理你的收藏")
                            .font(LumenFont.label(10))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.bottom, 56)
                }
                .padding(.vertical, 48)

                VStack {
                    HStack {
                        Text("LUMEN  /  MAC GAME LAUNCHER")
                            .font(LumenFont.mono(8.5, weight: .medium))
                            .tracking(2.2)
                        Spacer()
                        Text("VERSION 1.0")
                            .font(LumenFont.mono(8.5, weight: .medium))
                            .tracking(2.2)
                    }
                    .foregroundStyle(.white.opacity(0.22))
                    .padding(.horizontal, 40)
                    .padding(.top, 30)

                    Spacer()

                    Text("点击任意处跳过")
                        .font(LumenFont.label(9))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(.bottom, 24)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture { finish() }
        }
        .ignoresSafeArea()
        .task { await runIntro() }
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.13))
                .frame(width: 200, height: 200)
                .blur(radius: 44)

            Circle()
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                .frame(width: 148, height: 148)

            Circle()
                .trim(from: 0.04, to: 0.22)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.9), palette.accent.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: 168, height: 168)
                .rotationEffect(.degrees(spin))

            Circle()
                .trim(from: 0.58, to: 0.7)
                .stroke(Color(hex: 0xE8D2A2).opacity(0.8), lineWidth: 1)
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(-spin * 0.55))

            LumenMark(size: 82, showsWordmark: false)
                .shadow(color: palette.accent.opacity(0.45), radius: 18)
        }
        .frame(width: 210, height: 210)
        .task {
            withAnimation(.linear(duration: 11).repeatForever(autoreverses: false)) {
                spin = 360
            }
        }
    }

    private func runIntro() async {
        try? await Task.sleep(nanoseconds: 150_000_000)
        withAnimation(.easeOut(duration: 1.1)) {
            reveal = true
            progress = 0.34
        }

        try? await Task.sleep(nanoseconds: 620_000_000)
        withAnimation(.easeInOut(duration: 0.8)) { progress = 0.78 }

        try? await Task.sleep(nanoseconds: 620_000_000)
        withAnimation(.easeOut(duration: 0.4)) { progress = 1 }

        try? await Task.sleep(nanoseconds: 560_000_000)
        finish()
    }

    private func finish() {
        guard model.isBooting else { return }
        model.finishBoot()
    }
}

private struct BootStarField: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<130 {
                let seed = Double(index) * 12.9898
                let x = abs(sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1) * size.width
                let y = abs(sin(seed + 4.191) * 24634.6345).truncatingRemainder(dividingBy: 1) * size.height
                let radius = 0.5 + abs(sin(seed + 9.7)) * 1.1
                let alpha = 0.08 + abs(cos(seed + 2.3)) * 0.32
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}
