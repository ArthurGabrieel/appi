import Foundation

enum RequestError: Error, LocalizedError, Equatable {
    case invalidURL(String)
    case networkError(URLError)
    case timeout
    case cancelled
    case sslError(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return String(localized: "error.request.invalidURL \(url)")
        case .networkError(let error):
            return String(localized: "error.request.network \(error.localizedDescription)")
        case .timeout:
            return String(localized: "error.request.timeout")
        case .cancelled:
            return String(localized: "error.request.cancelled")
        case .sslError(let detail):
            return String(localized: "error.request.ssl \(detail)")
        }
    }
}

enum AuthError: Error, LocalizedError, Equatable {
    case tokenExpired
    case refreshFailed(Error)
    case authorizationDenied
    case invalidConfiguration(String)

    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.tokenExpired, .tokenExpired): return true
        case (.authorizationDenied, .authorizationDenied): return true
        case (.invalidConfiguration(let l), .invalidConfiguration(let r)): return l == r
        case (.refreshFailed, .refreshFailed): return true
        default: return false
        }
    }

    nonisolated var errorDescription: String? {
        switch self {
        case .tokenExpired:
            return String(localized: "error.auth.tokenExpired")
        case .refreshFailed:
            return String(localized: "error.auth.refreshFailed")
        case .authorizationDenied:
            return String(localized: "error.auth.denied")
        case .invalidConfiguration(let detail):
            return String(localized: "error.auth.invalidConfig \(detail)")
        }
    }
}

enum ImportError: Error, LocalizedError {
    case unsupportedFormat
    case corruptedFile(String)
    case parseFailed(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return String(localized: "error.import.unsupportedFormat")
        case .corruptedFile(let detail):
            return String(localized: "error.import.corrupted \(detail)")
        case .parseFailed(let detail):
            return String(localized: "error.import.parseFailed \(detail)")
        }
    }
}

enum PersistenceError: Error, LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(any Error)
    case migrationFailed(Error)

    nonisolated var errorDescription: String? {
        switch self {
        case .saveFailed:
            return String(localized: "error.persistence.saveFailed")
        case .fetchFailed:
            return String(localized: "error.persistence.fetchFailed")
        case .deleteFailed:
            return String(localized: "error.persistence.deleteFailed")
        case .migrationFailed:
            return String(localized: "error.persistence.migrationFailed")
        }
    }
}
