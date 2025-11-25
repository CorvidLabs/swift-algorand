@preconcurrency import Foundation

/// Errors that can occur when working with the Algorand SDK
public enum AlgorandError: Error, Sendable {
    case invalidAddress(String)
    case invalidMnemonic(String)
    case invalidTransaction(String)
    case networkError(String)
    case encodingError(String)
    case decodingError(String)
    case invalidResponse(String)
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
