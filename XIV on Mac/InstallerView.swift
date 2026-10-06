//
//  InstallerView.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 29.09.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct InstallerView: View {
    private enum Source: String, CaseIterable { case download, copy, existing }
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var platform = Settings.platform
    @State private var freeTrial = Settings.freeTrial
    @State private var dalamud = Settings.dalamudEnabled
    @State private var source: Source = .download
    @State private var folder: URL?
    @State private var choosingFolder = false
    @State private var working = false
    @State private var notice: AppNotice?
    @State private var detectedFolders: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ToolHeader(
                title: "Welcome to XIV on Mac",
                subtitle: "A little setup. A whole world to explore.",
                symbol: "sparkles")
            HStack(spacing: 8) {
                stepLabel("License", number: 0)
                Rectangle().fill(.primary.opacity(0.12)).frame(height: 1)
                stepLabel("Experience", number: 1)
                Rectangle().fill(.primary.opacity(0.12)).frame(height: 1)
                stepLabel("Game files", number: 2)
            }
            Group {
                switch step {
                case 0: license
                case 1: experience
                default: files
                }
            }.frame(maxWidth: .infinity, minHeight: 285, alignment: .topLeading)
            Divider()
            HStack {
                Button("BUTTON_CANCEL", role: .cancel) { dismiss() }.disabled(
                    working)
                Spacer()
                if step > 0 {
                    Button("Previous") { step -= 1 }.disabled(working)
                }
                Button(step < 2 ? "Next" : "Start your adventure") {
                    if step < 2 { step += 1 } else { install() }
                }
                .xomPrimaryButton().keyboardShortcut(.defaultAction)
                .disabled(
                    working
                        || (step == 2 && source != .download && folder == nil))
            }
        }
        .padding(32).frame(width: 620)
        .tint(XOMStyle.accent)
        .interactiveDismissDisabled(working)
        .notice($notice)
        .fileImporter(
            isPresented: $choosingFolder, allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                if Self.isValidGameDirectory(gamePath: url.path) {
                    folder = url
                } else {
                    notice = AppNotice(
                        "INSTALLER_PATH_INVALID_MESSAGE",
                        "INSTALLER_PATH_INVALID_INFORMATIVE")
                }
            case .failure(let error):
                notice = AppNotice(
                    "INSTALLER_PATH_INVALID_MESSAGE", error.localizedDescription
                )
            }
        }
        .task { detectedFolders = Self.detectInstallations() }
    }

    private func stepLabel(_ title: LocalizedStringKey, number: Int)
        -> some View
    {
        HStack(spacing: 8) {
            Text("\(number + 1)").font(.caption.bold()).frame(
                width: 25, height: 25
            )
            .background(
                number <= step ? XOMStyle.accent : .secondary.opacity(0.15),
                in: Circle()
            )
            .foregroundStyle(number <= step ? .white : .secondary)
            Text(title).font(.caption.weight(step == number ? .bold : .regular))
        }.fixedSize()
    }

    private var license: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a License:").font(.title2.bold())
            Text("SETTINGS_GENERAL_LANGUAGE_AND_LICENSE_BLURB").foregroundStyle(
                .secondary)
            Picker("SETTINGS_PLATFORM_PICKER", selection: $platform) {
                Text("SETTINGS_PLATFORM_MAC").tag(FFXIVPlatform.mac)
                Text("SETTINGS_PLATFORM_WINDOWS").tag(FFXIVPlatform.windows)
                Text("SETTINGS_PLATFORM_STEAM").tag(FFXIVPlatform.steam)
            }.pickerStyle(.segmented).labelsHidden().padding(.vertical, 8)
            Toggle("SETTINGS_FREE_TRIAL", isOn: $freeTrial)
            Text("SETTINGS_GENERAL_FREE_TRIAL_BLURB").font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var experience: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Make it your adventure.").font(.title2.bold())
            option(
                "Launch with Dalamud Plugin Support",
                subtitle: "You can disable Dalamud anytime",
                symbol: "puzzlepiece.extension", selected: dalamud
            ) { dalamud = true }
            option(
                "Launch Vanilla Game",
                subtitle: "You can chose to enable Dalamud later",
                symbol: "gamecontroller", selected: !dalamud
            ) { dalamud = false }
        }
    }

    private var files: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Select how you want to handle the game files:").font(
                .title2.bold())
            if working {
                ProgressView("Preparing game files…")
                Text(
                    "You can leave this window open while your files are copied."
                ).foregroundStyle(
                    .secondary)
            } else {
                Picker("Game files", selection: $source) {
                    Text("Download").tag(Source.download)
                    Text("Copy existing install").tag(Source.copy)
                    Text("Choose existing install").tag(Source.existing)
                }.pickerStyle(.segmented).labelsHidden()
                if source == .download {
                    Label(
                        "Download and Install the game.",
                        systemImage: "arrow.down.circle"
                    ).padding(
                        .top, 12)
                    Text(Settings.defaultGameLoc.path).font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text(
                        source == .copy
                            ? "Copy your game files into XIV on Mac’s installation folder."
                            : "Point XIV on Mac towards a custom folder."
                    )
                    .foregroundStyle(.secondary)
                    ForEach(detectedFolders, id: \.path) { url in
                        Button {
                            folder = url
                        } label: {
                            Label(
                                url.path,
                                systemImage: folder == url
                                    ? "checkmark.circle.fill" : "folder"
                            )
                            .lineLimit(2).truncationMode(.middle)
                        }.buttonStyle(.bordered)
                    }
                    HStack {
                        Text(
                            folder?.path
                                ?? String(
                                    localized:
                                        "Select the folder containing game and boot."
                                )
                        )
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        .truncationMode(.middle)
                        Spacer()
                        Button("Choose folder…") { choosingFolder = true }
                    }
                }
            }
        }
    }

    private func option(
        _ title: LocalizedStringKey, subtitle: LocalizedStringKey,
        symbol: String, selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: symbol).font(.title2).frame(width: 30)
                    .foregroundStyle(XOMStyle.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        selected ? XOMStyle.accent : .secondary)
            }.padding(18).contentShape(Rectangle())
        }.buttonStyle(.plain).xomGlass(radius: 16, interactive: true)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func install() {
        working = true
        let source = source
        let folder = folder
        let platform = platform
        Task {
            do {
                try await backgroundWork {
                    if source == .copy, let folder {
                        let destination = Settings.defaultGameLoc
                        if folder.standardizedFileURL
                            != destination.standardizedFileURL
                        {
                            try FileManager.default.createDirectory(
                                at: destination.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
                            guard
                                !FileManager.default.fileExists(
                                    atPath: destination.path)
                            else {
                                throw CocoaError(.fileWriteFileExists)
                            }
                            let staging =
                                destination.deletingLastPathComponent()
                                .appendingPathComponent(
                                    ".xiv-import-" + UUID().uuidString)
                            defer {
                                try? FileManager.default.removeItem(at: staging)
                            }
                            try FileManager.default.copyItem(
                                at: folder, to: staging)
                            try FileManager.default.moveItem(
                                at: staging, to: destination)
                        }
                        Settings.gamePath = destination
                    } else if source == .existing, let folder {
                        Settings.gamePath = folder
                    } else {
                        Settings.gamePath = Settings.defaultGameLoc
                    }
                    Settings.platform = platform
                }
                Settings.freeTrial = freeTrial
                Settings.dalamudEnabled = dalamud
                working = false
                onComplete()
            } catch {
                working = false
                notice = AppNotice(
                    "Installation could not be completed",
                    error.localizedDescription)
            }
        }
    }

    static func isValidGameDirectory(gamePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: gamePath + "/game/ffxiv_dx11.exe")
            && FileManager.default.fileExists(atPath: gamePath + "/boot")
    }

    private static func detectInstallations() -> [URL] {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[
                0]
        return [
            "FINAL FANTASY XIV ONLINE/Bottles/published_Final_Fantasy/drive_c/Program Files (x86)/SquareEnix/FINAL FANTASY XIV - A Realm Reborn",
            "CrossOver/Bottles/Final Fantasy XIV Online/drive_c/Program Files (x86)/SquareEnix/FINAL FANTASY XIV - A Realm Reborn",
        ].map { support.appendingPathComponent($0) }.filter {
            isValidGameDirectory(gamePath: $0.path)
        }
    }
}

#if DEBUG
    #Preview("Installer") {
        InstallerView(onComplete: {})
    }
#endif
