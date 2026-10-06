//
//  SettingsWindow.swift
//  XIV on Mac
//
//  Created by Chris Backas on 1/14/23.
//

import SwiftUI

struct SettingsView: View {
    @State private var selected: SettingsPage = .general

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(SettingsPage.allCases) { page in
                    Button {
                        selected = page
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: page.symbol).frame(width: 20)
                            Text(page.title).fontWeight(
                                selected == page ? .semibold : .regular)
                            Spacer()
                        }
                        .padding(12).contentShape(Rectangle())
                        .background(
                            selected == page
                                ? XOMStyle.accent.opacity(0.14) : .clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(
                            selected == page ? XOMStyle.accent : .primary)
                    }.buttonStyle(.plain).accessibilityAddTraits(
                        selected == page ? .isSelected : [])
                }
                Spacer()
                Text("XIV ON MAC").font(.system(size: 9, weight: .bold))
                    .tracking(2).foregroundStyle(
                        .tertiary
                    ).padding(12)
            }
            .padding(18).frame(width: 205).frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Group {
                        switch selected {
                        case .general: SettingsGeneralTabView()
                        case .graphics: SettingsGraphicsTabView()
                        case .plugins: SettingsPluginsTabView()
                        case .capture: SettingsCaptureView()
                        case .advanced: SettingsAdvancedTabView()
                        }
                    }
                }.padding(28)
            }
        }
        .frame(minWidth: 900, idealWidth: 960, minHeight: 640, idealHeight: 720)
        .navigationTitle("SETTINGS_WINDOW_TITLE")
        .modifier(AppWindowBackground()).tint(XOMStyle.accent)
    }
}

#if DEBUG
    #Preview("Settings") {
        SettingsView().frame(width: 960, height: 720)
    }
#endif

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general, graphics, plugins, capture, advanced
    var id: Self { self }
    var title: LocalizedStringKey {
        switch self {
        case .general: "SETTINGS_TAB_GENERAL_TITLE"
        case .graphics: "SETTINGS_TAB_GRAPHICS_TITLE"
        case .plugins: "SETTINGS_TAB_PLUGINS_TITLE"
        case .capture: "SETTINGS_TAB_CAPTURE_TITLE"
        case .advanced: "SETTINGS_TAB_ADVANCED_TITLE"
        }
    }
    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .graphics: "display"
        case .plugins: "puzzlepiece.extension"
        case .capture: "record.circle"
        case .advanced: "gearshape.2"
        }
    }
}
