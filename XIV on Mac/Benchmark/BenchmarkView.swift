//
//  BenchmarkView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 2/20/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct BenchmarkView: View {
    @AppStorage(Benchmark.benchmarkFolderPref) private var benchmarkFolder = ""
    @State private var importingCharacters = false
    @State private var choosingFolder = false
    @State private var benchmarkRunning = false
    @State private var setDefaults = true
    @State private var benchType: BenchmarkType = .hd
    @State private var benchMode: BenchmarkMode = .benchmark
    @State private var chosenCostume: BenchmarkCostumes = .jobGear
    @State private var availableCharacters: [CharacterDataSlot] = []
    @State private var selectedAppearanceSlot: Int?
    @State private var notice: AppNotice?

    private var benchmarkVersion: BenchmarkVersion {
        if Util.isPreview { return .dawntrail }
        return Benchmark.benchmarkVersion()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(
                    title: "BENCHMARK_FOLDER_LABEL", symbol: "folder"
                ) {
                    HStack {
                        Text(
                            benchmarkFolder.isEmpty
                                ? String(
                                    localized:
                                        "Choose your benchmark installation.")
                                : benchmarkFolder
                        )
                        .font(.callout).foregroundStyle(.secondary).lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        Spacer()
                        Button("BENCHMARK_FOLDER_SELECT_BUTTON") {
                            choosingFolder = true
                        }
                    }
                }
                SettingsSection(
                    title: "BENCHMARK_MODE_LABEL", symbol: "gamecontroller"
                ) {
                    Picker("BENCHMARK_MODE_LABEL", selection: $benchMode) {
                        Text("BENCHMARK_MODE_BENCHMARK_LABEL").tag(
                            BenchmarkMode.benchmark)
                        Text("BENCHMARK_MODE_CREATOR_LABEL").tag(
                            BenchmarkMode.characterCreator)
                    }.pickerStyle(.segmented).labelsHidden()
                    Picker("BENCHMARK_TYPE_LABEL", selection: $benchType) {
                        Text("BENCHMARK_TYPE_HD").tag(BenchmarkType.hd)
                        Text("BENCHMARK_TYPE_QHD").tag(BenchmarkType.wqhd)
                        Text("BENCHMARK_TYPE_CUSTOM").tag(BenchmarkType.custom)
                    }
                    Toggle("BENCHMARK_SET_DEFAULTS", isOn: $setDefaults)
                }
                if benchmarkVersion == .dawntrail && benchMode == .benchmark {
                    SettingsSection(
                        title: "BENCHMARK_CHARACTER_APPEARANCE",
                        symbol: "person.crop.rectangle"
                    ) {
                        Picker(
                            "BENCHMARK_CHARACTER_APPEARANCE",
                            selection: $selectedAppearanceSlot
                        ) {
                            Text("BENCHMARK_DEFAULT_APPEARANCE").tag(
                                nil as Int?)
                            ForEach(availableCharacters) { character in
                                Text(character.longDisplayName).tag(
                                    character.id as Int?)
                            }
                        }
                        Picker(
                            "BENCHMARK_CHARACTER_COSTUME",
                            selection: $chosenCostume
                        ) {
                            ForEach(BenchmarkCostumes.allCases, id: \.self) {
                                costume in
                                Text(costume.localizedName).tag(costume)
                            }
                        }
                        Button("BENCHMARK_IMPORT_CHARACTER_BUTTON") {
                            importingCharacters = true
                        }
                    }
                }
                HStack {
                    if benchmarkRunning {
                        ProgressView().controlSize(.small)
                        Text("Benchmark in progress…").foregroundStyle(
                            .secondary)
                    }
                    Spacer()
                    Button(action: launch) {
                        Label(
                            "BENCHMARK_START_BUTTON", systemImage: "play.fill"
                        ).padding(.vertical, 5)
                    }
                    .xomPrimaryButton().controlSize(.large)
                    .disabled(benchmarkRunning || benchmarkVersion == .unknown)
                }
            }.padding(28)
        }
        .frame(minWidth: 740, minHeight: 580)
        .modifier(AppWindowBackground())
        .disabled(benchmarkRunning)
        .notice($notice)
        .sheet(isPresented: $importingCharacters, onDismiss: refreshCharacters)
        {
            CharacterDataImportView().frame(minWidth: 760, minHeight: 640)
        }
        .fileImporter(
            isPresented: $choosingFolder, allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                if Benchmark.check(folder: url) {
                    benchmarkFolder = url.path
                    selectedAppearanceSlot = nil
                    refreshCharacters()
                } else {
                    notice = AppNotice(
                        "BENCHMARK_TITLE",
                        "SELECT_BENCHMARK_PATH_ERROR_INFORMATIVE")
                }
            case .failure(let error):
                notice = AppNotice(
                    "BENCHMARK_TITLE", error.localizedDescription)
            }
        }
        .onAppear(perform: refreshCharacters)
    }

    private func refreshCharacters() {
        #if DEBUG
            if Util.isPreview {
                availableCharacters = [PreviewContent.character]
                return
            }
        #endif
        availableCharacters = Benchmark.findAvailableDemoCharacters().sorted {
            $0.id < $1.id
        }
    }

    private func launch() {
        benchmarkRunning = true
        var options = BenchmarkOptions()
        options.type = benchType
        options.appearanceSlot = selectedAppearanceSlot
        options.costume = chosenCostume
        options.mode = benchMode
        let folder = URL(fileURLWithPath: benchmarkFolder)
        let defaults = setDefaults
        Task {
            defer {
                benchmarkRunning = false
                refreshCharacters()
            }
            do {
                try await backgroundWork { GraphicsInstaller.ensureBackend() }
                if let result = try await Benchmark.launchFrom(
                    folder: folder, options: options, setDefaults: defaults)
                {
                    notice = AppNotice("BENCHMARK_TITLE", result)
                }
            } catch {
                notice = AppNotice(
                    "BENCHMARK_TITLE", error.localizedDescription)
            }
        }
    }
}

#if DEBUG
    #Preview("Benchmark") {
        BenchmarkView().frame(width: 800, height: 680).tint(XOMStyle.accent)
    }
#endif
