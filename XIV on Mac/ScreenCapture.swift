//
//  ScreenCapture.swift
//  XIV on Mac
//
//  Created by Chris Backas on 3/9/23.
//

import Foundation
import OSLog
import ScreenCaptureKit
@preconcurrency import UserNotifications

public enum ScreenCaptureCodec: Int {
    case h264 = 0
    case hevc = 1
}

enum ScreenCaptureHelper {
    public static let captureFolderPref: String = "ScreenCaptureDirectory"
    public static let videoCodecPref: String = "ScreenCaptureCodec"

}

class ScreenCapture: @unchecked Sendable {
    private let screenCaptureEngine = ScreenCaptureEngine()
    private let avWriter: AVWriter = AVWriter()
    private var isRecording: Bool = false {
        didSet {
            Task {
                await self.sendScreenCaptureStatusNotification()
            }
        }
    }

    @MainActor func sendScreenCaptureStatusNotification() {
        ScreenCapture.sendScreenCaptureStatusNotification(
            isRecording: self.isRecording, avWriter: self.avWriter)
    }

    @MainActor static func sendScreenCaptureStatusNotification(
        isRecording: Bool, avWriter: AVWriter
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            if isRecording {
                content.title = NSLocalizedString(
                    "NOTIFY_CAPTURE_TITLE", comment: "")
                content.subtitle = NSLocalizedString(
                    "NOTIFY_CAPTURE_STARTED_SUBTITLE", comment: "")
                content.body = String(
                    format: NSLocalizedString(
                        "NOTIFY_CAPTURE_STARTED_BODY", comment: ""),
                    "\(avWriter.currentRecordingURL?.lastPathComponent ?? "")"
                )
            } else {
                content.title = NSLocalizedString(
                    "NOTIFY_CAPTURE_TITLE", comment: "")
                content.subtitle = NSLocalizedString(
                    "NOTIFY_CAPTURE_STOPPED_SUBTITLE", comment: "")
                content.body = String(
                    format: NSLocalizedString(
                        "NOTIFY_CAPTURE_STOPPED_BODY", comment: ""),
                    "\(avWriter.currentRecordingURL?.lastPathComponent ?? "")"
                )
            }
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "com.marzent.XIVOnMac.ScreenCapture",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func hasRecordPermission() async -> Bool {
        do {
            // If the app doesn't have Screen Recording permission, this call generates an exception.
            try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)

            return true
        } catch {
            Log.error("FFXIV Screencapture: No screen recording permissions")
            return false
        }
    }

    var canRecord: Bool {
        get async {
            if await !ScreenCapture.hasRecordPermission() {
                Log.error("FFXIV Screencapture: Can't capture, no permission!")
                return false
            }

            // We're single-purpose here :D
            if !FFXIVApp.running {
                Log.error(
                    "FFXIV Screencapture: Game is not running, nothing to capture."
                )
                return false
            }

            return true
        }
    }

    func toggleScreenCapture() {
        if isRecording {
            stopCapture()
        } else {
            startCapture()
        }
    }

    func startCapture() {
        Task {
            if await canRecord {
                await doStartCapture()
            }
        }
    }

    func stopCapture() {
        Task {
            await screenCaptureEngine.stopCapture()
            await MainActor.run {
                isRecording = false
            }
        }
    }

    private func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        let gameUnixPids = Wine.pidsOf(processName: "ffxiv_dx11.exe").map {
            Wine.convertToUnixPidFrom(winePid: $0)
        }
        return
            windows
            .filter {
                gameUnixPids.contains($0.owningApplication?.processID ?? -1)
            }
            .sorted {
                $0.owningApplication?.processID ?? 0 < $1.owningApplication?
                    .processID ?? 0
            }
    }

    private func refreshAvailableContent() async -> SCWindow? {
        do {
            // Retrieve the available screen content to capture.
            let availableContent =
                try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true)
            let windows = filterWindows(availableContent.windows)

            return windows.first

        } catch {
            Log.error(
                "FFXIV Screencapture: Failed to get the shareable content: \(error.localizedDescription)"
            )
        }
        return nil
    }

    private func streamConfiguration(forWindow: SCWindow)
        -> SCStreamConfiguration
    {
        let streamConfig = SCStreamConfiguration()

        // Configure audio capture.
        streamConfig.capturesAudio = true
        streamConfig.excludesCurrentProcessAudio = true
        streamConfig.showsCursor = false  // Hide mouse

        // Configure the window content width and height.
        streamConfig.width = Int(forWindow.frame.width) * 2
        streamConfig.height = Int(forWindow.frame.height) * 2

        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        streamConfig.queueDepth = 5

        return streamConfig
    }

    func doStartCapture() async {
        guard let window: SCWindow = await refreshAvailableContent() else {
            Log.error("FFXIV Screencapture: No game windows found to capture")
            return
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        screenCaptureEngine.avWriter = self.avWriter
        screenCaptureEngine.startCapture(
            configuration: streamConfiguration(forWindow: window),
            filter: filter)
        await MainActor.run {
            isRecording = true
        }
    }

}
