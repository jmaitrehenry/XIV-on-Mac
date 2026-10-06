//
//  PatchPipeline.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 29.09.26.
//

import Foundation

enum PatchPipeline {
    private final class Failure: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Error?

        func record(_ error: Error) {
            lock.lock()
            defer { lock.unlock() }
            if value == nil { value = error }
        }

        func check() throws {
            lock.lock()
            defer { lock.unlock() }
            if let value { throw value }
        }
    }

    static func run<Item>(
        _ items: [Item],
        download: (Item, Int) throws -> Void,
        install: @escaping (Item, Int) throws -> Void
    ) throws {
        let queue = DispatchQueue(label: "xiv.patch.install", qos: .utility)
        let group = DispatchGroup()
        let failure = Failure()
        for (index, item) in items.enumerated() {
            do {
                try failure.check()
                try download(item, index)
                group.enter()
                queue.async {
                    defer { group.leave() }
                    do {
                        try failure.check()
                        try install(item, index)
                    } catch { failure.record(error) }
                }
            } catch {
                failure.record(error)
                break
            }
        }
        // Drain in-flight installs before allowing a retry.
        group.wait()
        try failure.check()
    }
}
