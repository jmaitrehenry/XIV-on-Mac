//
//  FirstAidWindowContent.swift
//  XIV on Mac
//
//  Created by Chris Backas on 1/18/23.
//

import SwiftUI

struct FirstAidView: View {
    @StateObject private var model = FirstAidModel()
    @State private var notice: AppNotice?
    @State private var confirmPrefix = false
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(
                    title: "FIRSTAID_CONFIG_HEADING", symbol: "checkmark.shield"
                ) {
                    Text("FIRSTAID_CHECKUP_BLURB").foregroundStyle(.secondary)
                    HStack {
                        Label(
                            resultTitle,
                            systemImage: model.cfgCheckOverallResult == .problem
                                ? "exclamationmark.triangle.fill"
                                : "checkmark.shield.fill"
                        )
                        .foregroundStyle(
                            model.cfgCheckOverallResult == .problem
                                ? .orange : .green)
                        Spacer()
                        Button("FIRSTAID_CHECKUP_BUTTON") { model.reloadCfg() }
                    }
                    ForEach(model.cfgProblems) { problem in
                        Divider()
                        HStack(alignment: .top, spacing: 14) {
                            Image(
                                systemName: problem.fixed
                                    ? "checkmark.circle.fill"
                                    : "exclamationmark.circle"
                            )
                            .font(.title3).foregroundStyle(
                                problem.fixed ? .green : .orange)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(problem.title).font(.headline)
                                if problem.fixed {
                                    Text("FIRSTAID_CFGCHECK_FIXED")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(problem.explanation).font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            if !problem.fixed {
                                Button("FIRSTAID_CFGCHECK_FIX_BUTTON") {
                                    guard checkIfNotRunning() else { return }
                                    model.fix(condition: problem)
                                }
                            }
                        }
                    }
                }
                SettingsSection(
                    title: "FIRSTAID_SHADER_CACHE_HEADING",
                    symbol: "sparkles.rectangle.stack"
                ) {
                    Text("FIRSTAID_SHADER_CACHE_BLURB").foregroundStyle(
                        .secondary)
                    Button("FIRSTAID_SHADER_CACHE_BUTTON") {
                        perform(
                            success: "DXMT_USER_CACHE_DELETED",
                            successInfo: "DXMT_USER_CACHE_DELETED_INFORMATIVE",
                            failure: "DXMT_USER_CACHE_DELETE_FAILED",
                            operation: Dxmt.resetCache)
                    }
                }
                SettingsSection(
                    title: "FIRSTAID_CONFIG_HEADING",
                    symbol: "slider.horizontal.3"
                ) {
                    Text("FIRSTAID_RESET_CONFIG_BLURB").foregroundStyle(
                        .secondary)
                    Button("FIRSTAID_RESET_CONFIG_BUTTON") {
                        perform(
                            success: "GAME_CONFIG_RESET",
                            successInfo: "GAME_CONFIG_RESET_INFORMATIVE",
                            failure: "GAME_CONFIG_RESET_FAILED",
                            operation: FFXIVApp.resetConfiguration)
                    }
                }
                SettingsSection(
                    title: "FIRSTAID_PREFIX_HEADING", symbol: "externaldrive"
                ) {
                    Text("FIRSTAID_PREFIX_BLURB").foregroundStyle(.secondary)
                    Button("FIRSTAID_PREFIX_BUTTON", role: .destructive) {
                        if checkIfNotRunning() { confirmPrefix = true }
                    }
                }
                if working { ProgressView().frame(maxWidth: .infinity) }
            }.padding(28).disabled(working)
        }
        .frame(minWidth: 700, minHeight: 590)
        .modifier(AppWindowBackground()).notice($notice)
        .confirmationDialog(
            "FIRSTAID_PREFIX_CONFIRM", isPresented: $confirmPrefix,
            titleVisibility: .visible
        ) {
            Button("BUTTON_DELETE", role: .destructive) {
                perform(
                    success: "FIRSTAID_PREFIX_DELETED",
                    successInfo: "FIRSTAID_PREFIX_DELETED_INFORMATIVE",
                    failure: "FIRSTAID_PREFIX_DELETE_FAILED",
                    operation: Wine.deletePrefix)
            }
            Button("BUTTON_CANCEL", role: .cancel) {}
        } message: {
            Text("FIRSTAID_PREFIX_CONFIRM_INFORMATIVE")
        }
    }

    private var resultTitle: LocalizedStringKey {
        switch model.cfgCheckOverallResult {
        case .noissue: "FIRSTAID_CFGCHECK_GOOD_RESULT"
        case .advisory: "FIRSTAID_CFGCHECK_ADVISORY_RESULT"
        case .recommendation: "FIRSTAID_CFGCHECK_RECOMMENDATION_RESULT"
        case .problem: "FIRSTAID_CFGCHECK_PROBLEM_RESULT"
        }
    }

    private func checkIfNotRunning() -> Bool {
        // Since we're deleting or otherwise mucking with files the game may be using or may re-write,
        // we generally want no copies running.
        if Wine.running(processName: "ffxiv_dx11.exe") {
            notice = AppNotice("FIRSTAID_GAME_RUNNING", "FIRSTAID_GAME_RUNNING")
            return false
        }
        return true
    }

    private func perform(
        success: String, successInfo: String, failure: String,
        operation: @escaping () throws -> Void
    ) {
        guard checkIfNotRunning() else { return }
        working = true
        Task {
            do {
                try await backgroundWork(operation)
                model.reloadCfg()
                notice = AppNotice(success, successInfo)
            } catch {
                Log.error(error.localizedDescription)
                notice = AppNotice(failure, error.localizedDescription)
            }
            working = false
        }
    }
}

#if DEBUG
    #Preview("First Aid") {
        FirstAidView().frame(width: 780, height: 780).tint(XOMStyle.accent)
    }
#endif
