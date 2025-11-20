import Foundation

/// Protocol for URL session operations
public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func data(from url: URL) async throws -> (Data, URLResponse)
}

/// Extension to make URLSession conform to URLSessionProtocol
extension URLSession: URLSessionProtocol {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await data(for: request)
    }
    
    public func data(from url: URL) async throws -> (Data, URLResponse) {
        return try await data(from: url)
    }
}

/// Protocol for logging operations
public protocol Logging {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

/// Default logger implementation
public class DefaultLogger: Logging {
    private let dateFormatter: DateFormatter
    
    public init() {
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    public func debug(_ message: String) {
        print("[\(dateFormatter.string(from: Date()))] DEBUG: \(message)")
    }
    
    public func info(_ message: String) {
        print("[\(dateFormatter.string(from: Date()))] INFO: \(message)")
    }
    
    public func warning(_ message: String) {
        print("[\(dateFormatter.string(from: Date()))] WARNING: \(message)")
    }
    
    public func error(_ message: String) {
        print("[\(dateFormatter.string(from: Date()))] ERROR: \(message)")
    }
}

/// Protocol for HTTP client operations
public protocol HTTPClient {
    /// Fetch HTML content from a URL
    func fetchHTML(from url: String) async throws -> String
    
    /// Fetch raw data from a URL
    func fetchData(from url: String) async throws -> Data
    
    /// Check if a URL is accessible
    func checkAccessibility(of url: String) async throws -> Bool
}

/// HTTP client implementation using URLSession
public class DefaultHTTPClient: HTTPClient {
    private let session: URLSessionProtocol
    private let logger: Logging
    
    public init(session: URLSessionProtocol = URLSession.shared, logger: Logging = DefaultLogger()) {
        self.session = session
        self.logger = logger
    }
    
    public func fetchHTML(from url: String) async throws -> String {
        logger.info("Fetching HTML from \(url)")
        
        guard let urlObject = URL(string: url) else {
            throw HTTPError.invalidURL(url)
        }
        
        let request = URLRequest(url: urlObject)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw HTTPError.httpError(httpResponse.statusCode)
        }
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw HTTPError.decodingFailed
        }
        
        logger.info("Successfully fetched HTML content (\(data.count) bytes)")
        return htmlString
    }
    
    public func fetchData(from url: String) async throws -> Data {
        logger.info("Fetching data from \(url)")
        
        guard let urlObject = URL(string: url) else {
            throw HTTPError.invalidURL(url)
        }
        
        let (data, response) = try await session.data(from: urlObject)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw HTTPError.httpError(httpResponse.statusCode)
        }
        
        logger.info("Successfully fetched data (\(data.count) bytes)")
        return data
    }
    
    public func checkAccessibility(of url: String) async throws -> Bool {
        guard let urlObject = URL(string: url) else {
            return false
        }
        
        let request = URLRequest(url: urlObject)
        let (_, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return 200...299 ~= httpResponse.statusCode
        }
        
        return false
    }
}

/// HTTP-related errors
public enum HTTPError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .httpError(let code):
            return "HTTP error with status code: \(code)"
        case .decodingFailed:
            return "Failed to decode response data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Protocol for JavaScript execution
public protocol JavaScriptExecutor {
    /// Execute JavaScript code and return result
    func execute(_ script: String) async throws -> String
}

/// Mock JavaScript executor for server-side execution
public class DefaultJavaScriptExecutor: JavaScriptExecutor {
    public init() {}
    
    public func execute(_ script: String) async throws -> String {
        // This is a simplified implementation
        // In a real-world scenario, you would use a JavaScript engine like JavaScriptCore
        throw JavaScriptError.executionNotSupported
    }
}

/// JavaScript execution errors
public enum JavaScriptError: Error, LocalizedError {
    case executionNotSupported
    
    public var errorDescription: String? {
        switch self {
        case .executionNotSupported:
            return "JavaScript execution is not supported in this environment"
        }
    }
}