//
//  SettingsGeneralTabView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 1/14/23.
//

import SeeURL
import SwiftUI

struct SettingsGeneralTabView: View {
    @StateObject private var viewModel = ViewModel()
    var body: some View {
        VStack(spacing: 18) {
            SettingsSection(
                title: "SETTINGS_GENERAL_TITLE_LICENSE",
                symbol: "person.text.rectangle"
            ) {
                Text("SETTINGS_GENERAL_LANGUAGE_AND_LICENSE_BLURB")
                    .foregroundStyle(.secondary)
                Picker(
                    "SETTINGS_LANGUAGE_PICKER", selection: $viewModel.language
                ) {
                    Text("SETTINGS_LANGUAGE_JAPANESE").tag(
                        FFXIVLanguage.japanese)
                    Text("SETTINGS_LANGUAGE_ENGLISH").tag(FFXIVLanguage.english)
                    Text("SETTINGS_LANGUAGE_FRENCH").tag(FFXIVLanguage.french)
                    Text("SETTINGS_LANGUAGE_GERMAN").tag(FFXIVLanguage.german)
                }
                Picker(
                    "SETTINGS_PLATFORM_PICKER", selection: $viewModel.platform
                ) {
                    Text("SETTINGS_PLATFORM_MAC").tag(FFXIVPlatform.mac)
                    Text("SETTINGS_PLATFORM_WINDOWS").tag(FFXIVPlatform.windows)
                    Text("SETTINGS_PLATFORM_STEAM").tag(FFXIVPlatform.steam)
                }
                Toggle("SETTINGS_FREE_TRIAL", isOn: $viewModel.freeTrial)
                Text("SETTINGS_GENERAL_FREE_TRIAL_BLURB").font(.caption)
                    .foregroundStyle(.secondary)
            }
            SettingsSection(
                title: "SETTINGS_GENERAL_TITLE_NETWORK", symbol: "network"
            ) {
                HStack {
                    Toggle(
                        "SETTINGS_DOWNLOAD_LIMIT",
                        isOn: $viewModel.limitDownloadEnabled)
                    Spacer()
                    TextField(
                        "SETTINGS_DOWNLOAD_LIMIT_PLACEHOLDER",
                        text: $viewModel.limitDownloadSpeed
                    )
                    .frame(width: 75).disabled(!viewModel.limitDownloadEnabled)
                    Text("SETTINGS_DOWNLOAD_LIMIT_UNITS").foregroundStyle(
                        .secondary)
                }
            }
            SettingsSection(
                title: "SETTINGS_GENERAL_TITLE_INPUT", symbol: "keyboard"
            ) {
                HStack {
                    Picker(
                        "SETTINGS_GENERAL_INPUT_LEFT_OPTION",
                        selection: $viewModel.leftOptionIsAlt
                    ) {
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_WINDOWS_ALT").tag(
                            true)
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_MACOS_OPTION").tag(
                            false)
                    }
                    Picker(
                        "SETTINGS_GENERAL_INPUT_RIGHT_OPTION",
                        selection: $viewModel.rightOptionIsAlt
                    ) {
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_WINDOWS_ALT").tag(
                            true)
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_MACOS_OPTION").tag(
                            false)
                    }
                }
                HStack {
                    Picker(
                        "SETTINGS_GENERAL_INPUT_LEFT_COMMAND",
                        selection: $viewModel.leftCommandIsCtrl
                    ) {
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_CTRL").tag(true)
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_ALT").tag(false)
                    }
                    Picker(
                        "SETTINGS_GENERAL_INPUT_RIGHT_COMMAND",
                        selection: $viewModel.rightCommandIsCtrl
                    ) {
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_CTRL").tag(true)
                        Text("SETTINGS_GENERAL_INPUT_BUTTON_ALT").tag(false)
                    }
                }
            }
        }.textFieldStyle(.roundedBorder)
    }
}

#if DEBUG
    #Preview("General") {
        ScrollView {
            SettingsGeneralTabView().padding(28)
        }
        .frame(width: 755, height: 640)
        .tint(XOMStyle.accent)
    }
#endif

extension SettingsGeneralTabView {
    @MainActor class ViewModel: ObservableObject {
        @Published var language: FFXIVLanguage = Settings.language {
            didSet { Settings.language = language }
        }

        @Published var platform: FFXIVPlatform = Settings.platform {
            didSet { Settings.platform = platform }
        }

        @Published var freeTrial: Bool = Settings.freeTrial {
            didSet { Settings.freeTrial = freeTrial }
        }

        @Published var limitDownloadEnabled: Bool = HTTPClient.maxSpeed > 0 {
            didSet { updateHTTPMaxSpeed() }
        }

        @Published var limitDownloadSpeed: String = .init(HTTPClient.maxSpeed) {
            didSet { updateHTTPMaxSpeed() }
        }

        @Published var leftOptionIsAlt: Bool = Wine.leftOptionIsAlt {
            didSet { Wine.leftOptionIsAlt = leftOptionIsAlt }
        }

        @Published var rightOptionIsAlt: Bool = Wine.rightOptionIsAlt {
            didSet { Wine.rightOptionIsAlt = rightOptionIsAlt }
        }

        @Published var leftCommandIsCtrl: Bool = Wine.leftCommandIsCtrl {
            didSet { Wine.leftCommandIsCtrl = leftCommandIsCtrl }
        }

        @Published var rightCommandIsCtrl: Bool = Wine.rightCommandIsCtrl {
            didSet { Wine.rightCommandIsCtrl = rightCommandIsCtrl }
        }

        private func updateHTTPMaxSpeed() {
            HTTPClient.maxSpeed =
                limitDownloadEnabled ? Double(limitDownloadSpeed) ?? 0.0 : 0.0
        }
    }
}
