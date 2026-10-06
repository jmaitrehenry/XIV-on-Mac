//
//  DesignSystem.swift
//  XIV on Mac
//

import SwiftUI

enum XOMStyle {
    static let accent = Color(red: 0.94, green: 0.25, blue: 0.34)
    static let cyan = Color(red: 0.30, green: 0.76, blue: 0.86)
}

struct AppWindowBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private
        var reduceTransparency

    private var style: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
            : AnyShapeStyle(.ultraThinMaterial)
    }

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .containerBackground(style, for: .window)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            content.background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct GlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private
        var reduceTransparency
    let radius: CGFloat
    let interactive: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: radius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius).strokeBorder(
                    .primary.opacity(0.15)))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(
                .regular.interactive(interactive),
                in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(
                .regularMaterial, in: RoundedRectangle(cornerRadius: radius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius).strokeBorder(
                    .white.opacity(0.18))
            )
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
        }
    }
}

extension View {
    func xomGlass(radius: CGFloat = 22, interactive: Bool = false) -> some View
    {
        modifier(GlassSurface(radius: radius, interactive: interactive))
    }

    @ViewBuilder func xomPrimaryButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent).tint(XOMStyle.accent)
        } else {
            buttonStyle(.borderedProminent).tint(XOMStyle.accent)
        }
    }
}

struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 20) { content }
        } else {
            content
        }
    }
}

struct ToolHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    let symbol: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(XOMStyle.accent)
                .frame(width: 56, height: 56)
                .xomGlass(radius: 18)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(
                    .system(size: 27, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle).foregroundStyle(.secondary).fixedSize(
                        horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol).font(.headline)
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .background.opacity(0.55), in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18).strokeBorder(
                .primary.opacity(0.07)))
    }
}

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ title: String, _ message: String) {
        self.title = NSLocalizedString(title, comment: "")
        self.message = NSLocalizedString(message, comment: "")
    }
}

extension View {
    func notice(_ notice: Binding<AppNotice?>) -> some View {
        alert(
            notice.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { notice.wrappedValue != nil },
                set: { if !$0 { notice.wrappedValue = nil } }
            ), presenting: notice.wrappedValue
        ) { _ in
            Button("BUTTON_OK", role: .cancel) { notice.wrappedValue = nil }
        } message: { item in
            Text(item.message)
        }
    }
}

func backgroundWork<T>(_ work: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(with: Result(catching: work))
        }
    }
}

#if DEBUG
    @MainActor
    enum PreviewContent {
        static var character: CharacterDataSlot {
            CharacterDataSlot(
                id: 1,
                dataURL: Bundle.main.url(
                    forResource: "DISCORD_TEAM_USAGI_01", withExtension: "dat"))
        }

        static var news: [Frontier.Info.News] {
            [
                "Scheduled maintenance", "Latest update details",
                "Community news",
            ]
            .enumerated().map { index, title in
                Frontier.Info.News(
                    date: "2026-09-29T12:00:00Z", title: title,
                    url: "https://eu.finalfantasyxiv.com/lodestone/",
                    id: "preview-\(index)", tag: nil)
            }
        }

        static var topics: [Frontier.Info.News] {
            ["A new chapter in Eorzea", "Seasonal event", "From the community"]
                .enumerated().map { index, title in
                    Frontier.Info.News(
                        date: "2026-09-28T12:00:00Z", title: title,
                        url: "https://eu.finalfantasyxiv.com/lodestone/",
                        id: "preview-topic-\(index)", tag: nil)
                }
        }

        static var banners: [Frontier.LoadedBanner] {
            ["FINAL FANTASY XIV", "Explore Eorzea", "Seasonal events"]
                .enumerated().map { index, title in
                    let renderer = ImageRenderer(
                        content: LinearGradient(
                            colors: [index == 1 ? .teal : .indigo, .black],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .overlay {
                            VStack(spacing: 16) {
                                Image(systemName: "sparkles").font(.largeTitle)
                                Text(title).font(
                                    .system(size: 32, weight: .bold))
                            }.foregroundStyle(.white)
                        }
                        .frame(width: 640, height: 250))
                    renderer.scale = 2
                    return Frontier.LoadedBanner(
                        id: "preview-banner-\(index)",
                        destination: URL(
                            string: "https://eu.finalfantasyxiv.com/lodestone/")!,
                        image: renderer.nsImage
                            ?? NSImage(size: NSSize(width: 640, height: 250)))
                }
        }

        static func launcher(startingGame: Bool = false) -> LauncherModel {
            let model = LauncherModel()
            model.username = "WarriorOfLight"
            model.password = "preview"
            model.automaticOTP = false
            model.phase = startingGame ? .login : .ready
            model.status =
                startingGame
                ? String(localized: "Starting Game")
                : String(localized: "Ready to play")
            model.news = news
            model.topics = topics
            model.banners = banners
            model.loadingNews = false
            model.loadingBanners = false
            return model
        }
    }
#endif
