@preconcurrency import Foundation

/// Parsing for the endpoint strings callers hand to ``AlgodClient`` and ``IndexerClient``.
internal enum EndpointURL {
    /// The schemes an Algorand node endpoint may use.
    private static let allowedSchemes: Set<String> = ["http", "https"]

    /**
     Parses an endpoint string, rejecting anything that is not an absolute http(s) URL.

     `URL(string:)` alone is not a validity check: Swift 6's Foundation parses `"not a url"`
     successfully, percent-encoding the spaces into a relative URL with no scheme and no host, so a
     `guard let` on it lets obvious nonsense through and the failure surfaces later as an opaque
     transport error. Requiring a scheme and a host turns that into an error at the call the caller
     can fix.

     - Parameters:
       - string: The endpoint string.
       - role: What the endpoint is, for the error message (`"algod"` or `"indexer"`).
     - Returns: The parsed URL.
     - Throws: `AlgorandError.invalidURL` if the string is not an absolute http(s) URL.
     */
    internal static func parse(_ string: String, role: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw AlgorandError.invalidURL("Not a valid \(role) base URL: \(string)")
        }
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else {
            throw AlgorandError.invalidURL("\(role) base URL must use http or https: \(string)")
        }
        guard let host = url.host, !host.isEmpty else {
            throw AlgorandError.invalidURL("\(role) base URL has no host: \(string)")
        }
        return url
    }
}
