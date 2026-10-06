//
//  OTP.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 13.02.22.
//

import Base32
import Embassy
import Foundation
import KeychainAccess

class OTP {
    private let loop: SelectorEventLoop
    private var server: DefaultHTTPServer?
    private static let keychain = Keychain(
        server: "https://secure.square-enix.com", protocolType: .https)
    private var generator: TOTP?
    private var timer = Timer()

    init(username: String) {
        loop = try! SelectorEventLoop(selector: try! KqueueSelector())
        server = DefaultHTTPServer(eventLoop: loop, interface: "::", port: 4646)
        {
            [weak self]
            (
                environ: [String: Any],
                startResponse: (String, [(String, String)]) -> Void,
                sendBody: (Data) -> Void
            ) in
            // Start HTTP response
            startResponse(
                "200 OK", [("Content-Type", "text/plain; charset=utf-8")])
            let pathInfo = environ["PATH_INFO"]! as! String
            let components = pathInfo.split(separator: "/")
            if components.count == 2 && components[0] == "ffxivlauncher"
                && Int(components[1]) != nil
            {
                let otp = String(components[1])
                self?.push(otp: otp)
                sendBody(
                    Data(
                        String(localized: "OTP \(otp) received successfully.")
                            .utf8))
            } else {
                sendBody(
                    Data(
                        String(
                            localized:
                                "Please use this format: http://[Your PC Address]:4646/ffxivlauncher/[one-time password]"
                        ).utf8))
            }
            // send EOF
            sendBody(Data())
        }
        generator = retrieve(username: username)
        start()
    }

    deinit { stop() }

    static func secretStored(username: String) -> Bool {
        return OTP.keychain[data: "\(username)(OTP secret)"] != nil
    }

    static func store(username: String, secret: String) {
        let cleanSecret = secret.components(separatedBy: .whitespaces).joined()
        keychain[data: "\(username)(OTP secret)"] = base32DecodeToData(
            cleanSecret)
    }

    private func retrieve(username: String) -> TOTP? {
        if let secret = OTP.keychain[data: "\(username)(OTP secret)"] {
            return TOTP(secret: secret)
        } else {
            return nil
        }
    }

    private func push(otp: String?) {
        NotificationCenter.default.post(
            name: .otpPush, object: self,
            userInfo: [Notification.status.info: otp ?? ""])
    }

    private func startServer() {
        DispatchQueue.global(qos: .utility).async {
            self.loop.runForever()
        }
        try? server?.start()
    }

    private func stopServer() {
        loop.stop()
        server?.stop()
    }

    func start() {
        startServer()
        if generator != nil {
            push(otp: generator?.token)
            timer.invalidate()
            timer = Timer.scheduledTimer(
                withTimeInterval: 30, repeats: true,
                block: { [weak self] _ in
                    self?.push(otp: self?.generator?.token)
                })
        }
    }

    func stop() {
        stopServer()
        timer.invalidate()
    }
}
