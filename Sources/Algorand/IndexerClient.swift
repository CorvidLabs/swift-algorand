@preconcurrency import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Client for querying blockchain data from an Algorand indexer
public actor IndexerClient {
    private let baseURL: URL
    private let apiToken: String?
    /// The session every request on this client uses.
    ///
    /// Deliberately NOT `URLSession.shared`. The shared session is process-wide
    /// and has a bounded connection pool; on Linux, once that pool is saturated
    /// it *queues* rather than erroring, so an untimed request on it can wait
    /// indefinitely. A caller doing unrelated bulk work on `URLSession.shared`
    /// could therefore hang every call made through this client, and a caller
    /// doing bulk work through this client could hang everything else.
    ///
    /// A dedicated session with real deadlines makes a slow or unreachable node
    /// fail its own request instead of starving the process.
    private let session: URLSession

    /// Applied per-request as well as on the configuration: on Linux the
    /// per-request value is the one consistently honoured.
    private let requestTimeout: TimeInterval

    /**
     Creates a new Indexer client

     - Parameters:
       - baseURL: The base URL of the indexer (e.g., "https://testnet-idx.algonode.cloud")
       - apiToken: Optional API token for authentication
       - requestTimeout: Deadline for a single request. Defaults to 30s.
       - resourceTimeout: Deadline for the whole transfer. Defaults to 60s.
     */
    public init(
        baseURL: URL,
        apiToken: String? = nil,
        requestTimeout: TimeInterval = 30,
        resourceTimeout: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.requestTimeout = requestTimeout
        self.session = Self.makeSession(
            requestTimeout: requestTimeout,
            resourceTimeout: resourceTimeout
        )
    }

    /// Builds the client's dedicated session.
    ///
    /// `timeoutIntervalForRequest` bounds the gap between packets;
    /// `timeoutIntervalForResource` bounds the whole transfer. Both are needed:
    /// a node that trickles bytes forever satisfies the first and not the second.
    private static func makeSession(
        requestTimeout: TimeInterval,
        resourceTimeout: TimeInterval
    ) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        // Only settable on Apple platforms: in swift-corelibs-foundation this
        // property is get-only and assigning to it does not compile. That is
        // unfortunate, because Linux is exactly where it would help most - the
        // default behaviour can wait for a usable network path instead of
        // failing, which is close to the hang this timeout work exists to kill.
        // The two timeouts above still bound that wait on every platform.
        #if canImport(Darwin)
            configuration.waitsForConnectivity = false
        #endif
        return URLSession(configuration: configuration)
    }

    /// Releases the dedicated session when the client goes away.
    ///
    /// A custom `URLSession` is not `URLSession.shared`: it holds its connection
    /// pool and its delegate queue until invalidated, so a caller that creates
    /// clients repeatedly would accumulate them for the life of the process.
    /// `invalidateAndCancel()` rather than `finishTasksAndInvalidate()` because
    /// a discarded client has no one left to receive its responses.
    deinit {
        session.invalidateAndCancel()
    }


    /**
     Creates a new Indexer client

     - Parameters:
       - baseURL: The base URL string of the indexer
       - apiToken: Optional API token for authentication
     - Throws: `AlgorandError.invalidURL` if `baseURL` is not an absolute http(s) URL
     */
    public init(
        baseURL: String,
        apiToken: String? = nil,
        requestTimeout: TimeInterval = 30,
        resourceTimeout: TimeInterval = 60
    ) throws {
        let url = try EndpointURL.parse(baseURL, role: "indexer")
        self.init(
            baseURL: url,
            apiToken: apiToken,
            requestTimeout: requestTimeout,
            resourceTimeout: resourceTimeout
        )
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
        let accountsURL = baseURL.appendingPathComponent("/v2/accounts")
        guard var components = URLComponents(url: accountsURL, resolvingAgainstBaseURL: false) else {
            throw AlgorandError.invalidURL("Could not build URL components for accounts search")
        }
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
        request.timeoutInterval = requestTimeout
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

    /// The asset's parameters, in the same model algod returns for `GET /v2/assets/{id}`.
    ///
    /// The `0.3.x` line declared a nested `IndexerAsset.AssetParams` carrying four of the twelve
    /// fields, which discarded the creator, the role addresses, the URL, and the metadata hash,
    /// and shadowed the top-level ``AssetParams`` - the asset *creation* parameters - anywhere
    /// inside `IndexerAsset`. The indexer's asset parameters are go-algorand's `model.AssetParams`,
    /// the object ``AssetParamsResponse`` already decodes.
    public let params: AssetParamsResponse

    /// The nested name the `0.3.x` line gave the indexer's asset parameters.
    @available(
        *,
        deprecated,
        renamed: "AssetParamsResponse",
        message: "IndexerAsset.params is an AssetParamsResponse, the same model algod returns"
    )
    public typealias AssetParams = AssetParamsResponse

    enum CodingKeys: String, CodingKey {
        case index
        case params
    }
}

/**
 Block response

 The block header as the indexer returns it from `GET /v2/blocks/{round}`, with the block's
 transactions decoded through ``IndexerTransaction``. The `0.3.x` `BlockResponse` was an empty
 struct: ``IndexerClient/block(_:)`` decoded successfully and returned nothing at all.
 */
public struct BlockResponse: Codable, Sendable {
    /// The round this block belongs to.
    public let round: UInt64

    /// The block's creation time, in seconds since the Unix epoch.
    public let timestamp: UInt64?

    /// The genesis ID of the network.
    public let genesisID: String?

    /// The genesis hash of the network, base64-encoded.
    public let genesisHash: String?

    /// The hash of the previous block, base64-encoded.
    public let previousBlockHash: String?

    /// The sortition seed, base64-encoded.
    public let seed: String?

    /// The root of the transaction commitment tree, base64-encoded.
    public let transactionsRoot: String?

    /// The SHA-256 root of the transaction commitment tree, base64-encoded.
    public let transactionsRootSha256: String?

    /// The number of transactions in the ledger through this block.
    public let txnCounter: UInt64?

    /// The block proposer, present from consensus v41 onward.
    public let proposer: String?

    /// The block's transactions, when the indexer includes them.
    public let transactions: [IndexerTransaction]?

    enum CodingKeys: String, CodingKey {
        case round
        case timestamp
        case genesisID = "genesis-id"
        case genesisHash = "genesis-hash"
        case previousBlockHash = "previous-block-hash"
        case seed
        case transactionsRoot = "transactions-root"
        case transactionsRootSha256 = "transactions-root-sha256"
        case txnCounter = "txn-counter"
        case proposer
        case transactions
    }
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
