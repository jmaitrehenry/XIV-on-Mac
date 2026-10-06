//
//  RepairController.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 27.05.22.
//

import Foundation
import SwiftUI
import XIVLauncher

private struct RepairProgress: Decodable {
    let currentStep, currentFile: String
    let total, progress, speed: Int64
    enum CodingKeys: String, CodingKey {
        case currentStep = "CurrentStep"
        case currentFile = "CurrentFile"
        case total = "Total"
        case progress = "Progress"
        case speed = "Speed"
    }

    static func read() -> RepairProgress? {
        guard let pointer = queryRepairProgress() else { return nil }
        defer { free(UnsafeMutableRawPointer(mutating: pointer)) }
        return try? JSONDecoder().decode(
            Self.self, from: Data(String(cString: pointer).utf8))
    }
}

#if DEBUG
    extension RepairController {
        static var preview: RepairController {
            let model = RepairController()
            model.status = String(localized: "Checking game files…")
            model.file = "game/sqpack/ffxiv/000000.win32.dat0"
            model.progress = 0.45
            return model
        }
    }

    #Preview("Repair progress") {
        RepairProgressView(model: .preview).padding(24).frame(width: 304)
            .tint(XOMStyle.accent)
    }
#endif

@MainActor
final class RepairController: ObservableObject {
    @Published private(set) var status = ""
    @Published private(set) var file = ""
    @Published private(set) var progress = 0.0

    func repair(_ result: LoginResult) async -> String {
        status = String(localized: "Checking game files…")
        file = ""
        progress = 0
        let polling = Task {
            while !Task.isCancelled {
                if let update = try? await backgroundWork({
                    RepairProgress.read()
                }) {
                    guard !Task.isCancelled else { break }
                    let step = NSLocalizedString(
                        update.currentStep, comment: "")
                    status = String(
                        localized:
                            "\(step) · \(ByteCountFormatter.string(fromByteCount: update.speed, countStyle: .file))/s"
                    )
                    file = update.currentFile
                    progress =
                        update.total > 0
                        ? min(
                            1,
                            max(
                                0,
                                Double(update.progress) / Double(update.total)))
                        : 0
                }
                do { try await Task.sleep(nanoseconds: 250_000_000) } catch {
                    break
                }
            }
        }
        let resultMessage =
            (try? await backgroundWork {
                Wine.kill()
                return result.repairGame()
            }) ?? String(localized: "Repair could not be completed.")
        polling.cancel()
        await polling.value
        return localizedRepairResult(resultMessage)
    }

    private func localizedRepairResult(_ message: String) -> String {
        let scanner = Scanner(string: message)
        if scanner.scanString("XIV on Mac has successfully repaired") != nil,
            let count = scanner.scanInt(),
            let suffix = scanner.scanUpToCharacters(from: .newlines),
            ["game file.", "game files."].contains(suffix), scanner.isAtEnd
        {
            return String(localized: "Game files repaired: \(count)")
        }
        return NSLocalizedString(message, comment: "")
    }
}

struct RepairProgressView: View {
    @ObservedObject var model: RepairController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: model.progress)
            Text(model.status).font(.callout)
            Text(model.file).font(.caption).foregroundStyle(.secondary)
                .lineLimit(2).truncationMode(
                    .middle)
        }
    }
}
