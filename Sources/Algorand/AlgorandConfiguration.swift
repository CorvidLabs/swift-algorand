@preconcurrency import Foundation

/// Configuration for the Algorand client.
public struct AlgorandConfiguration: Sendable {
    /// Predefined network configurations
    public enum Network: Sendable {
        case localnet
        case testnet
        case mainnet
        case custom(algodURL: URL, indexerURL: URL?)
    }

    /// The network to connect to
    public let network: Network

    /// Optional API token for authentication
    public let apiToken: String?

    /**
     Creates a configuration for the specified network

     - Parameters:
       - network: The network to connect to
       - apiToken: Optional API token for authentication
     */
    public init(network: Network, apiToken: String? = nil) {
        self.network = network
        self.apiToken = apiToken
    }

    // MARK: - Static Factory Methods

    /// Creates a configuration for localnet (AlgoKit local development)
    /// - Parameter apiToken: Optional API token (default: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    public static func localnet(apiToken: String? = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") -> AlgorandConfiguration {
        AlgorandConfiguration(network: .localnet, apiToken: apiToken)
    }

    /// Creates a configuration for testnet (AlgoNode public endpoint)
    public static func testnet() -> AlgorandConfiguration {
        AlgorandConfiguration(network: .testnet)
    }

    /// Creates a configuration for mainnet (AlgoNode public endpoint)
    public static func mainnet() -> AlgorandConfiguration {
        AlgorandConfiguration(network: .mainnet)
    }

    /**
     Creates a configuration for custom endpoints

     - Parameters:
       - algodURL: The URL of the algod node
       - indexerURL: Optional URL of the indexer
       - apiToken: Optional API token for authentication
     */
    public static func custom(algodURL: URL, indexerURL: URL? = nil, apiToken: String? = nil) -> AlgorandConfiguration {
        AlgorandConfiguration(network: .custom(algodURL: algodURL, indexerURL: indexerURL), apiToken: apiToken)
    }

    // MARK: - URL Computation

    /// The algod node URL for this configuration
    public var algodURL: URL {
        switch network {
        case .localnet:
            return URL(string: "http://localhost:4001")!
        case .testnet:
            return URL(string: "https://testnet-api.algonode.cloud")!
        case .mainnet:
            return URL(string: "https://mainnet-api.algonode.cloud")!
        case .custom(let algodURL, _):
            return algodURL
        }
    }

    /// The indexer URL for this configuration (if available)
    public var indexerURL: URL? {
        switch network {
        case .localnet:
            return URL(string: "http://localhost:8980")
        case .testnet:
            return URL(string: "https://testnet-idx.algonode.cloud")
        case .mainnet:
            return URL(string: "https://mainnet-idx.algonode.cloud")
        case .custom(_, let indexerURL):
            return indexerURL
        }
    }
}
