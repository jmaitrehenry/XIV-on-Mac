//
//  LauncherContent.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 29.09.26.
//

import Foundation

struct FrontierHeadlines: Codable {
    struct News: Codable {
        let date: String
        let title: String
        let url: String
        let id: String
        let tag: String?

        var publishedAt: Date? {
            try? Date(date, strategy: .iso8601)
        }

        func destination(languageCode: String) -> URL? {
            if let supplied = URL(string: url),
                ["https", "http"].contains(supplied.scheme?.lowercased() ?? ""),
                supplied.host != nil
            {
                return supplied
            }
            // News and pinned entries can supply an ID with an empty URL.
            guard !id.isEmpty else { return nil }
            return FrontierHeadlines.lodestoneURL(languageCode: languageCode)
                .appendingPathComponent("news/detail")
                .appendingPathComponent(id)
        }
    }

    let news, topics, pinned: [News]

    static func lodestoneURL(languageCode: String) -> URL {
        let region: String
        switch languageCode {
        case "ja": region = "jp"
        case "de": region = "de"
        case "fr": region = "fr"
        case "en-us": region = "na"
        default: region = "eu"
        }
        return URL(string: "https://\(region).finalfantasyxiv.com/lodestone/")!
    }
}

enum OneTimeCode {
    static func sanitize(_ value: String) -> String {
        String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
    }

    static func isValid(_ value: String) -> Bool {
        value.isEmpty || (value.count == 6 && sanitize(value) == value)
    }
}

actor MemoryPrefetchCache<Value> {
    private var values: [URL: Value] = [:]
    private var pending: [URL: Task<Value?, Never>] = [:]
    private let load: @Sendable (URL) async -> Value?

    init(load: @escaping @Sendable (URL) async -> Value?) {
        self.load = load
    }

    private func value(for url: URL) async -> Value? {
        if let cached = values[url] { return cached }
        if let task = pending[url] { return await task.value }
        let task = Task { await load(url) }
        pending[url] = task
        let result = await task.value
        if let result { values[url] = result }
        pending[url] = nil
        return result
    }

    func prefetch(_ urls: [URL]) async -> [URL: Value] {
        await withTaskGroup(of: (URL, Value?).self) { group in
            for url in Set(urls) {
                group.addTask { (url, await self.value(for: url)) }
            }
            var result: [URL: Value] = [:]
            for await (url, value) in group {
                if let value { result[url] = value }
            }
            return result
        }
    }
}
