//
//  PatchController.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 26.02.22.
//

import Foundation
import OrderedCollections
import SeeURL
import SwiftUI

@MainActor
final class PatchController: ObservableObject {
    @Published private(set) var downloadName = ""
    @Published private(set) var installName = ""
    @Published private(set) var downloadProgress = 0.0
    @Published private(set) var fileProgress = 0.0
    @Published private(set) var installed = 0
    @Published private(set) var count = 0
    @Published private(set) var transfer = ""

    func install(_ patches: [Patch]) async throws {
        guard !patches.isEmpty else { return }
        count = patches.count
        installed = 0
        downloadProgress = 0
        fileProgress = 0
        downloadName = ""
        installName = NSLocalizedString(
            "PATCH_INSTALLATION_WAITING", comment: "")
        transfer = ""
        try await backgroundWork {
            try PatchDownloadService.install(
                patches,
                download: { name, overall, file, transfer in
                    DispatchQueue.main.async {
                        self.downloadName = name
                        self.downloadProgress = overall
                        self.fileProgress = file
                        self.transfer = transfer
                    }
                },
                installation: { name, completed in
                    DispatchQueue.main.async {
                        self.installName = name
                        self.installed = completed
                    }
                })
        }
    }
}

#if DEBUG
    extension PatchController {
        static var preview: PatchController {
            let model = PatchController()
            model.downloadName = "D2026.09.01.0000.0000.patch"
            model.installName = "D2026.08.25.0000.0000.patch"
            model.downloadProgress = 0.62
            model.fileProgress = 0.38
            model.installed = 2
            model.count = 5
            model.transfer = "1.6 GB / 4.2 GB · 18 MB/s"
            return model
        }
    }

    #Preview("Patch progress") {
        PatchProgressView(model: .preview).padding(24).frame(width: 304)
            .tint(XOMStyle.accent)
    }
#endif

private enum PatchDownloadService {
    static func install(
        _ patches: [Patch],
        download: @escaping (String, Double, Double, String) -> Void,
        installation: @escaping (String, Int) -> Void
    ) throws {
        let total = Patch.totalLength(patches)
        var completed: Int64 = 0
        try PatchPipeline.run(
            patches,
            download: { patch, _ in
                let previous = completed
                try fetch(patch) { size, now, speed in
                    let transfer = String(
                        localized:
                            "\(ByteCountFormatter.string(fromByteCount: previous + now, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)) · \(ByteCountFormatter.string(fromByteCount: speed, countStyle: .file))/s"
                    )
                    download(
                        patch.name, fraction(previous + now, total),
                        fraction(now, size), transfer)
                }
                completed += patch.length
                download(
                    patch.name, fraction(completed, total), 1,
                    String(
                        localized:
                            "\(ByteCountFormatter.string(fromByteCount: completed, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
                    )
                )
            },
            install: { patch, index in
                installation(patch.name, index)
                try patch.install()
                installation(patch.name, index + 1)
            })
        FFXIVRepo.verToBck()
    }

    static func fraction(_ value: Int64, _ total: Int64) -> Double {
        total > 0 ? min(1, max(0, Double(value) / Double(total))) : 0
    }

    private static func fetch(
        _ patch: Patch, progress: @escaping (Int64, Int64, Int64) -> Void
    )
        throws
    {
        let headers: OrderedDictionary = [
            "User-Agent": Patch.userAgent,
            "Accept-Encoding":
                "*/*,application/metalink4+xml,application/metalink+xml",
            "Host": "patch-dl.ffxiv.com",
            "Connection": "Keep-Alive",
            "Want-Digest": "SHA-512;q=1, SHA-256;q=1, SHA;q=0.1",
        ]
        for attempt in 0...3 {
            do {
                try HTTPClient.fetchFile(
                    url: patch.url,
                    destinationUrl: Patch.dir.appendingPathComponent(
                        patch.path),
                    headers: headers, progressCallback: progress)
                return
            } catch {
                if attempt == 3 { throw error }
            }
        }
    }
}

struct PatchProgressView: View {
    @ObservedObject var model: PatchController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Downloading", systemImage: "arrow.down.circle").font(
                .headline)
            ProgressView(value: model.downloadProgress)
            Text(model.transfer).font(.caption).monospacedDigit()
                .foregroundStyle(.secondary)
            Text(model.downloadName).font(.caption).lineLimit(1).truncationMode(
                .middle)
            ProgressView(value: model.fileProgress)
            Divider()
            Label("Installing", systemImage: "shippingbox").font(.headline)
            ProgressView(
                value: Double(model.installed),
                total: Double(max(1, model.count))
            ).tint(XOMStyle.cyan)
            Text("\(model.installed) / \(model.count)").font(.caption)
                .monospacedDigit()
            Text(model.installName).font(.caption).lineLimit(1).truncationMode(
                .middle
            ).foregroundStyle(
                .secondary)
        }
    }
}
