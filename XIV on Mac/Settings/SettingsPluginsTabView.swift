//
//  SettingsPluginsTabView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 1/14/23.
//

import SwiftUI
import XIVLauncher

struct SettingsPluginsTabView: View {
    @StateObject private var viewModel = ViewModel()
    @State private var editingKey = false
    @State private var betaKey = ""
    var body: some View {
        VStack(spacing: 18) {
            SettingsSection(title: "Dalamud", symbol: "puzzlepiece.extension") {
                Text("SETTINGS_PLUGINS_WHAT_IS_DALAMUD_BLURB").foregroundStyle(
                    .secondary)
                Toggle(
                    "SETTINGS_PLUGINS_DALAMUD_ENABLE",
                    isOn: $viewModel.dalamudEnabled)
                Toggle(
                    "SETTINGS_PLUGINS_DALAMUD_ENTRYPOINT",
                    isOn: $viewModel.dalamudEntryPoint
                )
                .disabled(!viewModel.dalamudEnabled)
                if !viewModel.dalamudEntryPoint {
                    Text("SETTINGS_PLUGINS_DALAMUD_DELAY_BLURB").font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("SETTINGS_PLUGINS_DALAMUD_DELAY_LABEL")
                        TextField("0", text: $viewModel.dalamudDelay).frame(
                            width: 70)
                        Text("SETTINGS_PLUGINS_DALAMUD_DELAY_UNITS")
                    }
                }
            }
            SettingsSection(
                title: "SETTINGS_PLUGINS_DALAMUD_BRANCH_LABEL",
                symbol: "arrow.triangle.branch"
            ) {
                Text("SETTINGS_PLUGINS_DALAMUD_BRANCH_BLURB").foregroundStyle(
                    .secondary)
                if viewModel.isFetching { ProgressView().controlSize(.small) }
                Picker(
                    "SETTINGS_PLUGINS_DALAMUD_BRANCH_LABEL",
                    selection: $viewModel.dalamudBetaKind
                ) {
                    ForEach(viewModel.branches) { branch in
                        Text(branch.displayNameWithAvailability).tag(
                            branch.track)
                    }
                }.disabled(viewModel.isFetching || viewModel.branches.isEmpty)
                if let selected = viewModel.selectedBranch {
                    if !(selected.isApplicableForCurrentGameVer ?? true) {
                        Label(
                            "SETTINGS_PLUGINS_DALAMUD_BRANCH_UNAVAILABLE",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }
                    if let description = selected.description,
                        !description.isEmpty
                    {
                        Text(description).font(.caption).foregroundStyle(
                            .secondary)
                    }
                    Text(
                        String(
                            format: NSLocalizedString(
                                "SETTINGS_PLUGINS_DALAMUD_TRACK_FORMAT",
                                comment: ""),
                            selected.track)
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                if let error = viewModel.fetchError {
                    Text(error).foregroundStyle(.red).font(.caption)
                    Button("Try again") { viewModel.refreshBranches() }
                }
                Button("SETTINGS_PLUGINS_DALAMUD_ENTER_BETA_KEY") {
                    betaKey = Settings.dalamudBetaKey
                    editingKey = true
                }.disabled(viewModel.isFetching)
            }
        }
        .textFieldStyle(.roundedBorder)
        .onAppear { viewModel.refreshBranches() }
        .sheet(isPresented: $editingKey) {
            VStack(alignment: .leading, spacing: 20) {
                ToolHeader(
                    title: "SETTINGS_PLUGINS_DALAMUD_ENTER_BETA_KEY_TITLE",
                    subtitle: "SETTINGS_PLUGINS_DALAMUD_ENTER_BETA_KEY_INFO",
                    symbol: "key")
                SecureField("Beta key", text: $betaKey).textFieldStyle(
                    .roundedBorder)
                HStack {
                    Button("BUTTON_CANCEL", role: .cancel) {
                        editingKey = false
                        betaKey = ""
                    }
                    Spacer()
                    Button("BUTTON_OK") {
                        viewModel.saveBetaKey(betaKey)
                        betaKey = ""
                        editingKey = false
                    }.xomPrimaryButton().keyboardShortcut(.defaultAction)
                }
            }.padding(32).frame(width: 480)
        }
    }
}

#if DEBUG
    #Preview("Plugins") {
        ScrollView {
            SettingsPluginsTabView().padding(28)
        }
        .frame(width: 755, height: 640)
        .tint(XOMStyle.accent)
    }
#endif

private struct DalamudBranch: Identifiable, Codable, Equatable {
    let displayName: String
    let description: String?
    let track: String
    let hidden: Bool
    let key: String
    let assemblyVersion: String?
    let runtimeVersion: String?
    let runtimeRequired: Bool?
    let supportedGameVer: String?
    let isApplicableForCurrentGameVer: Bool?
    let downloadUrl: String?

    var id: String { track }

    var displayNameWithAvailability: String {
        if isApplicableForCurrentGameVer ?? true { return displayName }
        return
            "\(displayName) \(NSLocalizedString("SETTINGS_PLUGINS_DALAMUD_UNAVAILABLE_SUFFIX", comment: ""))"
    }
}

extension SettingsPluginsTabView {
    @MainActor class ViewModel: ObservableObject {
        @Published var dalamudEnabled: Bool = Settings.dalamudEnabled {
            didSet { Settings.dalamudEnabled = dalamudEnabled }
        }

        @Published var dalamudEntryPoint: Bool = Settings.dalamudEntryPoint {
            didSet { Settings.dalamudEntryPoint = dalamudEntryPoint }
        }

        @Published var dalamudDelay: String = .init(Settings.injectionDelay) {
            didSet { Settings.injectionDelay = Double(dalamudDelay) ?? 0 }
        }

        @Published fileprivate var branches: [DalamudBranch] = []

        @Published var dalamudBetaKind: String = Settings.dalamudBetaKind {
            didSet {
                Settings.dalamudBetaKind = dalamudBetaKind
                if let betaKey = selectedBranch?.key {
                    Settings.dalamudBetaKey = betaKey
                }
                updateDalamud(dalamudBetaKind, Settings.dalamudBetaKey)
            }
        }

        @Published var isFetching: Bool = false
        @Published var fetchError: String? = nil

        fileprivate var selectedBranch: DalamudBranch? {
            return branches.first { $0.track == dalamudBetaKind }
        }

        func refreshBranches() {
            if Util.isPreview {
                branches = [
                    DalamudBranch(
                        displayName: "Stable", description: "Stable release",
                        track: dalamudBetaKind, hidden: false, key: "",
                        assemblyVersion: nil, runtimeVersion: nil,
                        runtimeRequired: nil, supportedGameVer: nil,
                        isApplicableForCurrentGameVer: true, downloadUrl: nil)
                ]
                return
            }
            Task { await fetchBranchesAsync() }
        }

        private func fetchBranchesAsync() async {
            await MainActor.run {
                self.isFetching = true
                self.fetchError = nil
            }
            defer {
                Task { @MainActor in self.isFetching = false }
            }

            guard
                let url = URL(
                    string: "https://kamori.goats.dev/Dalamud/Release/Meta"
                )
            else {
                await MainActor.run {
                    self.fetchError = NSLocalizedString(
                        "SETTINGS_PLUGINS_DALAMUD_FETCH_ERROR_INVALID_URL",
                        comment: "")
                }
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(
                    from: url
                )
                if let http = response as? HTTPURLResponse,
                    http.statusCode != 200
                {
                    await MainActor.run {
                        self.fetchError = String(
                            format: NSLocalizedString(
                                "SETTINGS_PLUGINS_DALAMUD_FETCH_ERROR_HTTP",
                                comment: ""),
                            http.statusCode)
                    }
                    return
                }
                let decoder = JSONDecoder()
                let dict = try decoder.decode(
                    [String: DalamudBranch].self,
                    from: data
                )
                let allBranches = Array(dict.values)
                let betaKey = Settings.dalamudBetaKey
                let filtered = allBranches.filter { br in
                    return !br.hidden
                        || (br.hidden && br.key == betaKey)
                }

                await MainActor.run {
                    self.branches = filtered
                    if filtered.first(where: {
                        $0.track == dalamudBetaKind
                            && $0.key == Settings.dalamudBetaKey
                    }) != nil {
                        Log.information(
                            "Selected active Dalamud branch \(dalamudBetaKind)")
                    } else if let selectedBranch = filtered.first(where: {
                        $0.key == Settings.dalamudBetaKey
                    }) {
                        Log.information(
                            "Selected active Dalamud branch \(selectedBranch.track)"
                        )
                        self.dalamudBetaKind = selectedBranch.track
                    } else if let release = filtered.first(where: {
                        $0.track.lowercased() == "release"
                    }) {
                        Log.information(
                            "Falling back to latest stable Dalamud release")
                        self.dalamudBetaKind = release.track
                    } else {
                        Log.warning(
                            "Could not find a suitable Dalamud release or beta key"
                        )
                        self.dalamudBetaKind = ""
                    }
                }
                updateDalamud(dalamudBetaKind, Settings.dalamudBetaKey)

            } catch {
                await MainActor.run {
                    self.fetchError = String(
                        format: NSLocalizedString(
                            "SETTINGS_PLUGINS_DALAMUD_FETCH_ERROR_GENERIC",
                            comment: ""),
                        error.localizedDescription)
                }
            }
        }

        func saveBetaKey(_ key: String) {
            Settings.dalamudBetaKey = key.trimmingCharacters(
                in: .whitespacesAndNewlines)
            refreshBranches()
        }
    }
}
