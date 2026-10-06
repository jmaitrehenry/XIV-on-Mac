//
//  LauncherView.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 29.09.26.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

struct LauncherView: View {
    @ObservedObject var model: LauncherModel
    @Environment(\.openWindow) private var openWindow
    @State private var confirmAutoLogin = false
    @FocusState private var focusedField: Field?
    private enum Field { case username, password }

    var body: some View {
        VStack(spacing: 16) {
            GlassGroup {
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 16) {
                        BannerCarousel(
                            banners: model.banners,
                            isLoading: model.loadingBanners)
                        HStack(spacing: 16) {
                            newsPanel(title: "News", items: model.news)
                            newsPanel(title: "Topics", items: model.topics)
                        }
                    }
                    .frame(width: 640)
                    accountPanel.frame(width: 304)
                }
            }
            footer
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 12)
        .frame(width: 1016, height: 624)
        .modifier(AppWindowBackground())
        .tint(XOMStyle.accent)
        .notice($model.notice)
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .installer: InstallerView(onComplete: model.finishInstallation)
            case .otp:
                OTPSetupView(username: model.username, save: model.saveOTP)
            case .rosetta: rosettaSheet
            }
        }
        .fileImporter(
            isPresented: $model.selectingGamePath,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url): model.chooseGamePath(url)
            case .failure(let error):
                model.notice = AppNotice(
                    "SELECT_GAME_PATH_ERROR_MESSAGE", error.localizedDescription
                )
            }
        }
        .confirmationDialog(
            "SELECT_GAME_PATH_ERROR_MESSAGE",
            isPresented: Binding(
                get: { model.unvalidatedGamePath != nil },
                set: { if !$0 { model.unvalidatedGamePath = nil } }),
            titleVisibility: .visible
        ) {
            Button("BUTTON_YES") {
                if let url = model.unvalidatedGamePath {
                    Settings.gamePath = url
                }
                model.unvalidatedGamePath = nil
            }
            Button("BUTTON_NO", role: .cancel) {
                model.unvalidatedGamePath = nil
            }
        } message: {
            Text("SELECT_GAME_PATH_ERROR_INFORMATIVE")
        }
        .onChange(of: model.needsFirstAid) { needed in
            if needed {
                openWindow(id: "first-aid")
                model.needsFirstAid = false
            }
        }
        .task(id: model.username) {
            guard !Util.isPreview else { return }
            do { try await Task.sleep(nanoseconds: 400_000_000) } catch {
                return
            }
            model.configureOTP()
        }
        .alert("AUTOLOGIN_MESSAGE", isPresented: $confirmAutoLogin) {
            Button("BUTTON_OK", role: .cancel) {}
        } message: {
            Text("AUTOLOGIN_INFORMATIVE")
        }
        .onAppear {
            focusedField = model.username.isEmpty ? .username : .password
        }
    }

    private func newsPanel(
        title: LocalizedStringKey, items: [Frontier.Info.News]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            if !items.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) {
                            _, item in
                            NewsRow(item: item)
                            Divider().opacity(0.5)
                        }
                    }
                }
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.05),
                            .init(color: .black, location: 0.9),
                            .init(color: .clear, location: 1),
                        ], startPoint: .top, endPoint: .bottom)
                }
            } else if model.loadingNews {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Fetching the latest news…")
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "newspaper").font(.title2)
                        .foregroundStyle(.secondary)
                    Text(
                        model.newsUnavailable
                            ? "News is temporarily unavailable"
                            : "No news to show yet"
                    )
                    .font(.callout).multilineTextAlignment(.center)
                    Link(
                        "Visit the Lodestone",
                        destination: Frontier.lodestoneURL
                    )
                    .font(.caption)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading
        )
        .xomGlass()
    }

    private var accountPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle")
                    .font(.title3).foregroundStyle(XOMStyle.accent)
                Text("Account").font(.headline)
                Spacer()
                if model.phase == .playing {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(.secondary).help("Game running")
                }
            }
            if model.isBusy {
                operation
            } else {
                credentials
            }
            Spacer(minLength: 0)
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "lock.shield").foregroundStyle(.secondary)
                Text("Your password is stored securely in Keychain.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .xomGlass()
    }

    private var credentials: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Square Enix ID").font(.caption).foregroundStyle(
                        .secondary)
                    Spacer()
                    if !model.accounts.isEmpty {
                        Menu {
                            ForEach(model.accounts, id: \.username) { account in
                                Button(account.username) {
                                    model.selectAccount(account)
                                }
                            }
                        } label: {
                            Image(systemName: "person.2")
                        }
                        .menuStyle(.borderlessButton).fixedSize().help(
                            "Saved accounts"
                        )
                        .accessibilityLabel("Saved accounts")
                    }
                }
                TextField("Square Enix ID", text: $model.username)
                    .textContentType(.username).focused(
                        $focusedField, equals: .username
                    )
                    .onSubmit { focusedField = .password }
                    .textFieldStyle(.plain).padding(11)
                    .background(
                        .primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Square Enix Password").font(.caption).foregroundStyle(
                    .secondary)
                SecureField("Square Enix Password", text: $model.password)
                    .textContentType(.password).focused(
                        $focusedField, equals: .password
                    )
                    .onSubmit { model.login() }
                    .textFieldStyle(.plain).padding(11)
                    .background(
                        .primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("One-Time Password")
                    Spacer()
                    Text("Optional").foregroundStyle(.tertiary)
                }.font(.caption).foregroundStyle(.secondary)
                OneTimeCodeField(text: $model.oneTimePassword)
                    .onSubmit { model.login() }
            }
            HStack {
                Toggle(
                    "Auto-OTP",
                    isOn: Binding(
                        get: { model.automaticOTP },
                        set: model.toggleAutomaticOTP))
                Spacer()
                Toggle(
                    "Auto-Login",
                    isOn: Binding(
                        get: { model.autoLogin },
                        set: {
                            model.autoLogin = $0
                            if $0 { confirmAutoLogin = true }
                        }))
            }.font(.caption).toggleStyle(.checkbox)
            Button {
                model.login()
            } label: {
                HStack {
                    Spacer()
                    Text("Login").fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                    Spacer()
                }.padding(.vertical, 8)
            }
            .xomPrimaryButton().controlSize(.large)
            .keyboardShortcut(.defaultAction).disabled(!model.canLogin)
            .padding(.top, 2)
        }
    }

    @ViewBuilder private var operation: some View {
        if model.phase == .login {
            VStack(spacing: 26) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                Text(model.status)
                    .font(
                        .system(size: 18, weight: .semibold, design: .rounded)
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 32)
        } else {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text(
                        model.phase == .patching
                            ? String(localized: "Updating your game")
                            : model.phase == .repairing
                                ? String(localized: "Repairing game files")
                                : model.status
                    )
                    .font(.headline).fixedSize(
                        horizontal: false, vertical: true)
                }
                if model.phase == .patching {
                    PatchProgressView(model: model.patcher)
                }
                if model.phase == .repairing {
                    RepairProgressView(model: model.repairer)
                }
            }
            .padding(.vertical, 14)
        }
    }

    private var footer: some View {
        HStack {
            Circle().fill(
                model.phase == .ready || model.phase == .playing
                    ? Color.green : XOMStyle.accent
            )
            .frame(width: 6, height: 6).accessibilityHidden(true)
            Text(model.status).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Link(
                "Help & community",
                destination: URL(
                    string: "https://www.xivmac.com/xiv-mac-application-help")!
            )
            .font(.caption).foregroundStyle(.secondary)
            Text("XIV ON MAC").font(.system(size: 9, weight: .bold)).tracking(2)
                .foregroundStyle(
                    .tertiary)
        }
    }

    private var rosettaSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            ToolHeader(
                title: "ROSETTA_REQUIRED",
                subtitle: "ROSETTA_REQUIRED_INFORMATIVE", symbol: "cpu")
            HStack {
                Button("ROSETTA_REQUIRED_CANCEL_BUTTON", role: .cancel) {
                    Util.quit()
                }
                Spacer()
                Button("ROSETTA_REQUIRED_INSTALL_BUTTON") {
                    model.installRosetta()
                }
                .xomPrimaryButton().keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 540)
            .interactiveDismissDisabled()
    }
}

#if DEBUG
    #Preview("Launcher") {
        LauncherView(model: PreviewContent.launcher())
    }

    #Preview("Starting game") {
        LauncherView(model: PreviewContent.launcher(startingGame: true))
    }

    #Preview("Featured banners") {
        BannerCarousel(banners: PreviewContent.banners, isLoading: false)
    }

    #Preview("One-time password") {
        OneTimeCodeField(text: .constant("123456")).padding().frame(width: 304)
    }

    #Preview("Auto-OTP setup") {
        OTPSetupView(username: "WarriorOfLight", save: { _ in })
    }
#endif

private struct OneTimeCodeField: View {
    @Binding var text: String
    @State private var input = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "key.horizontal")
                    .foregroundStyle(isFocused ? XOMStyle.accent : .secondary)
                    .accessibilityHidden(true)
                TextField("000000", text: $input)
                    .textFieldStyle(.plain)
                    .textContentType(.oneTimeCode)
                    .font(
                        .system(size: 23, weight: .medium, design: .monospaced)
                    )
                    .multilineTextAlignment(.center)
                    .tint(XOMStyle.accent)
                    .focused($isFocused)
                    .accessibilityLabel("One-Time Password")
                    .accessibilityHint("Optional six-digit code")
                Text("\(input.count)/6")
                    .font(
                        .system(size: 10, weight: .medium, design: .monospaced)
                    )
                    .foregroundStyle(.secondary).accessibilityHidden(true)
            }
            HStack(spacing: 5) {
                ForEach(0..<6) { index in
                    Capsule().fill(
                        index < input.count
                            ? XOMStyle.accent : .primary.opacity(0.1)
                    )
                    .frame(height: 2)
                }
            }.accessibilityHidden(true)
        }
        .padding(12)
        .background(
            .primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isFocused ? XOMStyle.accent : .primary.opacity(0.1),
                    lineWidth: isFocused ? 1.5 : 1)
        }
        .onAppear { input = text }
        .onChange(of: input) { value in
            let digits = OneTimeCode.sanitize(value)
            if input != digits { input = digits }
            if text != digits { text = digits }
        }
        .onChange(of: text) { value in
            if input != value { input = value }
        }
    }
}

private struct NewsRow: View {
    let item: Frontier.Info.News
    @State private var hovered = false
    var body: some View {
        Group {
            if let url = item.destination(languageCode: Settings.language.code)
            {
                Link(destination: url) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }.onHover { hovered = $0 }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let date = item.publishedAt {
                    Text(
                        date, format: .dateTime.month(.abbreviated).day().year()
                    )
                    .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11).padding(.horizontal, 4)
        .background(
            hovered ? Color.primary.opacity(0.04) : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
    }
}

private struct BannerCarousel: View {
    let banners: [Frontier.LoadedBanner]
    let isLoading: Bool
    @State private var position = 0
    @State private var hovered = false
    @StateObject private var scrollMonitor = BannerScrollMonitor()
    @FocusState private var focusedBanner: Int?
    @FocusState private var focusedControl: Int?
    @AccessibilityFocusState private var accessibleBanner: Int?
    @AccessibilityFocusState private var accessibleControl: Int?
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private
        var reduceTransparency
    private let timer = Timer.publish(every: 8, on: .main, in: .common)
        .autoconnect()

    private var index: Int { bannerIndex(at: position) }
    private var isInteracting: Bool {
        hovered || focusedBanner != nil || focusedControl != nil
            || accessibleBanner != nil || accessibleControl != nil
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.primary.opacity(0.035))
            if !banners.isEmpty {
                // Adjacent cycles fill the edges during spring overshoot.
                ForEach(
                    (position - banners.count)...(position + banners.count),
                    id: \.self
                ) { slot in
                    let banner = banners[bannerIndex(at: slot)]
                    Link(destination: banner.destination) {
                        Image(nsImage: banner.image).resizable()
                            .scaledToFit()
                    }
                    .buttonStyle(.plain)
                    .frame(width: 640, height: 250)
                    .offset(x: CGFloat(slot - position) * 640)
                    .transition(.identity)
                    .allowsHitTesting(slot == position)
                    .disabled(slot != position)
                    .accessibilityHidden(slot != position)
                    .accessibilityLabel("Open featured news")
                    .focused($focusedBanner, equals: slot)
                    .accessibilityFocused($accessibleBanner, equals: slot)
                    .accessibilityAction(named: Text("Previous banner")) {
                        advance(-1)
                    }
                    .accessibilityAction(named: Text("Next banner")) {
                        advance(1)
                    }
                    .onMoveCommand { direction in
                        switch direction {
                        case .left: advance(-1)
                        case .right: advance(1)
                        default: break
                        }
                    }
                }
            } else if isLoading {
                ProgressView().controlSize(.small)
                    .accessibilityLabel("Loading featured news…")
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }
        }
        .frame(width: 640, height: 250)
        .overlay {
            if banners.count > 1 {
                GlassGroup {
                    controls
                        .allowsHitTesting(hovered)
                        .accessibilityHidden(!hovered)
                }
                .animation(
                    reduceMotion
                        ? nil : .spring(response: 0.4, dampingFraction: 0.86),
                    value: hovered)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.12))
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onHover { inside in
            hovered = inside
            updateScrollMonitoring()
        }
        .onChange(of: activeState) { _ in updateScrollMonitoring() }
        .onDisappear {
            scrollMonitor.stop()
            hovered = false
        }
        .onChange(of: banners.map(\.id)) { _ in
            position = 0
            updateScrollMonitoring()
        }
        .onReceive(timer) { _ in
            if !isInteracting && !reduceMotion && activeState != .inactive {
                advance(1)
            }
        }
    }

    private var controls: some View {
        ZStack(alignment: .bottom) {
            HStack {
                if hovered {
                    arrow("chevron.left", label: "Previous banner", step: -1)
                }
                Spacer()
                if hovered {
                    arrow("chevron.right", label: "Next banner", step: 1)
                }
            }
            .frame(maxHeight: .infinity)
            if hovered {
                pagination
                    .frame(height: 32)
                    .zIndex(1)
                    .transition(
                        reduceMotion
                            ? .identity
                            : .asymmetric(
                                insertion: .offset(y: 56).combined(
                                    with: .opacity),
                                removal: .opacity))
            }
        }
        .buttonStyle(.plain)
        .padding(12)
    }

    private var pageButtons: some View {
        HStack(spacing: 0) {
            ForEach(banners.indices, id: \.self) { page in
                Button {
                    change(to: page)
                } label: {
                    Capsule().fill(
                        (reduceTransparency ? Color.primary : .white)
                            .opacity(page == index ? 1 : 0.45)
                    )
                    .frame(width: page == index ? 18 : 5, height: 5)
                    .frame(width: 28, height: 32)
                    .contentShape(Rectangle())
                }.accessibilityLabel("Banner \(page + 1)")
                    .accessibilityAddTraits(page == index ? .isSelected : [])
                    .focused($focusedControl, equals: page)
                    .accessibilityFocused($accessibleControl, equals: page)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private var pagination: some View {
        if reduceTransparency {
            pageButtons.background(
                Color(nsColor: .controlBackgroundColor), in: Capsule())
        } else if #available(macOS 26.0, *) {
            pageButtons
                .background(.black.opacity(0.3), in: Capsule())
                .glassEffect(.regular.interactive(), in: Capsule())
                .glassEffectTransition(.materialize)
        } else {
            pageButtons.background(.regularMaterial, in: Capsule())
        }
    }

    private func arrow(
        _ symbol: String, label: LocalizedStringKey, step: Int
    ) -> some View {
        Button {
            advance(step)
        } label: {
            arrowImage(symbol)
        }
        .accessibilityLabel(label)
        .focused($focusedControl, equals: step < 0 ? -1 : banners.count)
        .accessibilityFocused(
            $accessibleControl, equals: step < 0 ? -1 : banners.count
        )
        .transition(
            reduceMotion
                ? .identity
                : .asymmetric(
                    insertion: .offset(x: CGFloat(step) * 68).combined(
                        with: .opacity),
                    removal: .opacity))
    }

    @ViewBuilder private func arrowImage(_ symbol: String) -> some View {
        let image = Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.3), in: Circle())
            .xomGlass(radius: 22, interactive: true)
            .contentShape(Circle())
        if #available(macOS 26.0, *) {
            image.glassEffectTransition(.materialize)
        } else {
            image
        }
    }

    private func updateScrollMonitoring() {
        scrollMonitor.stop()
        guard hovered, banners.count > 1 else {
            return
        }
        scrollMonitor.start { advance($0) }
    }

    private func advance(_ step: Int) {
        guard banners.count > 1 else { return }
        withAnimation(
            reduceMotion
                ? nil
                : .spring(response: 0.65, dampingFraction: 0.74)
        ) {
            position += step
        }
    }

    private func change(to page: Int) {
        guard banners.indices.contains(page), page != index else { return }
        let forward = (page - index + banners.count) % banners.count
        let backward = forward - banners.count
        advance(forward <= -backward ? forward : backward)
    }

    private func bannerIndex(at slot: Int) -> Int {
        guard !banners.isEmpty else { return 0 }
        return (slot % banners.count + banners.count) % banners.count
    }
}

@MainActor
private final class BannerScrollMonitor: ObservableObject {
    private var monitor: Any?
    private var accumulatedDelta: CGFloat = 0
    private var lastEventTime: TimeInterval = 0
    private var lastAdvanceTime = -TimeInterval.infinity
    private var advancedInGesture = false

    func start(advance: @escaping (Int) -> Void) {
        stop()
        let windowNumber = NSWindow.windowNumber(
            at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
        guard
            let window = NSApp.windows.first(where: {
                $0.windowNumber == windowNumber
            })
        else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self, weak window] event in
            guard let self, let window, event.window === window,
                window.isVisible, !NSApp.isHidden
            else { return event }
            if let step = self.step(for: event) { advance(step) }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        accumulatedDelta = 0
        lastEventTime = 0
        lastAdvanceTime = -.infinity
        advancedInGesture = false
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    private func step(for event: NSEvent) -> Int? {
        if event.phase.contains(.began)
            || (event.phase.isEmpty && event.timestamp - lastEventTime > 0.25)
        {
            accumulatedDelta = 0
            advancedInGesture = false
        }
        lastEventTime = event.timestamp
        guard event.momentumPhase.isEmpty else { return nil }
        guard !event.phase.contains(.ended),
            !event.phase.contains(.cancelled)
        else {
            accumulatedDelta = 0
            return nil
        }
        guard event.phase.isEmpty || !advancedInGesture else { return nil }
        let delta =
            abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        if delta * accumulatedDelta < 0 { accumulatedDelta = 0 }
        accumulatedDelta += delta
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 40 : 1
        guard abs(accumulatedDelta) >= threshold,
            event.timestamp - lastAdvanceTime >= 0.35
        else { return nil }
        let step = accumulatedDelta < 0 ? 1 : -1
        accumulatedDelta = 0
        lastAdvanceTime = event.timestamp
        advancedInGesture = true
        return step
    }
}

struct OTPSetupView: View {
    let username: String
    let save: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var secret = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ToolHeader(
                title: "Auto-OTP", subtitle: "OTP_INFORMATIVE",
                symbol: "lock.shield")
            Text(username).font(.headline)
            SecureField("OTP secret", text: $secret).textFieldStyle(
                .roundedBorder)
            HStack {
                Button("BUTTON_CANCEL", role: .cancel) { dismiss() }
                Spacer()
                Button("BUTTON_OK") {
                    save(secret)
                    secret = ""
                }
                .xomPrimaryButton().disabled(
                    secret.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
                .keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 500)
    }
}
