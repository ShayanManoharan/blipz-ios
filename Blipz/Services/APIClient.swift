import Foundation

enum APIError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}

extension Error {
    /// A user-safe message for this error — never echoes raw server/API text.
    var friendlyMessage: String {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "You're offline. Check your connection and try again."
            case .timedOut:
                return "That took too long. Please try again."
            default:
                return "Something went wrong. Please try again."
            }
        }
        return "Something went wrong. Please try again."
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        var request = URLRequest(url: Config.apiBaseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = try await AuthManager.shared.currentAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.server(message)
        }
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try await authorizedRequest(path: path, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        var request = try await authorizedRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    // For endpoints that can return more than one *successful* shape (e.g. 200 vs 202
    // "still in progress") — callers decode `data` themselves based on `statusCode`
    // instead of assuming a single fixed response type.
    func postRaw<Body: Encodable>(_ path: String, body: Body) async throws -> (statusCode: Int, data: Data) {
        var request = try await authorizedRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server("Invalid response")
        }
        return (http.statusCode, data)
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}
