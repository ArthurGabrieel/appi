import Foundation

struct DefaultEnvResolver: EnvResolver {
    private nonisolated(unsafe) let variablePattern = /\{\{(\w+)\}\}/

    nonisolated func resolve(_ draft: RequestDraft, using environment: Environment?) throws -> PreparedRequest {
        let vars = enabledVariables(from: environment)

        let resolvedURL = substituteVariables(in: draft.url, using: vars)
        guard !resolvedURL.isEmpty, let url = URL(string: resolvedURL) else {
            throw RequestError.invalidURL(resolvedURL)
        }

        let resolvedHeaders = draft.headers.map { header in
            var resolved = header
            resolved.value = substituteVariables(in: header.value, using: vars)
            resolved.key = substituteVariables(in: header.key, using: vars)
            return resolved
        }

        let resolvedBody = resolveBody(draft.body, using: vars)

        return PreparedRequest(
            method: draft.method,
            url: url,
            headers: resolvedHeaders.filter(\.isEnabled),
            body: resolvedBody
        )
    }

    nonisolated func unresolvedKeys(in draft: RequestDraft, environment: Environment?) -> [String] {
        let vars = enabledVariables(from: environment)
        var allKeys: Set<String> = []

        allKeys.formUnion(extractKeys(from: draft.url))
        for header in draft.headers where header.isEnabled {
            allKeys.formUnion(extractKeys(from: header.key))
            allKeys.formUnion(extractKeys(from: header.value))
        }
        if case .raw(let content, _) = draft.body {
            allKeys.formUnion(extractKeys(from: content))
        }

        return allKeys.filter { vars[$0] == nil }.sorted()
    }

    // MARK: - Private

    private nonisolated func enabledVariables(from environment: Environment?) -> [String: String] {
        guard let environment else { return [:] }
        var vars: [String: String] = [:]
        for variable in environment.variables where variable.isEnabled {
            vars[variable.key] = variable.value
        }
        return vars
    }

    private nonisolated func substituteVariables(in text: String, using vars: [String: String]) -> String {
        var result = text
        for match in text.matches(of: variablePattern) {
            let key = String(match.1)
            if let value = vars[key] {
                result = result.replacingOccurrences(of: String(match.0), with: value)
            }
        }
        return result
    }

    private nonisolated func resolveBody(_ body: RequestBody, using vars: [String: String]) -> RequestBody {
        switch body {
        case .none:
            return .none
        case .raw(let content, let contentType):
            return .raw(substituteVariables(in: content, using: vars), contentType: contentType)
        case .formData(let fields):
            let resolved = fields.map { field in
                var f = field
                f.key = substituteVariables(in: field.key, using: vars)
                if case .text(let text) = field.value {
                    f.value = .text(substituteVariables(in: text, using: vars))
                }
                return f
            }
            return .formData(resolved)
        }
    }

    private nonisolated func extractKeys(from text: String) -> Set<String> {
        Set(text.matches(of: variablePattern).map { String($0.1) })
    }
}
