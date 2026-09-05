@preconcurrency import Foundation

/**
 Configuration for the Algorand client.

 ``algodURL`` and ``indexerURL`` are resolved once, when the configuration is created, and stored.
 Foundation has no total constructor for an `http` URL, so the well-known endpoint literals are
 parsed through a throwing path rather than force-unwrapped: the failure cannot happen for the
 endpoints this SDK ships, and a test asserts that, but the throw is what keeps every code path
 free of traps.
 */
public struct AlgorandConfiguration: Sendable {
    /// Predefined network configurations
    public enum Network: Sendable {
        case localnet
        case testnet
        case mainnet
        case custom(algodURL: URL, indexerURL: URL?)
    }

    /// The API token AlgoKit's localnet accepts: 64 `a` characters.
    public static let defaultLocalnetAPIToken = String(repeating: "a", count: 64)

    /// The network to connect to
    public let network: Network

    /// Optional API token for authentication
    public let apiToken: String?

    /// The algod node URL for this configuration
    public let algodURL: URL

    /// The indexer URL for this configuration (if available)
    public let indexerURL: URL?

    /**
     Creates a configuration for the specified network

     - Parameters:
       - network: The network to connect to
       - apiToken: Optional API token for authentication
     - Throws: `AlgorandError.invalidURL` if a built-in endpoint literal cannot be parsed, which
       cannot happen for the endpoints this SDK ships
     */
    public init(network: Network, apiToken: String? = nil) throws {
        self.network = network
        self.apiToken = apiToken

        switch network {
        case .localnet:
            self.algodURL = try Endpoint.localnetAlgod.resolve()
            self.indexerURL = try Endpoint.localnetIndexer.resolve()
        case .testnet:
            self.algodURL = try Endpoint.testnetAlgod.resolve()
            self.indexerURL = try Endpoint.testnetIndexer.resolve()
        case .mainnet:
            self.algodURL = try Endpoint.mainnetAlgod.resolve()
            self.indexerURL = try Endpoint.mainnetIndexer.resolve()
        case .custom(let algodURL, let indexerURL):
            self.algodURL = algodURL
            self.indexerURL = indexerURL
        }
    }

    /// Memberwise path for configurations whose URLs the caller already holds.
    private init(network: Network, apiToken: String?, algodURL: URL, indexerURL: URL?) {
        self.network = network
        self.apiToken = apiToken
        self.algodURL = algodURL
        self.indexerURL = indexerURL
    }

    // MARK: - Static Factory Methods

    /// Creates a configuration for localnet (AlgoKit local development)
    /// - Parameter apiToken: Optional API token (default: ``defaultLocalnetAPIToken``)
    /// - Throws: `AlgorandError.invalidURL` if a built-in endpoint literal cannot be parsed
    public static func localnet(
        apiToken: String? = AlgorandConfiguration.defaultLocalnetAPIToken
    ) throws -> AlgorandConfiguration {
        try AlgorandConfiguration(network: .localnet, apiToken: apiToken)
    }

    /// Creates a configuration for testnet (AlgoNode public endpoint)
    /// - Parameter apiToken: Optional API token for authentication
    /// - Throws: `AlgorandError.invalidURL` if a built-in endpoint literal cannot be parsed
    public static func testnet(apiToken: String? = nil) throws -> AlgorandConfiguration {
        try AlgorandConfiguration(network: .testnet, apiToken: apiToken)
    }

    /// Creates a configuration for mainnet (AlgoNode public endpoint)
    /// - Parameter apiToken: Optional API token for authentication
    /// - Throws: `AlgorandError.invalidURL` if a built-in endpoint literal cannot be parsed
    public static func mainnet(apiToken: String? = nil) throws -> AlgorandConfiguration {
        try AlgorandConfiguration(network: .mainnet, apiToken: apiToken)
    }

    /**
     Creates a configuration for custom endpoints

     Not throwing: the caller supplies already-parsed `URL` values, so nothing is left to fail.

     - Parameters:
       - algodURL: The URL of the algod node
       - indexerURL: Optional URL of the indexer
       - apiToken: Optional API token for authentication
     */
    public static func custom(algodURL: URL, indexerURL: URL? = nil, apiToken: String? = nil) -> AlgorandConfiguration {
        AlgorandConfiguration(
            network: .custom(algodURL: algodURL, indexerURL: indexerURL),
            apiToken: apiToken,
            algodURL: algodURL,
            indexerURL: indexerURL
        )
    }

    // MARK: - Built-in Endpoints

    /// The endpoint literals this SDK ships, kept in one place so a test can assert they parse.
    internal enum Endpoint: String, CaseIterable, Sendable {
        case localnetAlgod = "http://localhost:4001"
        case localnetIndexer = "http://localhost:8980"
        case testnetAlgod = "https://testnet-api.algonode.cloud"
        case testnetIndexer = "https://testnet-idx.algonode.cloud"
        case mainnetAlgod = "https://mainnet-api.algonode.cloud"
        case mainnetIndexer = "https://mainnet-idx.algonode.cloud"

        /// Parses the literal.
        /// - Throws: `AlgorandError.invalidURL` if Foundation refuses the literal.
        internal func resolve() throws -> URL {
            guard let url = URL(string: rawValue) else {
                throw AlgorandError.invalidURL("Built-in endpoint is not a valid URL: \(rawValue)")
            }
            return url
        }
    }
}
