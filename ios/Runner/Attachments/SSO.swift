////
////  SSO.swift
////  Runner
////
////  Created by Ayman Fathy on 02/01/2026.
////
//
//import Foundation
//import CryptoKit
//import WebKit
//
//enum OIDCConfig {
//    static let baseURL = "https://csitproxy.dev.hq.nwc/realms/workforce/protocol/openid-connect"
//    static let clientId = "<CLIENT_ID_FROM_SSO>"
//    static let redirectURI = "mobileapphandler://auth"
//}
//
//
//struct PKCE {
//
//    let verifier: String
//    let challenge: String
//
//    static func generate() -> PKCE {
//        let verifier = randomString(length: 64)
//        let challenge = sha256Base64URL(verifier)
//        return PKCE(verifier: verifier, challenge: challenge)
//    }
//
//    private static func randomString(length: Int) -> String {
//        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
//        return String((0..<length).compactMap { _ in chars.randomElement() })
//    }
//
//    private static func sha256Base64URL(_ input: String) -> String {
//        let data = Data(input.utf8)
//        let hash = SHA256.hash(data: data)
//        return Data(hash)
//            .base64EncodedString()
//            .replacingOccurrences(of: "+", with: "-")
//            .replacingOccurrences(of: "/", with: "_")
//            .replacingOccurrences(of: "=", with: "")
//    }
//}
//
//
//final class OIDCLoginViewController: UIViewController {
//
//    private let webView = WKWebView()
//    private let pkce = PKCE.generate()
//    private let state = UUID().uuidString
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        webView.navigationDelegate = self
//        view.addSubview(webView)
//        webView.frame = view.bounds
//
//        let url = authorizationURL(pkce: pkce, state: state)
//        webView.load(URLRequest(url: url))
//    }
//    func authorizationURL(pkce: PKCE, state: String) -> URL {
//        var components = URLComponents(string: "\(OIDCConfig.baseURL)/auth")!
//        components.queryItems = [
//            .init(name: "scope", value: "openid"),
//            .init(name: "response_type", value: "code"),
//            .init(name: "client_id", value: OIDCConfig.clientId),
//            .init(name: "code_challenge", value: pkce.challenge),
//            .init(name: "code_challenge_method", value: "S256"),
//            .init(name: "redirect_uri", value: OIDCConfig.redirectURI),
//            .init(name: "state", value: state)
//        ]
//        return components.url!
//    }
//    func exchangeCodeForToken(_ code: String) {
//        var request = URLRequest(
//            url: URL(string: "\(OIDCConfig.baseURL)/token")!
//        )
//        request.httpMethod = "POST"
//        request.setValue(
//            "application/x-www-form-urlencoded;charset=UTF-8",
//            forHTTPHeaderField: "Content-Type"
//        )
//
//        let body = [
//            "grant_type=authorization_code",
//            "client_id=\(OIDCConfig.clientId)",
//            "redirect_uri=\(OIDCConfig.redirectURI)",
//            "code=\(code)",
//            "code_verifier=\(pkce.verifier)"
//        ].joined(separator: "&")
//
//        request.httpBody = body.data(using: .utf8)
//
//        URLSession.shared.dataTask(with: request) { data, _, _ in
//            let token = try? JSONDecoder().decode(TokenResponse.self, from: data!)
//            TokenStore.save(token!)
//        }.resume()
//    }
//    
//    func refreshToken(_ refreshToken: String) {
//        var request = URLRequest(
//            url: URL(string: "\(OIDCConfig.baseURL)/token")!
//        )
//        request.httpMethod = "POST"
//        request.setValue(
//            "application/x-www-form-urlencoded;charset=UTF-8",
//            forHTTPHeaderField: "Content-Type"
//        )
//
//        request.httpBody = """
//        grant_type=refresh_token&
//        client_id=\(OIDCConfig.clientId)&
//        refresh_token=\(refreshToken)
//        """.data(using: .utf8)
//
//        URLSession.shared.dataTask(with: request) { data, _, _ in
//            let token = try? JSONDecoder().decode(TokenResponse.self, from: data!)
//            TokenStore.save(token!)
//        }.resume()
//    }
//    
//    func logout(refreshToken: String) {
//        var request = URLRequest(
//            url: URL(string: "\(OIDCConfig.baseURL)/logout")!
//        )
//        request.httpMethod = "POST"
//        request.setValue(
//            "application/x-www-form-urlencoded;charset=UTF-8",
//            forHTTPHeaderField: "Content-Type"
//        )
//
//        request.httpBody = """
//        client_id=\(OIDCConfig.clientId)&
//        refresh_token=\(refreshToken)
//        """.data(using: .utf8)
//
//        URLSession.shared.dataTask(with: request).resume()
//    }
//}
//extension OIDCLoginViewController: WKNavigationDelegate {
//
//    func webView(
//        _ webView: WKWebView,
//        decidePolicyFor navigationAction: WKNavigationAction,
//        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
//    ) {
//        guard let url = navigationAction.request.url else {
//            decisionHandler(.allow)
//            return
//        }
//
//        if url.scheme == "mobileapphandler" {
//            decisionHandler(.cancel)   // 🔴 return immediately
//            handleRedirect(url)
//            return
//        }
//
//        decisionHandler(.allow)
//    }
//    
//    private func handleRedirect(_ url: URL) {
//        guard
//            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
//            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
//        else {
//            return
//        }
//
//        // Dismiss UI immediately
//        DispatchQueue.main.async {
//            self.dismiss(animated: true)
//        }
//
//        // Exchange token off main thread
//        DispatchQueue.global(qos: .userInitiated).async {
//            self.exchangeCodeForToken(code)
//        }
//    }
//}
//
//struct TokenResponse: Codable {
//    let access_token: String
//    let refresh_token: String
//    let expires_in: Int
//    let refresh_expires_in: Int
//    let id_token: String
//}
//
//
//protocol TokenStoreProtocol {
//    func save(_ token: TokenResponse)
//    func accessToken() -> String?
//    func refreshToken() -> String?
//    func clear()
//}
//
//
//import Security
//
//final class KeychainHelper {
//
//    static let shared = KeychainHelper()
//    private init() {}
//
//    func save(_ data: Data, service: String, account: String) {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account
//        ]
//
//        SecItemDelete(query as CFDictionary)
//
//        let attributes: [String: Any] = query.merging([
//            kSecValueData as String: data
//        ]) { $1 }
//
//        SecItemAdd(attributes as CFDictionary, nil)
//    }
//
//    func read(service: String, account: String) -> Data? {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account,
//            kSecReturnData as String: true,
//            kSecMatchLimit as String: kSecMatchLimitOne
//        ]
//
//        var result: AnyObject?
//        SecItemCopyMatching(query as CFDictionary, &result)
//        return result as? Data
//    }
//
//    func delete(service: String, account: String) {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account
//        ]
//
//        SecItemDelete(query as CFDictionary)
//    }
//}
//
//
//
//final class TokenStore: TokenStoreProtocol {
//
//    static let shared = TokenStore()
//
//    private let service = "com.yourcompany.oidc"
//
//    private enum Key {
//        static let accessToken = "access_token"
//        static let refreshToken = "refresh_token"
//        static let expiryDate = "expiry_date"
//    }
//
//    private init() {}
//
//    func save(_ token: TokenResponse) {
//        let expiryDate = Date().addingTimeInterval(TimeInterval(token.expires_in))
//
//        KeychainHelper.shared.save(
//            Data(token.access_token.utf8),
//            service: service,
//            account: Key.accessToken
//        )
//
//        KeychainHelper.shared.save(
//            Data(token.refresh_token.utf8),
//            service: service,
//            account: Key.refreshToken
//        )
//
//        KeychainHelper.shared.save(
//            Data("\(expiryDate.timeIntervalSince1970)".utf8),
//            service: service,
//            account: Key.expiryDate
//        )
//    }
//
//    func accessToken() -> String? {
//        guard let data = KeychainHelper.shared.read(
//            service: service,
//            account: Key.accessToken
//        ) else { return nil }
//
//        return String(decoding: data, as: UTF8.self)
//    }
//
//    func refreshToken() -> String? {
//        guard let data = KeychainHelper.shared.read(
//            service: service,
//            account: Key.refreshToken
//        ) else { return nil }
//
//        return String(decoding: data, as: UTF8.self)
//    }
//
//    func isAccessTokenExpired() -> Bool {
//        guard
//            let data = KeychainHelper.shared.read(
//                service: service,
//                account: Key.expiryDate
//            ),
//            let timestamp = TimeInterval(String(decoding: data, as: UTF8.self))
//        else {
//            return true
//        }
//
//        return Date() >= Date(timeIntervalSince1970: timestamp)
//    }
//
//    func clear() {
//        KeychainHelper.shared.delete(service: service, account: Key.accessToken)
//        KeychainHelper.shared.delete(service: service, account: Key.refreshToken)
//        KeychainHelper.shared.delete(service: service, account: Key.expiryDate)
//    }
//}
//
////
////https://csitproxy.dev.hq.nwc/realms/workforce/protocol/openid-connect/auth?scope=openid&response_type=code&client_id=MoamalatMobApp&code_challenge=wiP-izZ-KH4vPvx2BRYm7igMKfKARrqzzaGAEmF8LLc&code_challenge_method=S256&redirect_uri=sa.gov.nwc.moamalat.new://oauth2redirect/loggedin&state=832DE455-E29F-4EDC-92CC-2B9224A86A2B
