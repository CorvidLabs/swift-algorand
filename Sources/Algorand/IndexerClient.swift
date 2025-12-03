@preconcurrency import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Client for querying blockchain data from an Algorand indexer
public actor IndexerClient {
    private let baseURL: URL
    private let apiToken: String?
    private let session: URLSession

    /**
     Creates a new Indexer client

     - Parameters:
       - baseURL: The base URL of the indexer (e.g., "https://testnet-idx.algonode.cloud")
       - apiToken: Optional API token for authentication
     */
    public init(baseURL: URL, apiToken: String? = nil) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.session = URLSession.shared
    }

    /**
     Creates a new Indexer client

     - Parameters:
       - baseURL: The base URL string of the indexer
       - apiToken: Optional API token for authentication
     */
    public init(baseURL: String, apiToken: String? = nil) throws {
        guard let url = URL(string: baseURL) else {
            throw AlgorandError.invalidAddress("Invalid base URL")
        }
        self.init(baseURL: url, apiToken: apiToken)
    }

    // MARK: - Health Check

    /// Gets the health status of the indexer
    public func health() async throws -> HealthStatus {
        try await get(path: "/health")
    }

    // MARK: - Accounts

    /**
     Searches for accounts

     - Parameters:
       - limit: Maximum number of results (default: 100)
       - next: Token for pagination
       - currencyGreaterThan: Filter by minimum balance
       - currencyLessThan: Filter by maximum balance
     */
    public func searchAccounts(
        limit: Int = 100,
        next: String? = nil,
        currencyGreaterThan: UInt64? = nil,
        currencyLessThan: UInt64? = nil
    ) async throws -> AccountsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/v2/accounts"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let next = next {
            queryItems.append(URLQueryItem(name: "next", value: next))
        }
        if let currencyGreaterThan = currencyGreaterThan {
            queryItems.append(URLQueryItem(name: "currency-greater-than", value: "\(currencyGreaterThan)"))
        }
        if let currencyLessThan = currencyLessThan {
            queryItems.append(URLQueryItem(name: "currency-less-than", value: "\(currencyLessThan)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw AlgorandError.networkError("Failed to construct URL for accounts search")
        }
        return try await get(url: url)
    }

    /// Gets account information by address
    /// - Parameter address: The account address
    public func account(_ address: Address) async throws -> AccountResponse {
        try await get(path: "/v2/accounts/\(address.description)")
    }

    // MARK: - Transactions

    /**
     Searches for transactions

     - Parameters:
       - address: Filter by address
       - limit: Maximum number of results (default: 100)
       - next: Token for pagination
       - minRound: Minimum round
       - maxRound: Maximum round
     */
    public func searchTransactions(
        address: Address? = nil,
        limit: Int = 100,
        next: String? = nil,
        minRound: UInt64? = nil,
        maxRound: UInt64? = nil
    ) async throws -> TransactionsResponse {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/v2/transactions"), resolvingAgainstBaseURL: false) else {
            throw AlgorandError.networkError("Failed to construct URL components for transactions search")
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let address = address {
            queryItems.append(URLQueryItem(name: "address", value: address.description))
        }
        if let next = next {
            queryItems.append(URLQueryItem(name: "next", value: next))
        }
        if let minRound = minRound {
            queryItems.append(URLQueryItem(name: "min-round", value: "\(minRound)"))
        }
        if let maxRound = maxRound {
            queryItems.append(URLQueryItem(name: "max-round", value: "\(maxRound)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw AlgorandError.networkError("Failed to construct URL for transactions search")
        }
        return try await get(url: url)
    }

    /// Gets a transaction by ID
    /// - Parameter transactionID: The transaction ID
    public func transaction(_ transactionID: String) async throws -> TransactionResponse {
        try await get(path: "/v2/transactions/\(transactionID)")
    }

    // MARK: - Assets

    /**
     Searches for assets

     - Parameters:
       - limit: Maximum number of results (default: 100)
       - next: Token for pagination
       - name: Filter by name
       - unit: Filter by unit name
     */
    public func searchAssets(
        limit: Int = 100,
        next: String? = nil,
        name: String? = nil,
        unit: String? = nil
    ) async throws -> AssetsResponse {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/v2/assets"), resolvingAgainstBaseURL: false) else {
            throw AlgorandError.networkError("Failed to construct URL components for assets search")
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let next = next {
            queryItems.append(URLQueryItem(name: "next", value: next))
        }
        if let name = name {
            queryItems.append(URLQueryItem(name: "name", value: name))
        }
        if let unit = unit {
            queryItems.append(URLQueryItem(name: "unit", value: unit))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw AlgorandError.networkError("Failed to construct URL for assets search")
        }
        return try await get(url: url)
    }

    /// Gets asset information by ID
    /// - Parameter assetID: The asset ID
    public func asset(_ assetID: UInt64) async throws -> AssetResponse {
        try await get(path: "/v2/assets/\(assetID)")
    }

    // MARK: - Applications

    /// Gets application information by ID
    /// - Parameter appID: The application ID
    public func application(_ appID: UInt64) async throws -> ApplicationResponse {
        try await get(path: "/v2/applications/\(appID)")
    }

    /**
     Searches for applications

     - Parameters:
       - limit: Maximum number of results (default: 100)
       - next: Token for pagination
       - applicationID: Filter by application ID
     */
    public func searchApplications(
        limit: Int = 100,
        next: String? = nil,
        applicationID: UInt64? = nil
    ) async throws -> ApplicationsResponse {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/v2/applications"), resolvingAgainstBaseURL: false) else {
            throw AlgorandError.networkError("Failed to construct URL components for applications search")
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let next = next {
            queryItems.append(URLQueryItem(name: "next", value: next))
        }
        if let applicationID = applicationID {
            queryItems.append(URLQueryItem(name: "application-id", value: "\(applicationID)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw AlgorandError.networkError("Failed to construct URL for applications search")
        }
        return try await get(url: url)
    }

    // MARK: - Blocks

    /// Gets a block by round
    /// - Parameter round: The round number
    public func block(_ round: UInt64) async throws -> BlockResponse {
        try await get(path: "/v2/blocks/\(round)")
    }

    // MARK: - Private Methods

    private func get<T: Decodable>(path: String) async throws -> T {
        try await get(url: baseURL.appendingPathComponent(path))
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let apiToken = apiToken {
            request.setValue(apiToken, forHTTPHeaderField: "X-Indexer-API-Token")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlgorandError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AlgorandError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Response Types

/// Health status response
public struct HealthStatus: Codable, Sendable {
    public let version: String
    public let round: UInt64
    public let isMigrating: Bool
    public let dbAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case version
        case round
        case isMigrating = "is-migrating"
        case dbAvailable = "db-available"
    }
}

/// Accounts search response
public struct AccountsResponse: Codable, Sendable {
    public let accounts: [IndexerAccount]
    public let currentRound: UInt64
    public let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case accounts
        case currentRound = "current-round"
        case nextToken = "next-token"
    }
}

/// Account response
public struct AccountResponse: Codable, Sendable {
    public let account: IndexerAccount
    public let currentRound: UInt64

    enum CodingKeys: String, CodingKey {
        case account
        case currentRound = "current-round"
    }
}

/// Account information from indexer
public struct IndexerAccount: Codable, Sendable {
    public let address: String
    public let amount: UInt64
    public let amountWithoutPendingRewards: UInt64
    public let pendingRewards: UInt64
    public let round: UInt64
    public let status: String

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case amountWithoutPendingRewards = "amount-without-pending-rewards"
        case pendingRewards = "pending-rewards"
        case round
        case status
    }
}

/// Transactions search response
public struct TransactionsResponse: Codable, Sendable {
    public let transactions: [IndexerTransaction]
    public let currentRound: UInt64
    public let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case transactions
        case currentRound = "current-round"
        case nextToken = "next-token"
    }
}

/// Transaction response
public struct TransactionResponse: Codable, Sendable {
    public let transaction: IndexerTransaction
    public let currentRound: UInt64

    enum CodingKeys: String, CodingKey {
        case transaction
        case currentRound = "current-round"
    }
}

/// Transaction from indexer
public struct IndexerTransaction: Codable, Sendable {
    public let id: String
    public let confirmedRound: UInt64?
    public let roundTime: UInt64?
    public let sender: String
    public let fee: UInt64
    public let txType: String
    private let note: String?  // base64-encoded
    public let paymentTransaction: PaymentTransactionDetails?
    public let assetTransferTransaction: AssetTransferTransactionDetails?
    public let assetConfigTransaction: AssetConfigTransactionDetails?

    /// Decoded note as Data
    public var noteData: Data? {
        guard let note = note else { return nil }
        return Data(base64Encoded: note)
    }

    /// Decoded note as UTF-8 string
    public var noteString: String? {
        guard let data = noteData else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case confirmedRound = "confirmed-round"
        case roundTime = "round-time"
        case sender
        case fee
        case txType = "tx-type"
        case note
        case paymentTransaction = "payment-transaction"
        case assetTransferTransaction = "asset-transfer-transaction"
        case assetConfigTransaction = "asset-config-transaction"
    }

    public struct PaymentTransactionDetails: Codable, Sendable {
        public let receiver: String
        public let amount: UInt64
        public let closeAmount: UInt64?

        enum CodingKeys: String, CodingKey {
            case receiver
            case amount
            case closeAmount = "close-amount"
        }
    }

    public struct AssetTransferTransactionDetails: Codable, Sendable {
        public let assetID: UInt64
        public let amount: UInt64
        public let receiver: String
        public let closeAmount: UInt64?

        enum CodingKeys: String, CodingKey {
            case assetID = "asset-id"
            case amount
            case receiver
            case closeAmount = "close-amount"
        }
    }

    public struct AssetConfigTransactionDetails: Codable, Sendable {
        public let assetID: UInt64?
        public let params: AssetConfigParams?

        enum CodingKeys: String, CodingKey {
            case assetID = "asset-id"
            case params
        }

        public struct AssetConfigParams: Codable, Sendable {
            public let name: String?
            public let unitName: String?
            public let total: UInt64?
            public let decimals: UInt64?

            enum CodingKeys: String, CodingKey {
                case name
                case unitName = "unit-name"
                case total
                case decimals
            }
        }
    }
}

/// Assets search response
public struct AssetsResponse: Codable, Sendable {
    public let assets: [IndexerAsset]
    public let currentRound: UInt64
    public let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case assets
        case currentRound = "current-round"
        case nextToken = "next-token"
    }
}

/// Asset response
public struct AssetResponse: Codable, Sendable {
    public let asset: IndexerAsset
    public let currentRound: UInt64

    enum CodingKeys: String, CodingKey {
        case asset
        case currentRound = "current-round"
    }
}

/// Asset from indexer
public struct IndexerAsset: Codable, Sendable {
    public let index: UInt64
    public let params: AssetParams

    public struct AssetParams: Codable, Sendable {
        public let name: String?
        public let unitName: String?
        public let total: UInt64
        public let decimals: UInt64

        enum CodingKeys: String, CodingKey {
            case name
            case unitName = "unit-name"
            case total
            case decimals
        }
    }
}

/// Block response
public struct BlockResponse: Codable, Sendable {
    // Add block fields as needed
}

/// Application response
public struct ApplicationResponse: Codable, Sendable {
    public let application: IndexerApplication
    public let currentRound: UInt64

    enum CodingKeys: String, CodingKey {
        case application
        case currentRound = "current-round"
    }
}

/// Applications search response
public struct ApplicationsResponse: Codable, Sendable {
    public let applications: [IndexerApplication]
    public let currentRound: UInt64
    public let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case applications
        case currentRound = "current-round"
        case nextToken = "next-token"
    }
}

/// Application from indexer
public struct IndexerApplication: Codable, Sendable {
    public let id: UInt64
    public let params: ApplicationParams
    public let createdAtRound: UInt64?
    public let deletedAtRound: UInt64?
    public let deleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case params
        case createdAtRound = "created-at-round"
        case deletedAtRound = "deleted-at-round"
        case deleted
    }

    public struct ApplicationParams: Codable, Sendable {
        public let creator: String
        public let approvalProgram: String?
        public let clearStateProgram: String?
        public let globalStateSchema: StateSchemaInfo?
        public let localStateSchema: StateSchemaInfo?

        enum CodingKeys: String, CodingKey {
            case creator
            case approvalProgram = "approval-program"
            case clearStateProgram = "clear-state-program"
            case globalStateSchema = "global-state-schema"
            case localStateSchema = "local-state-schema"
        }

        public struct StateSchemaInfo: Codable, Sendable {
            public let numUint: UInt64
            public let numByteSlice: UInt64

            enum CodingKeys: String, CodingKey {
                case numUint = "num-uint"
                case numByteSlice = "num-byte-slice"
            }
        }
    }
}
