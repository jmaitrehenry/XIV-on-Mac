//
//  CharacterDataImportView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 4/17/24.
//

import SwiftUI

struct CharacterDataListView: View {
    @Binding var characterData: [CharacterDataSlot]
    @Binding var selection: Int?
    var body: some View {
        List(selection: $selection) {
            ForEach(characterData) { character in
                CharacterSlotView(
                    characterData: character,
                    selected: selection == character.id
                )
                .tag(character.id).listRowSeparator(.hidden).listRowBackground(
                    Color.clear)
            }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }
}

#if DEBUG
    #Preview("Import characters") {
        CharacterDataImportView().frame(width: 760, height: 640).tint(
            XOMStyle.accent)
    }

    #Preview("Character list") {
        CharacterDataListView(
            characterData: .constant([PreviewContent.character]),
            selection: .constant(1)
        )
        .frame(width: 340, height: 400)
    }
#endif

class CharacterListState: ObservableObject {
    @Published var targetCharacters: [CharacterDataSlot] = [CharacterDataSlot]()
    @Published var sourceCharacters: [CharacterDataSlot] = [CharacterDataSlot]()

    func pad(cdsArray: [CharacterDataSlot], toSize: Int) -> [CharacterDataSlot]
    {
        var ReturnMe: [CharacterDataSlot] = [CharacterDataSlot]()
        let highestSlot: Int = cdsArray.max()?.id ?? 0
        let listSize = max(toSize, highestSlot, 1)
        for slot in 1...listSize {
            if let existingData = cdsArray.filter({ $0.id == slot }).first {
                ReturnMe.append(existingData)
            } else {
                ReturnMe.append(CharacterDataSlot(id: slot, dataURL: nil))
            }
        }
        return ReturnMe
    }

    func loadSourceFromDiscordTeam() {
        sourceCharacters = pad(
            cdsArray: Benchmark.findAvailableDiscordTeamCharacters().sorted(
                by: { $0.id < $1.id }),
            toSize: 0)
    }

    func loadTargetFromDemo() {
        targetCharacters = pad(
            cdsArray: Benchmark.findAvailableDemoCharacters().sorted(by: {
                $0.id < $1.id
            }),
            toSize: 40)
    }

    func loadSourceFromRetail() {
        sourceCharacters = pad(
            cdsArray: Benchmark.findAvailableRetailCharacters().sorted(by: {
                $0.id < $1.id
            }),
            toSize: 0)
    }
}

struct CharacterDataImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = CharacterListState()
    @State private var targetSelection: Int?
    @State private var sourceSelection: Int?
    @State private var discordCrew = false
    @State private var confirmingDelete = false
    @State private var notice: AppNotice?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ToolHeader(
                title: "BENCHMARK_IMPORT_CHARACTER_BUTTON",
                subtitle: "Bring a familiar face on your next adventure.",
                symbol: "person.crop.rectangle.stack")
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("BENCHMARK_SLOTS_LIST_LABEL").font(.headline)
                    CharacterDataListView(
                        characterData: $state.targetCharacters,
                        selection: $targetSelection)
                    HStack {
                        Button(
                            "BENCHMARK_SLOT_DELETE_BUTTON", role: .destructive
                        ) { confirmingDelete = true }
                        .disabled(selectedTarget?.path == nil)
                        if Benchmark.benchmarkVersion() == .dawntrail {
                            Button("BENCHMARK_SLOT_EXPORT_BUTTON") {
                                if let character = selectedTarget {
                                    Benchmark.exportCharacterData(
                                        character: character)
                                    state.loadSourceFromRetail()
                                    discordCrew = false
                                    targetSelection = nil
                                }
                            }.disabled(selectedTarget?.path == nil)
                        }
                    }
                }.padding(18).xomGlass(radius: 18)
                VStack(alignment: .leading, spacing: 12) {
                    Text("AVAILABLE_SLOTS_LIST_LABEL").font(.headline)
                    CharacterDataListView(
                        characterData: $state.sourceCharacters,
                        selection: $sourceSelection)
                    Button("BENCHMARK_SLOT_IMPORT_BUTTON") {
                        if let character = state.sourceCharacters.first(where: {
                            $0.id == sourceSelection
                        }) {
                            Benchmark.importCharacterData(character: character)
                            state.loadTargetFromDemo()
                            sourceSelection = nil
                        }
                    }.disabled(
                        state.sourceCharacters.first(where: {
                            $0.id == sourceSelection
                        })?.path == nil)
                }.padding(18).xomGlass(radius: 18)
            }
            if discordCrew {
                Text("BENCHMARK_DISCORD_BLURB").font(.caption).foregroundStyle(
                    .secondary)
            }
            HStack {
                KwehView(chocoWalkUnits: 5, chocoFence: 70).frame(
                    width: 160, height: 48
                ).clipped()
                    .onTapGesture {
                        discordCrew = true
                        state.loadSourceFromDiscordTeam()
                        sourceSelection = nil
                    }.accessibilityLabel("Chocobo").accessibilityHint(
                        "Show the XIV on Mac team’s characters")
                Spacer()
                Button("BUTTON_DONE") { dismiss() }.xomPrimaryButton()
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).notice($notice)
        .onAppear {
            #if DEBUG
                if Util.isPreview {
                    state.targetCharacters = state.pad(cdsArray: [], toSize: 40)
                    state.sourceCharacters = [PreviewContent.character]
                    return
                }
            #endif
            state.loadTargetFromDemo()
            state.loadSourceFromRetail()
        }
        .confirmationDialog(
            "BENCHMARK_CONFIRM_SLOT_DELETE", isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("BUTTON_DELETE", role: .destructive) {
                do {
                    if let path = selectedTarget?.path {
                        try FileManager.default.removeItem(at: path)
                    }
                    state.loadTargetFromDemo()
                    targetSelection = nil
                } catch {
                    notice = AppNotice(
                        "BENCHMARK_TITLE", error.localizedDescription)
                }
            }
            Button("BUTTON_CANCEL", role: .cancel) {}
        } message: {
            Text("BENCHMARK_CONFIRM_SLOT_DELETE_INFORMATIVE")
        }
    }

    private var selectedTarget: CharacterDataSlot? {
        state.targetCharacters.first { $0.id == targetSelection }
    }
}
