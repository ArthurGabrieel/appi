import Foundation

final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func execute(_ request: ResolvedRequest) async throws -> Response {
        let urlRequest = buildURLRequest(from: request)
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, urlResponse) = try await session.data(for: urlRequest)
            return try makeResponse(
                data: data,
                urlResponse: urlResponse,
                startedAt: start
            )
        } catch is CancellationError {
            throw RequestError.cancelled
        } catch let error as RequestError {
            throw error
        } catch let error as URLError {
            throw map(error)
        } catch {
            throw RequestError.networkError(URLError(.unknown))
        }
    }

    // MARK: - Private

    private nonisolated func map(_ error: URLError) -> RequestError {
        switch error.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timeout
        case .serverCertificateUntrusted, .serverCertificateHasBadDate:
            return .sslError(error.localizedDescription)
        default:
            return .networkError(error)
        }
    }

    private nonisolated func makeResponse(data: Data, urlResponse: URLResponse, startedAt: CFAbsoluteTime) throws -> Response {
        let duration = CFAbsoluteTimeGetCurrent() - startedAt

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw RequestError.networkError(URLError(.badServerResponse))
        }

        let responseHeaders = httpResponse.allHeaderFields.compactMap { key, value -> Header? in
            guard let k = key as? String, let v = value as? String else { return nil }
            return Header(id: UUID(), key: k, value: v, isEnabled: true)
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")

        return Response(
            id: UUID(),
            statusCode: httpResponse.statusCode,
            statusMessage: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
            headers: responseHeaders,
            body: data,
            contentType: contentType,
            duration: duration,
            size: data.count,
            createdAt: Date()
        )
    }

    private nonisolated func buildURLRequest(from request: ResolvedRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue

        for header in request.headers where header.isEnabled {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }

        switch request.auth {
        case .none:
            break
        case .basic(let username, let password):
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                urlRequest.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        case .bearer(let token):
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .oauth2(_, let tokenSet):
            urlRequest.setValue("Bearer \(tokenSet.accessToken)", forHTTPHeaderField: "Authorization")
        }

        switch request.body {
        case .none:
            break
        case .raw(let content, let contentType):
            urlRequest.httpBody = content.data(using: .utf8)
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        case .formData(let fields):
            let boundary = UUID().uuidString
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = buildMultipartBody(fields: fields, boundary: boundary)
        }

        return urlRequest
    }

    private nonisolated func buildMultipartBody(fields: [FormField], boundary: String) -> Data {
        var body = Data()
        for field in fields where field.isEnabled {
            body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
            switch field.value {
            case .text(let text):
                body.append("Content-Disposition: form-data; name=\"\(field.key)\"\r\n\r\n".data(using: .utf8) ?? Data())
                body.append("\(text)\r\n".data(using: .utf8) ?? Data())
            case .file(let fileName, let mimeType, let fileData):
                body.append("Content-Disposition: form-data; name=\"\(field.key)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8) ?? Data())
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8) ?? Data())
                body.append(fileData)
                body.append("\r\n".data(using: .utf8) ?? Data())
            }
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8) ?? Data())
        return body
    }
}
