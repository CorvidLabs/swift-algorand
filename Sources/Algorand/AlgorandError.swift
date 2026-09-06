@preconcurrency import Foundation

/// Errors that can occur when working with the Algorand SDK
public enum AlgorandError: Error, Sendable {
    /// A value that must be a canonical Algorand address was not one.
    case invalidAddress(String)

    /// A 25-word mnemonic was malformed, misspelled, non-canonical, or failed its checksum.
    case invalidMnemonic(String)

    /// A transaction could not be built or is not well formed.
    case invalidTransaction(String)

    /// An endpoint string or a request URL could not be built.
    ///
    /// Distinct from ``invalidAddress(_:)``, which is reserved for Algorand account addresses.
    /// A client base URL that is not an absolute `http` or `https` URL, and a request whose
    /// components cannot be assembled, report here.
    case invalidURL(String)

    /// The request could not be completed, or the response was not an HTTP response.
    case networkError(String)

    /// A value could not be encoded for transmission.
    case encodingError(String)

    /// A value could not be decoded from a response.
    case decodingError(String)

    /// A response was well formed at the transport layer but not usable.
    case invalidResponse(String)

    /// The node or indexer returned a non-2xx status.
    case apiError(statusCode: Int, message: String)
}

// MARK: - LocalizedError

extension AlgorandError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidAddress(let message):
            return "Invalid address: \(message)"
        case .invalidMnemonic(let message):
            return "Invalid mnemonic: \(message)"
        case .invalidTransaction(let message):
            return "Invalid transaction: \(message)"
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
