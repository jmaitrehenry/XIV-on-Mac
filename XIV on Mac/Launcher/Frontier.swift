//
//  Frontier.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 07.02.22.
//

import Cocoa
import ImageIO
import OrderedCollections
import SeeURL
import XIVLauncher

class Frontier {
    private static var squareTime: Int64 {
        Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
    }

    public static let frontierURLTemplate =
        "https://launcher.finalfantasyxiv.com/v720/index.html?rc_lang={0}&time={1}"

    private static func generateReferer(lang: FFXIVLanguage) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm"
        let time = dateFormatter.string(from: Date())
        let rcLang = lang.code.replacingOccurrences(of: "-", with: "_")
        let frontierURL =
            frontierURLTemplate
            .replacingOccurrences(of: "{0}", with: rcLang)
            .replacingOccurrences(of: "{1}", with: time)
        return URL(string: frontierURL)!
    }

    private static var referer: URL {
        generateReferer(lang: Settings.language)
    }

    private static var refererGlobal: URL {
        generateReferer(lang: FFXIVLanguage.english)
    }

    private static var headline: URL {
        let lang = Settings.language.code
        return URL(
            string:
                "https://frontier.ffxiv.com/news/headline.json?lang=\(lang)&media=pcapp&_=\(squareTime)"
        )!
    }

    private static var banner: URL {
        let lang = Settings.language.code
        return URL(
            string:
                "https://frontier.ffxiv.com/v2/topics/\(lang)/banner.json?lang=\(lang)&media=pcapp&_=\(squareTime)"
        )!
    }

    static func fetch(url: URL, accept: String? = nil, global: Bool = false)
        -> HTTPClient.Response?
    {
        let headers: OrderedDictionary = [
            "User-Agent": String(cString: getUserAgent()),
            "Accept": accept,
            "Accept-Encoding": "gzip, deflate",
            "Origin": "https://launcher.finalfantasyxiv.com",
            "Referer": (global ? refererGlobal : referer).absoluteString,
            "Connection": "Keep-Alive",
        ]
        return HTTPClient.fetch(url: url, headers: headers)
    }

    static func fetchImage(url: URL) -> NSImage? {
        guard let response = fetch(url: url), response.statusCode == 200,
            let source = CGImageSourceCreateWithData(
                response.body as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(
                source, 0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else {
            return nil
        }
        return NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height))
    }

    struct LoadedBanner: Identifiable {
        let id: String
        let destination: URL
        let image: NSImage
    }

    struct Gate: Codable {
        let status: Int
        let message: [String]?
        let news: [String]?
    }

    struct Login: Codable {
        let status: Int
    }

    static var gameMaintenance: Bool {
        let url = URL(
            string:
                "https://frontier.ffxiv.com/worldStatus/gate_status.json?lang=\(Settings.language.code)&_=\(squareTime)"
        )!
        guard let response = fetch(url: url) else {
            return true
        }
        guard response.statusCode == 200 else {
            return true
        }
        let jsonDecoder = JSONDecoder()
        do {
            let gate = try jsonDecoder.decode(Gate.self, from: response.body)
            return gate.status != 1
        } catch {
            return true
        }
    }

    static var loginMaintenance: Bool {
        let url = URL(
            string:
                "https://frontier.ffxiv.com/worldStatus/login_status.json?_=\(squareTime)"
        )!
        guard let response = fetch(url: url, global: true) else {
            return true
        }
        guard response.statusCode == 200 else {
            return true
        }
        let jsonDecoder = JSONDecoder()
        do {
            let login = try jsonDecoder.decode(Login.self, from: response.body)
            return login.status != 1
        } catch {
            return true
        }
    }

    typealias Info = FrontierHeadlines

    static var lodestoneURL: URL {
        Info.lodestoneURL(languageCode: Settings.language.code)
    }

    struct BannerRoot: Codable {
        struct Banner: Codable {
            let lsbBanner: String
            let link: String
            let orderPriority: Int32
            let fixOrder: Int32?

            enum CodingKeys: String, CodingKey {
                case lsbBanner = "lsb_banner"
                case link
                case orderPriority = "order_priority"
                case fixOrder = "fix_order"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                lsbBanner = try container.decode(
                    String.self, forKey: .lsbBanner)
                link = try container.decode(String.self, forKey: .link)

                let orderPriorityString = try container.decode(
                    String.self, forKey: .orderPriority)
                orderPriority = Int32(orderPriorityString) ?? 0

                if let fixOrderString = try container.decodeIfPresent(
                    String.self, forKey: .fixOrder)
                {
                    fixOrder = Int32(fixOrderString) ?? nil
                } else {
                    fixOrder = nil
                }
            }
        }

        let banner: [Banner]
    }

    static var info: Info? {
        guard let response = fetch(url: headline), response.statusCode == 200
        else {
            return nil
        }
        let jsonDecoder = JSONDecoder()
        do {
            return try jsonDecoder.decode(Info.self, from: response.body)
        } catch {
            Log.warning("Could not decode Frontier headlines: \(error)")
            return nil
        }
    }

    static var banners: [BannerRoot.Banner]? {
        guard let response = fetch(url: banner), response.statusCode == 200
        else {
            return nil
        }
        let jsonDecoder = JSONDecoder()
        do {
            let bannerRoot = try jsonDecoder.decode(
                BannerRoot.self, from: response.body)
            return bannerRoot.banner.sorted {
                if let fixOrder0 = $0.fixOrder, let fixOrder1 = $1.fixOrder {
                    return fixOrder0 > fixOrder1
                }
                if $0.fixOrder != nil {
                    return true
                }
                if $1.fixOrder != nil {
                    return false
                }
                return $0.orderPriority > $1.orderPriority
            }
        } catch {
            Log.warning("Could not decode Frontier banners: \(error)")
            return nil
        }
    }
}
