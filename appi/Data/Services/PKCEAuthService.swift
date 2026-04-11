// appi/Data/Services/PKCEAuthService.swift
import Foundation
import AuthenticationServices
import CryptoKit
import Security
import AppKit

// MARK: - Setup requirement
// Register custom URL scheme in target Info.plist → CFBundleURLTypes → CFBundleURLSchemes
// so ASWebAuthenticationSession can intercept the OAuth2 callback redirect.
// Example: add scheme "appi" to handle redirect URIs like "appi://oauth-callback".

actor PKCEAuthService: AuthService {
    private let keychainService: any KeychainService
    private var currentSession: ASWebAuthenticationSession?

    init(keychainService: any KeychainService) {
        self.keychainService = keychainService
    }

    // MARK: - Token storage

    func loadToken(for config: OAuth2Config) throws -> TokenSet? {
        guard let data = try keychainService.load(for: tokenKey(config)) else { return nil }
        return try JSONDecoder().decode(TokenSet.self, from: data)
    }

    func saveToken(_ tokenSet: TokenSet, for config: OAuth2Config) throws {
        let data = try JSONEncoder().encode(tokenSet)
        try keychainService.save(data, for: tokenKey(config))
    }

    private func tokenKey(_ config: OAuth2Config) -> String {
        "oauth2.\(config.clientId).\(config.authURL)"
    }

    private func clearCurrentSession() {
        currentSession = nil
    }

    // MARK: - Authorization

    func authorize(with config: OAuth2Config) async throws -> TokenSet {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        let authURL = try buildAuthURL(config: config, codeChallenge: codeChallenge)
        let callbackScheme = try extractScheme(from: config.redirectURI)

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { url, error in
                Task { await self.clearCurrentSession() }
                if error != nil {
                    continuation.resume(throwing: AuthError.authorizationDenied)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: AuthError.authorizationDenied)
                    return
                }
                continuation.resume(returning: url)
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = PresentationContextProvider.shared
            currentSession = session
            guard session.start() else {
                currentSession = nil
                continuation.resume(throwing: AuthError.authorizationDenied)
                return
            }
        }

        let code = try extractCode(from: callbackURL)
        let tokenSet = try await exchangeCode(code, codeVerifier: codeVerifier, config: config)
        try saveToken(tokenSet, for: config)
        return tokenSet
    }

    // MARK: - Refresh

    func refreshIfNeeded(tokenSet: TokenSet, config: OAuth2Config) async throws -> TokenSet {
        if tokenSet.expiresAt > Date.now.addingTimeInterval(30) { return tokenSet }

        guard let refreshToken = tokenSet.refreshToken else {
            throw AuthError.tokenExpired
        }

        var params: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientId,
        ]
        if let secret = config.clientSecret { params["client_secret"] = secret }

        let newTokenSet = try await postTokenRequest(url: config.tokenURL, params: params)
        try saveToken(newTokenSet, for: config)
        return newTokenSet
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 96)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncoded()
    }

    private func buildAuthURL(config: OAuth2Config, codeChallenge: String) throws -> URL {
        guard var components = URLComponents(string: config.authURL) else {
            throw AuthError.invalidConfiguration("Invalid auth URL: \(config.authURL)")
        }
        var items = components.queryItems ?? []
        items += [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: UUID().uuidString),
        ]
        components.queryItems = items
        guard let url = components.url else {
            throw AuthError.invalidConfiguration("Could not build auth URL")
        }
        return url
    }

    private func extractScheme(from redirectURI: String) throws -> String {
        guard let scheme = URL(string: redirectURI)?.scheme else {
            throw AuthError.invalidConfiguration("Invalid redirect URI: \(redirectURI)")
        }
        return scheme
    }

    private func extractCode(from callbackURL: URL) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw AuthError.authorizationDenied
        }
        return code
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String, codeVerifier: String, config: OAuth2Config) async throws -> TokenSet {
        var params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientId,
            "code_verifier": codeVerifier,
        ]
        if let secret = config.clientSecret { params["client_secret"] = secret }
        return try await postTokenRequest(url: config.tokenURL, params: params)
    }

    private func postTokenRequest(url tokenURLString: String, params: [String: String]) async throws -> TokenSet {
        guard let url = URL(string: tokenURLString) else {
            throw AuthError.invalidConfiguration("Invalid token URL: \(tokenURLString)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.refreshFailed(AuthError.tokenExpired)
        }

        let json = try JSONDecoder().decode([String: String].self, from: data)
        guard let accessToken = json["access_token"] else {
            throw AuthError.refreshFailed(AuthError.tokenExpired)
        }
        let expiresIn = Double(json["expires_in"] ?? "3600") ?? 3600
        return TokenSet(
            accessToken: accessToken,
            refreshToken: json["refresh_token"],
            expiresAt: Date.now.addingTimeInterval(expiresIn)
        )
    }
}

// MARK: - Base64URL

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation context (macOS)

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? NSWindow()
    }
}
