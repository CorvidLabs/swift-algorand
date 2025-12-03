@preconcurrency import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Client for interacting with an Algorand node (algod)
public actor AlgodClient {
    private let baseURL: URL
    private let apiToken: String?
    private let session: URLSession

    /**
     Creates a new Algod client

     - Parameters:
       - baseURL: The base URL of the algod node (e.g., "https://testnet-api.algonode.cloud")
       - apiToken: Optional API token for authentication
     */
    public init(baseURL: URL, apiToken: String? = nil) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.session = URLSession.shared
    }

    /**
     Creates a new Algod client

     - Parameters:
       - baseURL: The base URL string of the algod node
       - apiToken: Optional API token for authentication
     */
    public init(baseURL: String, apiToken: String? = nil) throws {
        guard let url = URL(string: baseURL) else {
            throw AlgorandError.invalidAddress("Invalid base URL")
        }
        self.init(baseURL: url, apiToken: apiToken)
    }

    // MARK: - Network Status

    /// Gets the current network status
    public func status() async throws -> NodeStatus {
        try await get(path: "/v2/status")
    }

    /// Waits for a block to be committed
    /// - Parameter round: The round to wait for
    public func waitForBlock(round: UInt64) async throws -> NodeStatus {
        try await get(path: "/v2/status/wait-for-block-after/\(round)")
    }

    // MARK: - Transaction Parameters

    /// Gets suggested transaction parameters
    public func transactionParams() async throws -> TransactionParams {
        try await get(path: "/v2/transactions/params")
    }

    // MARK: - Transactions

    /**
     Submits a signed transaction to the network

     - Parameter signedTransaction: The signed transaction to submit
     - Returns: The transaction ID
     */
    public func sendTransaction(_ signedTransaction: SignedTransaction) async throws -> String {
        let encoded = try signedTransaction.encode()

        var request = URLRequest(url: baseURL.appendingPathComponent("/v2/transactions"))
        request.httpMethod = "POST"
        request.httpBody = encoded
        request.setValue("application/x-binary", forHTTPHeaderField: "Content-Type")

        if let apiToken = apiToken {
            request.setValue(apiToken, forHTTPHeaderField: "X-Algo-API-Token")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlgorandError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AlgorandError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        struct Response: Codable {
            let txId: String
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.txId
    }

    /**
     Sends an atomic transaction group

     - Parameter group: The signed atomic transaction group
     - Returns: The transaction ID of the first transaction in the group
     */
    public func sendTransactionGroup(_ group: SignedAtomicTransactionGroup) async throws -> String {
        let encoded = try group.encode()

        var request = URLRequest(url: baseURL.appendingPathComponent("/v2/transactions"))
        request.httpMethod = "POST"
        request.setValue("application/x-binary", forHTTPHeaderField: "Content-Type")
        if let token = apiToken {
            request.setValue(token, forHTTPHeaderField: "X-Algo-API-Token")
        }
        request.httpBody = encoded

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlgorandError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AlgorandError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        struct Response: Codable {
            let txId: String
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.txId
    }

    /// Gets pending transaction information
    /// - Parameter transactionID: The transaction ID
    public func pendingTransaction(_ transactionID: String) async throws -> PendingTransaction {
        try await get(path: "/v2/transactions/pending/\(transactionID)")
    }

    /**
     Waits for a transaction to be confirmed

     - Parameters:
       - transactionID: The transaction ID
       - timeout: Maximum number of rounds to wait (default: 10)
     - Returns: The confirmed transaction
     */
    public func waitForConfirmation(
        transactionID: String,
        timeout: UInt64 = 10
    ) async throws -> PendingTransaction {
        let startRound = try await status().lastRound

        for round in startRound...(startRound + timeout) {
            let pending = try await pendingTransaction(transactionID)

            if pending.confirmedRound != nil {
                return pending
            }

            if let poolError = pending.poolError, !poolError.isEmpty {
                throw AlgorandError.networkError("Transaction pool error: \(poolError)")
            }

            _ = try await waitForBlock(round: round)
        }

        throw AlgorandError.networkError("Transaction not confirmed after \(timeout) rounds")
    }

    // MARK: - Account Information

    /// Gets account information
    /// - Parameter address: The account address
    public func accountInformation(_ address: Address) async throws -> AccountInformation {
        try await get(path: "/v2/accounts/\(address.description)")
    }

    // MARK: - Application State

    /// Gets application global state
    /// - Parameter applicationID: The application ID
    public func applicationInfo(_ applicationID: UInt64) async throws -> ApplicationInfo {
        try await get(path: "/v2/applications/\(applicationID)")
    }

    /**
     Gets application local state for an account

     - Parameters:
       - address: The account address
       - applicationID: The application ID
     */
    public func accountApplicationInfo(_ address: Address, applicationID: UInt64) async throws -> AccountApplicationInfo {
        try await get(path: "/v2/accounts/\(address.description)/applications/\(applicationID)")
    }

    // MARK: - Box Storage

    /// Gets all box names for an application
    /// - Parameter applicationID: The application ID
    /// - Returns: List of box names
    public func applicationBoxes(_ applicationID: UInt64) async throws -> BoxesResponse {
        try await get(path: "/v2/applications/\(applicationID)/boxes")
    }

    /**
     Gets a specific box by name

     - Parameters:
       - applicationID: The application ID
       - name: The box name (base64 encoded)
     */
    public func applicationBox(_ applicationID: UInt64, name: String) async throws -> BoxResponse {
        // URL encode the box name for the query
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return try await get(path: "/v2/applications/\(applicationID)/box?name=b64:\(encodedName)")
    }

    // MARK: - Transaction Simulation

    /// Simulates a transaction or group of transactions
    /// - Parameter request: The simulation request
    /// - Returns: Simulation result
    public func simulateTransaction(_ request: SimulateRequest) async throws -> SimulateResponse {
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("/v2/transactions/simulate"))
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = data
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiToken = apiToken {
            urlRequest.setValue(apiToken, forHTTPHeaderField: "X-Algo-API-Token")
        }

        let (responseData, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlgorandError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw AlgorandError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SimulateResponse.self, from: responseData)
    }

    // MARK: - Asset Information

    /// Gets asset information
    /// - Parameter assetID: The asset ID
    public func assetInfo(_ assetID: UInt64) async throws -> AssetInfo {
        try await get(path: "/v2/assets/\(assetID)")
    }

    // MARK: - Private

    private func get<T: Decodable>(path: String) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"

        if let apiToken = apiToken {
            request.setValue(apiToken, forHTTPHeaderField: "X-Algo-API-Token")
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

/// Node status information
public struct NodeStatus: Codable, Sendable {
    public let lastRound: UInt64
    public let lastVersion: String
    public let nextVersion: String
    public let nextVersionRound: UInt64
    public let nextVersionSupported: Bool
    public let timeSinceLastRound: UInt64
    public let catchupTime: UInt64

    enum CodingKeys: String, CodingKey {
        case lastRound = "last-round"
        case lastVersion = "last-version"
        case nextVersion = "next-version"
        case nextVersionRound = "next-version-round"
        case nextVersionSupported = "next-version-supported"
        case timeSinceLastRound = "time-since-last-round"
        case catchupTime = "catchup-time"
    }
}

/// Pending transaction information
public struct PendingTransaction: Codable, Sendable {
    public let confirmedRound: UInt64?
    public let poolError: String?
    public let txn: TransactionData?
    public let assetIndex: UInt64?
    public let applicationIndex: UInt64?

    enum CodingKeys: String, CodingKey {
        case confirmedRound = "confirmed-round"
        case poolError = "pool-error"
        case txn
        case assetIndex = "asset-index"
        case applicationIndex = "application-index"
    }
}

/// Transaction data from pending transaction response
public struct TransactionData: Codable, Sendable {
    // Add fields as needed
}

/// Account information
public struct AccountInformation: Codable, Sendable {
    public let address: String
    public let amount: UInt64
    public let amountWithoutPendingRewards: UInt64
    public let pendingRewards: UInt64
    public let round: UInt64
    public let status: String
    public let assets: [AssetHolding]?
    public let createdAssets: [CreatedAsset]?
    public let appsLocalState: [ApplicationLocalState]?
    public let createdApps: [CreatedApplication]?
    public let authAddr: String?
    public let minBalance: UInt64?
    public let totalAppsOptedIn: UInt64?
    public let totalAssetsOptedIn: UInt64?
    public let totalCreatedApps: UInt64?
    public let totalCreatedAssets: UInt64?

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case amountWithoutPendingRewards = "amount-without-pending-rewards"
        case pendingRewards = "pending-rewards"
        case round
        case status
        case assets
        case createdAssets = "created-assets"
        case appsLocalState = "apps-local-state"
        case createdApps = "created-apps"
        case authAddr = "auth-addr"
        case minBalance = "min-balance"
        case totalAppsOptedIn = "total-apps-opted-in"
        case totalAssetsOptedIn = "total-assets-opted-in"
        case totalCreatedApps = "total-created-apps"
        case totalCreatedAssets = "total-created-assets"
    }
}

/// Created asset information
public struct CreatedAsset: Codable, Sendable {
    public let index: UInt64
    public let params: AssetParamsResponse

    enum CodingKeys: String, CodingKey {
        case index
        case params
    }
}

/// Asset parameters from API response
public struct AssetParamsResponse: Codable, Sendable {
    public let creator: String
    public let decimals: UInt64
    public let total: UInt64
    public let defaultFrozen: Bool?
    public let unitName: String?
    public let name: String?
    public let url: String?
    public let metadataHash: String?
    public let manager: String?
    public let reserve: String?
    public let freeze: String?
    public let clawback: String?

    enum CodingKeys: String, CodingKey {
        case creator
        case decimals
        case total
        case defaultFrozen = "default-frozen"
        case unitName = "unit-name"
        case name
        case url
        case metadataHash = "metadata-hash"
        case manager
        case reserve
        case freeze
        case clawback
    }
}

/// Application local state for an account
public struct ApplicationLocalState: Codable, Sendable {
    public let id: UInt64
    public let keyValue: [TealKeyValue]?
    public let schema: StateSchemaResponse

    enum CodingKeys: String, CodingKey {
        case id
        case keyValue = "key-value"
        case schema
    }
}

/// Created application information
public struct CreatedApplication: Codable, Sendable {
    public let id: UInt64
    public let params: ApplicationParamsResponse

    enum CodingKeys: String, CodingKey {
        case id
        case params
    }
}

/// Application parameters from API response
public struct ApplicationParamsResponse: Codable, Sendable {
    public let approvalProgram: String
    public let clearStateProgram: String
    public let creator: String
    public let globalState: [TealKeyValue]?
    public let globalStateSchema: StateSchemaResponse?
    public let localStateSchema: StateSchemaResponse?
    public let extraProgramPages: UInt64?

    enum CodingKeys: String, CodingKey {
        case approvalProgram = "approval-program"
        case clearStateProgram = "clear-state-program"
        case creator
        case globalState = "global-state"
        case globalStateSchema = "global-state-schema"
        case localStateSchema = "local-state-schema"
        case extraProgramPages = "extra-program-pages"
    }
}

/// State schema from API response
public struct StateSchemaResponse: Codable, Sendable {
    public let numByteSlice: UInt64
    public let numUint: UInt64

    enum CodingKeys: String, CodingKey {
        case numByteSlice = "num-byte-slice"
        case numUint = "num-uint"
    }
}

/// TEAL key-value pair
public struct TealKeyValue: Codable, Sendable {
    public let key: String
    public let value: TealValue

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

/// TEAL value (can be bytes or uint)
public struct TealValue: Codable, Sendable {
    public let type: UInt64
    public let bytes: String?
    public let uint: UInt64?

    enum CodingKeys: String, CodingKey {
        case type
        case bytes
        case uint
    }
}

/// Application information response
public struct ApplicationInfo: Codable, Sendable {
    public let id: UInt64
    public let params: ApplicationParamsResponse

    enum CodingKeys: String, CodingKey {
        case id
        case params
    }
}

/// Account application information response
public struct AccountApplicationInfo: Codable, Sendable {
    public let appLocalState: ApplicationLocalState?
    public let createdApp: CreatedApplication?
    public let round: UInt64

    enum CodingKeys: String, CodingKey {
        case appLocalState = "app-local-state"
        case createdApp = "created-app"
        case round
    }
}

/// Box names response
public struct BoxesResponse: Codable, Sendable {
    public let boxes: [BoxDescriptor]

    enum CodingKeys: String, CodingKey {
        case boxes
    }
}

/// Box descriptor
public struct BoxDescriptor: Codable, Sendable {
    public let name: String

    enum CodingKeys: String, CodingKey {
        case name
    }
}

/// Box response
public struct BoxResponse: Codable, Sendable {
    public let name: String
    public let value: String
    public let round: UInt64

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case round
    }
}

/// Simulate request
public struct SimulateRequest: Codable, Sendable {
    public let txnGroups: [SimulateRequestTransactionGroup]
    public let allowEmptySignatures: Bool?
    public let allowMoreLogging: Bool?
    public let allowUnnamedResources: Bool?
    public let execTraceConfig: ExecTraceConfig?
    public let extraOpcodeBudget: UInt64?
    public let round: UInt64?

    public init(
        txnGroups: [SimulateRequestTransactionGroup],
        allowEmptySignatures: Bool? = nil,
        allowMoreLogging: Bool? = nil,
        allowUnnamedResources: Bool? = nil,
        execTraceConfig: ExecTraceConfig? = nil,
        extraOpcodeBudget: UInt64? = nil,
        round: UInt64? = nil
    ) {
        self.txnGroups = txnGroups
        self.allowEmptySignatures = allowEmptySignatures
        self.allowMoreLogging = allowMoreLogging
        self.allowUnnamedResources = allowUnnamedResources
        self.execTraceConfig = execTraceConfig
        self.extraOpcodeBudget = extraOpcodeBudget
        self.round = round
    }

    enum CodingKeys: String, CodingKey {
        case txnGroups = "txn-groups"
        case allowEmptySignatures = "allow-empty-signatures"
        case allowMoreLogging = "allow-more-logging"
        case allowUnnamedResources = "allow-unnamed-resources"
        case execTraceConfig = "exec-trace-config"
        case extraOpcodeBudget = "extra-opcode-budget"
        case round
    }
}

/// Simulate request transaction group
public struct SimulateRequestTransactionGroup: Codable, Sendable {
    public let txns: [String]  // Base64-encoded signed transactions

    public init(txns: [String]) {
        self.txns = txns
    }

    enum CodingKeys: String, CodingKey {
        case txns
    }
}

/// Execution trace configuration
public struct ExecTraceConfig: Codable, Sendable {
    public let enable: Bool?
    public let scratchChange: Bool?
    public let stackChange: Bool?
    public let stateChange: Bool?

    public init(
        enable: Bool? = nil,
        scratchChange: Bool? = nil,
        stackChange: Bool? = nil,
        stateChange: Bool? = nil
    ) {
        self.enable = enable
        self.scratchChange = scratchChange
        self.stackChange = stackChange
        self.stateChange = stateChange
    }

    enum CodingKeys: String, CodingKey {
        case enable
        case scratchChange = "scratch-change"
        case stackChange = "stack-change"
        case stateChange = "state-change"
    }
}

/// Simulate response
public struct SimulateResponse: Codable, Sendable {
    public let txnGroups: [SimulateTransactionGroupResult]
    public let lastRound: UInt64
    public let version: UInt64
    public let evalOverrides: EvalOverrides?
    public let execTraceConfig: ExecTraceConfig?
    public let initialStates: InitialStates?

    enum CodingKeys: String, CodingKey {
        case txnGroups = "txn-groups"
        case lastRound = "last-round"
        case version
        case evalOverrides = "eval-overrides"
        case execTraceConfig = "exec-trace-config"
        case initialStates = "initial-states"
    }
}

/// Simulate transaction group result
public struct SimulateTransactionGroupResult: Codable, Sendable {
    public let txnResults: [SimulateTransactionResult]
    public let failedAt: [UInt64]?
    public let failureMessage: String?
    public let appBudgetAdded: UInt64?
    public let appBudgetConsumed: UInt64?
    public let unnamedResourcesAccessed: UnnamedResourcesAccessed?

    enum CodingKeys: String, CodingKey {
        case txnResults = "txn-results"
        case failedAt = "failed-at"
        case failureMessage = "failure-message"
        case appBudgetAdded = "app-budget-added"
        case appBudgetConsumed = "app-budget-consumed"
        case unnamedResourcesAccessed = "unnamed-resources-accessed"
    }
}

/// Simulate transaction result
public struct SimulateTransactionResult: Codable, Sendable {
    public let txnResult: PendingTransaction
    public let appBudgetConsumed: UInt64?
    public let logicSigBudgetConsumed: UInt64?
    public let execTrace: SimulationTransactionExecTrace?
    public let unnamedResourcesAccessed: UnnamedResourcesAccessed?

    enum CodingKeys: String, CodingKey {
        case txnResult = "txn-result"
        case appBudgetConsumed = "app-budget-consumed"
        case logicSigBudgetConsumed = "logic-sig-budget-consumed"
        case execTrace = "exec-trace"
        case unnamedResourcesAccessed = "unnamed-resources-accessed"
    }
}

/// Evaluation overrides
public struct EvalOverrides: Codable, Sendable {
    public let allowEmptySignatures: Bool?
    public let allowUnnamedResources: Bool?
    public let extraOpcodeBudget: UInt64?
    public let maxLogCalls: UInt64?
    public let maxLogSize: UInt64?

    enum CodingKeys: String, CodingKey {
        case allowEmptySignatures = "allow-empty-signatures"
        case allowUnnamedResources = "allow-unnamed-resources"
        case extraOpcodeBudget = "extra-opcode-budget"
        case maxLogCalls = "max-log-calls"
        case maxLogSize = "max-log-size"
    }
}

/// Initial states for simulation
public struct InitialStates: Codable, Sendable {
    public let appInitialStates: [ApplicationInitialStates]?

    enum CodingKeys: String, CodingKey {
        case appInitialStates = "app-initial-states"
    }
}

/// Application initial states
public struct ApplicationInitialStates: Codable, Sendable {
    public let id: UInt64
    public let appBoxes: ApplicationKVDelta?
    public let appGlobals: ApplicationKVDelta?
    public let appLocals: [ApplicationKVDelta]?

    enum CodingKeys: String, CodingKey {
        case id
        case appBoxes = "app-boxes"
        case appGlobals = "app-globals"
        case appLocals = "app-locals"
    }
}

/// Application key-value delta
public struct ApplicationKVDelta: Codable, Sendable {
    public let account: String?
    public let kvs: [AvmKeyValue]?

    enum CodingKeys: String, CodingKey {
        case account
        case kvs
    }
}

/// AVM key-value pair
public struct AvmKeyValue: Codable, Sendable {
    public let key: String
    public let value: AvmValue

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

/// AVM value
public struct AvmValue: Codable, Sendable {
    public let type: UInt64
    public let bytes: String?
    public let uint: UInt64?

    enum CodingKeys: String, CodingKey {
        case type
        case bytes
        case uint
    }
}

/// Unnamed resources accessed during simulation
public struct UnnamedResourcesAccessed: Codable, Sendable {
    public let accounts: [String]?
    public let appLocals: [ApplicationLocalReference]?
    public let apps: [UInt64]?
    public let assetHoldings: [AssetHoldingReference]?
    public let assets: [UInt64]?
    public let boxes: [BoxReference]?
    public let extraBoxRefs: UInt64?

    enum CodingKeys: String, CodingKey {
        case accounts
        case appLocals = "app-locals"
        case apps
        case assetHoldings = "asset-holdings"
        case assets
        case boxes
        case extraBoxRefs = "extra-box-refs"
    }
}

/// Application local reference
public struct ApplicationLocalReference: Codable, Sendable {
    public let account: String
    public let app: UInt64

    enum CodingKeys: String, CodingKey {
        case account
        case app
    }
}

/// Asset holding reference
public struct AssetHoldingReference: Codable, Sendable {
    public let account: String
    public let asset: UInt64

    enum CodingKeys: String, CodingKey {
        case account
        case asset
    }
}

/// Box reference
public struct BoxReference: Codable, Sendable {
    public let app: UInt64
    public let name: String

    enum CodingKeys: String, CodingKey {
        case app
        case name
    }
}

/// Simulation transaction execution trace
public struct SimulationTransactionExecTrace: Codable, Sendable {
    public let approvalProgramHash: String?
    public let approvalProgramTrace: [SimulationOpcodeTraceUnit]?
    public let clearStateProgramHash: String?
    public let clearStateProgramTrace: [SimulationOpcodeTraceUnit]?
    public let clearStateRollback: Bool?
    public let clearStateRollbackError: String?
    public let innerTrace: [SimulationTransactionExecTrace]?
    public let logicSigHash: String?
    public let logicSigTrace: [SimulationOpcodeTraceUnit]?

    enum CodingKeys: String, CodingKey {
        case approvalProgramHash = "approval-program-hash"
        case approvalProgramTrace = "approval-program-trace"
        case clearStateProgramHash = "clear-state-program-hash"
        case clearStateProgramTrace = "clear-state-program-trace"
        case clearStateRollback = "clear-state-rollback"
        case clearStateRollbackError = "clear-state-rollback-error"
        case innerTrace = "inner-trace"
        case logicSigHash = "logic-sig-hash"
        case logicSigTrace = "logic-sig-trace"
    }
}

/// Simulation opcode trace unit
public struct SimulationOpcodeTraceUnit: Codable, Sendable {
    public let pc: UInt64
    public let scratchChanges: [ScratchChange]?
    public let spawnedInners: [UInt64]?
    public let stackAdditions: [AvmValue]?
    public let stackPopCount: UInt64?
    public let stateChanges: [ApplicationStateOperation]?

    enum CodingKeys: String, CodingKey {
        case pc
        case scratchChanges = "scratch-changes"
        case spawnedInners = "spawned-inners"
        case stackAdditions = "stack-additions"
        case stackPopCount = "stack-pop-count"
        case stateChanges = "state-changes"
    }
}

/// Scratch change during simulation
public struct ScratchChange: Codable, Sendable {
    public let newValue: AvmValue
    public let slot: UInt64

    enum CodingKeys: String, CodingKey {
        case newValue = "new-value"
        case slot
    }
}

/// Application state operation during simulation
public struct ApplicationStateOperation: Codable, Sendable {
    public let appStateType: String
    public let key: String
    public let newValue: AvmValue?
    public let operation: String
    public let account: String?

    enum CodingKeys: String, CodingKey {
        case appStateType = "app-state-type"
        case key
        case newValue = "new-value"
        case operation
        case account
    }
}

/// Asset information response
public struct AssetInfo: Codable, Sendable {
    public let index: UInt64
    public let params: AssetParamsResponse

    enum CodingKeys: String, CodingKey {
        case index
        case params
    }
}

/// Asset holding information
public struct AssetHolding: Codable, Sendable {
    public let assetID: UInt64
    public let amount: UInt64
    public let isFrozen: Bool

    enum CodingKeys: String, CodingKey {
        case assetID = "asset-id"
        case amount
        case isFrozen = "is-frozen"
    }
}
