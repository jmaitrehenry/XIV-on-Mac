//
//  SettingsGraphicsTabView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 1/14/23.
//

import SwiftUI

struct SettingsGraphicsTabView: View {
    @StateObject private var viewModel = ViewModel()
    @State private var confirmRetina = false
    var body: some View {
        VStack(spacing: 18) {
            SettingsSection(
                title: "Performance", symbol: "gauge.with.dots.needle.67percent"
            ) {
                Toggle(
                    "SETTINGS_GRAPHICS_METAL3_HUD", isOn: $viewModel.metal3Hud)
                Toggle(
                    "METALFX_SPATIAL_ENABLED",
                    isOn: $viewModel.metalFxSpatialEnabled)
                HStack {
                    Toggle("SETTINGS_FPS_LIMIT", isOn: $viewModel.fpsLimited)
                    Spacer()
                    TextField(
                        "SETTINGS_FPS_LIMIT_PLACEHOLDER",
                        text: $viewModel.fpsLimit
                    )
                    .frame(width: 70).disabled(!viewModel.fpsLimited)
                    Text("SETTINGS_FPS_LIMIT_UNITS").foregroundStyle(.secondary)
                }
            }
            SettingsSection(title: "Display", symbol: "display") {
                Toggle(
                    "SETTINGS_GRAPHICS_RETINA",
                    isOn: Binding(
                        get: { viewModel.macScaling },
                        set: { enabled in
                            if enabled {
                                viewModel.macScaling = true
                            } else {
                                confirmRetina = true
                            }
                        }))
                if let illustration = NSImage(named: "PrefsGraphics") {
                    Image(nsImage: illustration).resizable().scaledToFit()
                        .frame(height: 130)
                        .frame(maxWidth: .infinity).accessibilityHidden(true)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .alert("RETINA_WARNING", isPresented: $confirmRetina) {
            Button("RETINA_ENABLE_BUTTON") { viewModel.macScaling = false }
            Button("BUTTON_CANCEL", role: .cancel) {}
        } message: {
            Text("RETINA_WARNING_INFORMATIVE")
        }
    }
}

#if DEBUG
    #Preview("Graphics") {
        ScrollView {
            SettingsGraphicsTabView().padding(28)
        }
        .frame(width: 755, height: 640)
        .tint(XOMStyle.accent)
    }
#endif

extension SettingsGraphicsTabView {
    @MainActor class ViewModel: ObservableObject {
        @Published var metalFxSpatialEnabled: Bool = Settings
            .metalFxSpatialEnabled
        {
            didSet { Settings.metalFxSpatialEnabled = metalFxSpatialEnabled }
        }

        @Published var fpsLimited: Bool = Settings.maxFramerate != 0 {
            didSet { updateFpsLimit() }
        }

        @Published var fpsLimit: String = String(Settings.maxFramerate) {
            didSet { updateFpsLimit() }
        }

        @Published var metal3Hud: Bool = Settings.metal3PerformanceOverlay {
            didSet { Settings.metal3PerformanceOverlay = metal3Hud }
        }

        @Published var macScaling: Bool = !Wine.retina {
            didSet { Wine.retina = !macScaling }
        }

        private func updateFpsLimit() {
            Settings.maxFramerate = fpsLimited ? UInt32(fpsLimit) ?? 0 : 0
        }
    }
}
