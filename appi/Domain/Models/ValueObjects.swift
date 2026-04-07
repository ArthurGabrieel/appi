import Foundation

// MARK: - HTTPMethod

enum HTTPMethod: String, Codable, CaseIterable, Equatable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

// MARK: - Header

struct Header: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var key: String
    var value: String
    var isEnabled: Bool
}

// MARK: - FormField

enum FormFieldValue: Codable, Equatable, Hashable {
    case text(String)
    case file(fileName: String, mimeType: String, data: Data)
}

struct FormField: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var key: String
    var value: FormFieldValue
    var isEnabled: Bool
}

// MARK: - RequestBody

enum RequestBody: Codable, Equatable {
    case none
    case raw(String, contentType: String)
    case formData([FormField])

    // Manual Codable — enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type, content, contentType, fields
    }

    private enum BodyType: String, Codable {
        case none, raw, formData
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(BodyType.none, forKey: .type)
        case .raw(let content, let contentType):
            try container.encode(BodyType.raw, forKey: .type)
            try container.encode(content, forKey: .content)
            try container.encode(contentType, forKey: .contentType)
        case .formData(let fields):
            try container.encode(BodyType.formData, forKey: .type)
            try container.encode(fields, forKey: .fields)
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BodyType.self, forKey: .type)
        switch type {
        case .none:
            self = .none
        case .raw:
            let content = try container.decode(String.self, forKey: .content)
            let contentType = try container.decode(String.self, forKey: .contentType)
            self = .raw(content, contentType: contentType)
        case .formData:
            let fields = try container.decode([FormField].self, forKey: .fields)
            self = .formData(fields)
        }
    }
}

// MARK: - Auth

struct OAuth2Config: Codable, Equatable, Hashable {
    var authURL: String
    var tokenURL: String
    var clientId: String
    var clientSecret: String?
    var scopes: [String]
    var redirectURI: String
}

struct TokenSet: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

enum AuthConfig: Codable, Equatable {
    case inheritFromParent
    case none
    case basic(username: String, password: String)
    case bearer(token: String)
    case oauth2(OAuth2Config)

    private enum CodingKeys: String, CodingKey {
        case type, username, password, token, config
    }

    private enum AuthType: String, Codable {
        case inheritFromParent, none, basic, bearer, oauth2
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .inheritFromParent:
            try container.encode(AuthType.inheritFromParent, forKey: .type)
        case .none:
            try container.encode(AuthType.none, forKey: .type)
        case .basic(let username, let password):
            try container.encode(AuthType.basic, forKey: .type)
            try container.encode(username, forKey: .username)
            try container.encode(password, forKey: .password)
        case .bearer(let token):
            try container.encode(AuthType.bearer, forKey: .type)
            try container.encode(token, forKey: .token)
        case .oauth2(let config):
            try container.encode(AuthType.oauth2, forKey: .type)
            try container.encode(config, forKey: .config)
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(AuthType.self, forKey: .type)
        switch type {
        case .inheritFromParent: self = .inheritFromParent
        case .none: self = .none
        case .basic:
            self = .basic(
                username: try container.decode(String.self, forKey: .username),
                password: try container.decode(String.self, forKey: .password)
            )
        case .bearer:
            self = .bearer(token: try container.decode(String.self, forKey: .token))
        case .oauth2:
            self = .oauth2(try container.decode(OAuth2Config.self, forKey: .config))
        }
    }
}

enum ResolvedAuth: Codable, Equatable {
    case none
    case basic(username: String, password: String)
    case bearer(token: String)
    case oauth2(OAuth2Config, tokenSet: TokenSet)

    private enum CodingKeys: String, CodingKey {
        case type, username, password, token, config, tokenSet
    }

    private enum AuthType: String, Codable {
        case none, basic, bearer, oauth2
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(AuthType.none, forKey: .type)
        case .basic(let username, let password):
            try container.encode(AuthType.basic, forKey: .type)
            try container.encode(username, forKey: .username)
            try container.encode(password, forKey: .password)
        case .bearer(let token):
            try container.encode(AuthType.bearer, forKey: .type)
            try container.encode(token, forKey: .token)
        case .oauth2(let config, let tokenSet):
            try container.encode(AuthType.oauth2, forKey: .type)
            try container.encode(config, forKey: .config)
            try container.encode(tokenSet, forKey: .tokenSet)
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(AuthType.self, forKey: .type)
        switch type {
        case .none: self = .none
        case .basic:
            self = .basic(
                username: try container.decode(String.self, forKey: .username),
                password: try container.decode(String.self, forKey: .password)
            )
        case .bearer:
            self = .bearer(token: try container.decode(String.self, forKey: .token))
        case .oauth2:
            self = .oauth2(
                try container.decode(OAuth2Config.self, forKey: .config),
                tokenSet: try container.decode(TokenSet.self, forKey: .tokenSet)
            )
        }
    }
}

// MARK: - Resolved Requests

struct PreparedRequest: Equatable {
    let method: HTTPMethod
    let url: URL
    let headers: [Header]
    let body: RequestBody

    func withAuth(_ auth: ResolvedAuth) -> ResolvedRequest {
        ResolvedRequest(method: method, url: url, headers: headers, body: body, auth: auth)
    }
}

struct ResolvedRequest: Equatable {
    let method: HTTPMethod
    let url: URL
    let headers: [Header]
    let body: RequestBody
    let auth: ResolvedAuth
}

// MARK: - Import

struct ImportResult {
    let collections: [Collection]
    let requests: [Request]
    let environments: [Environment]
    let warnings: [ImportWarning]
}

struct ImportWarning: Equatable {
    let item: String
    let reason: String
}
