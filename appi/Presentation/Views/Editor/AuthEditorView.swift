import SwiftUI

struct AuthEditorView: View {
    @Binding var auth: AuthConfig
    let allowInherit: Bool          // false for root collections
    let effectiveAuth: AuthConfig?  // the first non-inherit AuthConfig from the ancestor chain;
                                    // AuthConfig (not ResolvedAuth) to avoid triggering token refresh
    let authError: (any LocalizedError)?
    let onClearAuthError: (() -> Void)?
    let onGetToken: ((OAuth2Config) async -> Bool)?

    var body: some View {
        Form {
            if let authError {
                InlineErrorBanner(error: authError) {
                    onClearAuthError?()
                }
            }

            Section {
                Picker(String(localized: "auth.type"), selection: authTypeBinding) {
                    if allowInherit {
                        Text(String(localized: "auth.inherit")).tag(AuthType.inherit)
                    }
                    Text(String(localized: "auth.none")).tag(AuthType.none)
                    Text(String(localized: "auth.basic")).tag(AuthType.basic)
                    Text(String(localized: "auth.bearer")).tag(AuthType.bearer)
                    Text(String(localized: "auth.oauth2")).tag(AuthType.oauth2)
                }
                .pickerStyle(.menu)
                .accessibilityLabel(String(localized: "auth.type"))
            }

            switch auth {
            case .inheritFromParent:
                if let effective = effectiveAuth {
                    InheritedAuthPreview(auth: effective)
                } else {
                    Text(String(localized: "auth.inherit.loading"))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            case .none:
                Text(String(localized: "auth.none.description"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            case .basic(let username, let password):
                Section(String(localized: "auth.basic.credentials")) {
                    TextField(String(localized: "auth.basic.username"), text: Binding(
                        get: { username },
                        set: { auth = .basic(username: $0, password: password) }
                    ))
                    .accessibilityLabel(String(localized: "auth.basic.username"))
                    SecureField(String(localized: "auth.basic.password"), text: Binding(
                        get: { password },
                        set: { auth = .basic(username: username, password: $0) }
                    ))
                    .accessibilityLabel(String(localized: "auth.basic.password"))
                }
            case .bearer(let token):
                Section(String(localized: "auth.bearer.token")) {
                    SecureField(String(localized: "auth.bearer.tokenPlaceholder"), text: Binding(
                        get: { token },
                        set: { auth = .bearer(token: $0) }
                    ))
                    .accessibilityLabel(String(localized: "auth.bearer.token"))
                }
            case .oauth2(let config):
                OAuth2ConfigFields(
                    config: Binding(get: { config }, set: { auth = .oauth2($0) }),
                    hasAuthError: authError != nil,
                    onGetToken: onGetToken
                )
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(String(localized: "auth.editor.label"))
    }

    private enum AuthType: Hashable {
        case inherit, none, basic, bearer, oauth2
    }

    private var authTypeBinding: Binding<AuthType> {
        Binding(
            get: {
                switch auth {
                case .inheritFromParent: .inherit
                case .none: .none
                case .basic: .basic
                case .bearer: .bearer
                case .oauth2: .oauth2
                }
            },
            set: { newType in
                switch newType {
                case .inherit: auth = .inheritFromParent
                case .none: auth = .none
                case .basic: auth = .basic(username: "", password: "")
                case .bearer: auth = .bearer(token: "")
                case .oauth2: auth = .oauth2(OAuth2Config(
                    authURL: "", tokenURL: "", clientId: "",
                    clientSecret: nil, scopes: [], redirectURI: ""))
                }
            }
        )
    }
}

// MARK: - InheritedAuthPreview
// Takes AuthConfig (not ResolvedAuth) — shows what type is inherited without touching tokens.

struct InheritedAuthPreview: View {
    let auth: AuthConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "auth.inherit.effective"))
                .font(.caption)
                .foregroundStyle(.secondary)
            switch auth {
            case .none, .inheritFromParent:
                Text(String(localized: "auth.none")).foregroundStyle(.secondary)
            case .basic(let username, _):
                Text(String(format: String(localized: "auth.basic.preview"), username)).foregroundStyle(.secondary)
            case .bearer:
                Text(String(localized: "auth.bearer.preview")).foregroundStyle(.secondary)
            case .oauth2(let config):
                Text(String(format: String(localized: "auth.oauth2.preview"), config.clientId)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel(String(localized: "auth.inherit.preview.label"))
    }
}

// MARK: - OAuth2ConfigFields

struct OAuth2ConfigFields: View {
    @Binding var config: OAuth2Config
    let hasAuthError: Bool
    let onGetToken: ((OAuth2Config) async -> Bool)?
    @State private var tokenStatus: String = ""

    var body: some View {
        Section(String(localized: "auth.oauth2.config")) {
            TextField(String(localized: "auth.oauth2.authURL"), text: $config.authURL)
                .accessibilityLabel(String(localized: "auth.oauth2.authURL"))
            TextField(String(localized: "auth.oauth2.tokenURL"), text: $config.tokenURL)
                .accessibilityLabel(String(localized: "auth.oauth2.tokenURL"))
            TextField(String(localized: "auth.oauth2.clientId"), text: $config.clientId)
                .accessibilityLabel(String(localized: "auth.oauth2.clientId"))
            SecureField(String(localized: "auth.oauth2.clientSecret"), text: Binding(
                get: { config.clientSecret ?? "" },
                set: { config.clientSecret = $0.isEmpty ? nil : $0 }
            ))
            .accessibilityLabel(String(localized: "auth.oauth2.clientSecret"))
            TextField(String(localized: "auth.oauth2.scopes"), text: Binding(
                get: { config.scopes.joined(separator: " ") },
                set: { config.scopes = $0.split(separator: " ").map(String.init) }
            ))
            .accessibilityLabel(String(localized: "auth.oauth2.scopes"))
            TextField(String(localized: "auth.oauth2.redirectURI"), text: $config.redirectURI)
                .accessibilityLabel(String(localized: "auth.oauth2.redirectURI"))
        }
        if let onGetToken {
            Section {
                HStack {
                    let label = hasAuthError
                        ? String(localized: "auth.oauth2.reauthorize")
                        : String(localized: "auth.oauth2.getToken")
                    Button(label) {
                        Task {
                            tokenStatus = String(localized: "auth.oauth2.authorizing")
                            let didSucceed = await onGetToken(config)
                            tokenStatus = didSucceed
                                ? String(localized: "auth.oauth2.tokenObtained")
                                : ""
                        }
                    }
                    .disabled(config.authURL.isEmpty || config.tokenURL.isEmpty || config.clientId.isEmpty)
                    .accessibilityLabel(label)

                    if !tokenStatus.isEmpty {
                        Text(tokenStatus).foregroundStyle(.secondary).font(.caption)
                    }
                }
            }
        }
    }
}
