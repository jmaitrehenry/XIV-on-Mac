//
//  SettingsCaptureView.swift
//  XIV on Mac
//
//  Created by Chris Backas on 3/19/23.
//

import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsCaptureView: View {
    @AppStorage(ScreenCaptureHelper.captureFolderPref) private
        var captureFolder =
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        .path
    @AppStorage(ScreenCaptureHelper.videoCodecPref) private var codecType:
        ScreenCaptureCodec = .h264
    @State private var choosingFolder = false
    @State private var checking = false
    @State private var permissionMessage: String?
    @State private var permissionURL: URL?
    @State private var notice: AppNotice?

    var body: some View {
        VStack(spacing: 18) {
            SettingsSection(title: "Permissions", symbol: "lock.shield") {
                Text("SETTINGS_CAPTURE_PERMISSIONS_CHECK").foregroundStyle(
                    .secondary)
                HStack {
                    Button("SETTINGS_CAPTURE_PERMISSIONS_CHECK_BUTTON") {
                        checkPermissions()
                    }.disabled(
                        checking)
                    if checking { ProgressView().controlSize(.small) }
                }
                if let message = permissionMessage {
                    Text(message).font(.callout)
                    if let url = permissionURL {
                        Link(
                            "SCREEN_CAPTURE_PERMISSION_OPEN_PREF_BUTTON",
                            destination: url)
                    }
                }
            }
            SettingsSection(title: "Recording", symbol: "record.circle") {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CAPTURE_FOLDER_LABEL")
                        Text(captureFolder).font(.caption).foregroundStyle(
                            .secondary
                        )
                        .lineLimit(2).truncationMode(.middle).textSelection(
                            .enabled)
                    }
                    Spacer()
                    Button("CAPTURE_FOLDER_SELECT_BUTTON") {
                        choosingFolder = true
                    }
                }
                KeyboardShortcuts.Recorder(
                    NSLocalizedString(
                        "SETTINGS_TOGGLE_SCREEN_RECORDING", comment: ""),
                    name: .toggleVideoCapture)
                Picker("SETTINGS_CAPTURE_CODEC", selection: $codecType) {
                    Text("SETTINGS_CAPTURE_CODEC_H264").tag(
                        ScreenCaptureCodec.h264)
                    Text("SETTINGS_CAPTURE_CODEC_HEVC").tag(
                        ScreenCaptureCodec.hevc)
                }
            }
        }
        .notice($notice)
        .fileImporter(
            isPresented: $choosingFolder, allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url): captureFolder = url.path
            case .failure(let error):
                notice = AppNotice(
                    "CAPTURE_FOLDER_LABEL", error.localizedDescription)
            }
        }
    }

    private func checkPermissions() {
        checking = true
        Task {
            let record = await ScreenCapture.hasRecordPermission()
            let notifications =
                await UNUserNotificationCenter.current().notificationSettings()
                .authorizationStatus
                == .authorized
            let key =
                !record && !notifications
                ? "SCREEN_CAPTURE_PERMISSION_HAVE_NONE"
                : !record
                    ? "SCREEN_CAPTURE_PERMISSION_NO_RECORD"
                    : !notifications
                        ? "SCREEN_CAPTURE_PERMISSION_NO_NOTIFY"
                        : "SCREEN_CAPTURE_PERMISSION_HAVE_ALL"
            permissionMessage = NSLocalizedString(key, comment: "")
            permissionURL =
                record && notifications
                ? nil
                : URL(
                    string: !record
                        ? "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                        : "x-apple.systempreferences:com.apple.preference")
            checking = false
        }
    }
}

#if DEBUG
    #Preview("Capture") {
        ScrollView {
            SettingsCaptureView().padding(28)
        }
        .frame(width: 755, height: 640)
        .tint(XOMStyle.accent)
    }
#endif
