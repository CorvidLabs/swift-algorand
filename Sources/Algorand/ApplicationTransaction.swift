@preconcurrency import Foundation

/// On-completion action for application transactions
public enum OnCompletion: UInt64, Sendable {
    case noOp = 0
    case optIn = 1
    case closeOut = 2
    case clearState = 3
    case updateApplication = 4
    case deleteApplication = 5
}

/// Application state schema
public struct StateSchema: Sendable {
    /// Number of uints in state
    public let numUint: UInt64

    /// Number of byte slices in state
    public let numByteSlice: UInt64

    public init(numUint: UInt64, numByteSlice: UInt64) {
        self.numUint = numUint
        self.numByteSlice = numByteSlice
    }
}

/// Base application call transaction
public struct ApplicationCallTransaction: Transaction {
    public let sender: Address
    public let applicationID: UInt64
    public let onCompletion: OnCompletion
    public let approvalProgram: Data?
    public let clearStateProgram: Data?
    public let globalStateSchema: StateSchema?
    public let localStateSchema: StateSchema?
    public let appArguments: [Data]?
    public let accounts: [Address]?
    public let foreignApps: [UInt64]?
    public let foreignAssets: [UInt64]?
    /// Box references for this application call, as `(applicationID, boxName)` pairs.
    ///
    /// The `applicationID` names the application that OWNS the box. Both `0` and this call's own
    /// `applicationID` mean "this application" and encode as an omitted index. Any other value is
    /// resolved to a 1-based slot in `foreignApps`, and is appended to `foreignApps` when it is not
    /// already declared there. Encoding throws ``AlgorandError/invalidTransaction(_:)`` when the
    /// resulting foreign-application array would exceed the protocol limit of 8.
    ///
    /// - Note: The node additionally caps combined references (accounts + apps + assets + boxes) at
    ///   8. That limit is not enforced here, so an append may surface as a node-side rejection.
    public let boxes: [(UInt64, Data)]?
    public let extraPages: UInt64?
    public let fee: MicroAlgos
    public let firstValid: UInt64
    public let lastValid: UInt64
    public let genesisID: String
    public let genesisHash: Data
    public let note: Data?
    public let lease: Data?
    public let rekeyTo: Address?

    public init(
        sender: Address,
        applicationID: UInt64,
        onCompletion: OnCompletion = .noOp,
        approvalProgram: Data? = nil,
        clearStateProgram: Data? = nil,
        globalStateSchema: StateSchema? = nil,
        localStateSchema: StateSchema? = nil,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        extraPages: UInt64? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) {
        self.sender = sender
        self.applicationID = applicationID
        self.onCompletion = onCompletion
        self.approvalProgram = approvalProgram
        self.clearStateProgram = clearStateProgram
        self.globalStateSchema = globalStateSchema
        self.localStateSchema = localStateSchema
        self.appArguments = appArguments
        self.accounts = accounts
        self.foreignApps = foreignApps
        self.foreignAssets = foreignAssets
        self.boxes = boxes
        self.extraPages = extraPages
        self.fee = fee
        self.firstValid = firstValid
        self.lastValid = lastValid
        self.genesisID = genesisID
        self.genesisHash = genesisHash
        self.note = note
        self.lease = lease
        self.rekeyTo = rekeyTo
    }

    /**
     Creates an application call from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - applicationID: As in the header-field initializer.
       - onCompletion: As in the header-field initializer.
       - approvalProgram: As in the header-field initializer.
       - clearStateProgram: As in the header-field initializer.
       - globalStateSchema: As in the header-field initializer.
       - localStateSchema: As in the header-field initializer.
       - appArguments: As in the header-field initializer.
       - accounts: As in the header-field initializer.
       - foreignApps: As in the header-field initializer.
       - foreignAssets: As in the header-field initializer.
       - boxes: As in the header-field initializer.
       - extraPages: As in the header-field initializer.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field initializer.
       - lease: As in the header-field initializer.
       - rekeyTo: As in the header-field initializer.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public init(
        sender: Address,
        applicationID: UInt64,
        onCompletion: OnCompletion = .noOp,
        approvalProgram: Data? = nil,
        clearStateProgram: Data? = nil,
        globalStateSchema: StateSchema? = nil,
        localStateSchema: StateSchema? = nil,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        extraPages: UInt64? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: onCompletion,
            approvalProgram: approvalProgram,
            clearStateProgram: clearStateProgram,
            globalStateSchema: globalStateSchema,
            localStateSchema: localStateSchema,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            extraPages: extraPages,
            fee: MicroAlgos(params.minFee),
            firstValid: window.first,
            lastValid: window.last,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
        self.init(
            sender: sender,
            applicationID: applicationID,
            onCompletion: onCompletion,
            approvalProgram: approvalProgram,
            clearStateProgram: clearStateProgram,
            globalStateSchema: globalStateSchema,
            localStateSchema: localStateSchema,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            extraPages: extraPages,
            fee: try fee.fee(for: draft, params: params),
            firstValid: window.first,
            lastValid: window.last,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Encodes the transaction to canonical MessagePack format for signing

     Box references are translated from the application IDs the caller supplied into the positional
     form the network expects, which may extend the foreign-application array.

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.invalidTransaction` if a box reference cannot be resolved, or
       `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        let boxReferences = try CanonicalBoxReferences(
            boxes: boxes ?? [],
            applicationID: applicationID,
            foreignApplications: foreignApps ?? []
        )

        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "appl",
            sender: sender,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo,
            groupID: groupID
        )

        fields.set("apid", uint: applicationID)
        fields.set("apan", uint: onCompletion.rawValue)
        fields.set("apap", blob: approvalProgram)
        fields.set("apsu", blob: clearStateProgram)
        fields.set("apgs", map: Self.schemaFields(globalStateSchema))
        fields.set("apls", map: Self.schemaFields(localStateSchema))
        fields.set("apaa", array: (appArguments ?? []).map { .binary($0) })
        fields.set("apat", array: (accounts ?? []).map { .binary($0.bytes) })
        fields.set("apfa", array: boxReferences.foreignApplications.map { .uint($0) })
        fields.set("apas", array: (foreignAssets ?? []).map { .uint($0) })
        fields.set("apbx", array: boxReferences.references.map(Self.boxValue))
        fields.set("apep", uint: extraPages ?? 0)

        return try fields.encoded()
    }

    // MARK: - Private Methods

    /// Builds the nested `apgs` / `apls` map, which is omitted when both counts are zero.
    private static func schemaFields(_ schema: StateSchema?) -> CanonicalTransactionFields {
        var fields = CanonicalTransactionFields()
        fields.set("nui", uint: schema?.numUint ?? 0)
        fields.set("nbs", uint: schema?.numByteSlice ?? 0)
        return fields
    }

    /// Builds one `apbx` element. Unlike the schemas, an all-zero box reference is still emitted,
    /// as an empty map, because the array elements themselves are not subject to omission.
    private static func boxValue(_ reference: CanonicalBoxReferences.Reference) -> MessagePackValue {
        var fields = CanonicalTransactionFields()
        fields.set("i", uint: reference.index)
        fields.set("n", blob: reference.name)
        return fields.mapValue
    }
}

// MARK: - Convenience Constructors

extension ApplicationCallTransaction {
    /// Creates an application (applicationID = 0)
    public static func create(
        sender: Address,
        approvalProgram: Data,
        clearStateProgram: Data,
        globalStateSchema: StateSchema,
        localStateSchema: StateSchema,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        extraPages: UInt64? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> ApplicationCallTransaction {
        return ApplicationCallTransaction(
            sender: sender,
            applicationID: 0,
            onCompletion: .noOp,
            approvalProgram: approvalProgram,
            clearStateProgram: clearStateProgram,
            globalStateSchema: globalStateSchema,
            localStateSchema: localStateSchema,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            extraPages: extraPages,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Creates an application (applicationID = 0) from suggested parameters, pricing its fee with a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - approvalProgram: As in the header-field factory.
       - clearStateProgram: As in the header-field factory.
       - globalStateSchema: As in the header-field factory.
       - localStateSchema: As in the header-field factory.
       - appArguments: As in the header-field factory.
       - accounts: As in the header-field factory.
       - foreignApps: As in the header-field factory.
       - foreignAssets: As in the header-field factory.
       - boxes: As in the header-field factory.
       - extraPages: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func create(
        sender: Address,
        approvalProgram: Data,
        clearStateProgram: Data,
        globalStateSchema: StateSchema,
        localStateSchema: StateSchema,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        extraPages: UInt64? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> ApplicationCallTransaction {
        return try ApplicationCallTransaction(
            sender: sender,
            applicationID: 0,
            onCompletion: .noOp,
            approvalProgram: approvalProgram,
            clearStateProgram: clearStateProgram,
            globalStateSchema: globalStateSchema,
            localStateSchema: localStateSchema,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            extraPages: extraPages,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Updates an application
    public static func update(
        sender: Address,
        applicationID: UInt64,
        approvalProgram: Data,
        clearStateProgram: Data,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> ApplicationCallTransaction {
        return ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .updateApplication,
            approvalProgram: approvalProgram,
            clearStateProgram: clearStateProgram,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Updates an application, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - applicationID: As in the header-field factory.
       - approvalProgram: As in the header-field factory.
       - clearStateProgram: As in the header-field factory.
       - appArguments: As in the header-field factory.
       - accounts: As in the header-field factory.
       - foreignApps: As in the header-field factory.
       - foreignAssets: As in the header-field factory.
       - boxes: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func update(
        sender: Address,
        applicationID: UInt64,
        approvalProgram: Data,
        clearStateProgram: Data,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> ApplicationCallTransaction {
        return try ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .updateApplication,
            approvalProgram: approvalProgram,
            clearStateProgram: clearStateProgram,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Deletes an application
    public static func delete(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> ApplicationCallTransaction {
        return ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .deleteApplication,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Deletes an application, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - applicationID: As in the header-field factory.
       - appArguments: As in the header-field factory.
       - accounts: As in the header-field factory.
       - foreignApps: As in the header-field factory.
       - foreignAssets: As in the header-field factory.
       - boxes: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func delete(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> ApplicationCallTransaction {
        return try ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .deleteApplication,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Opts into an application
    public static func optIn(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> ApplicationCallTransaction {
        return ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .optIn,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Opts into an application, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - applicationID: As in the header-field factory.
       - appArguments: As in the header-field factory.
       - accounts: As in the header-field factory.
       - foreignApps: As in the header-field factory.
       - foreignAssets: As in the header-field factory.
       - boxes: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func optIn(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> ApplicationCallTransaction {
        return try ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .optIn,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Closes out from an application
    public static func closeOut(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> ApplicationCallTransaction {
        return ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .closeOut,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Closes out from an application, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - applicationID: As in the header-field factory.
       - appArguments: As in the header-field factory.
       - accounts: As in the header-field factory.
       - foreignApps: As in the header-field factory.
       - foreignAssets: As in the header-field factory.
       - boxes: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func closeOut(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> ApplicationCallTransaction {
        return try ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .closeOut,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Clears state from an application
    public static func clearState(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> ApplicationCallTransaction {
        return ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .clearState,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Clears state from an application, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - applicationID: As in the header-field factory.
       - appArguments: As in the header-field factory.
       - accounts: As in the header-field factory.
       - foreignApps: As in the header-field factory.
       - foreignAssets: As in the header-field factory.
       - boxes: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func clearState(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> ApplicationCallTransaction {
        return try ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .clearState,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Calls an application with NoOp
    public static func call(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> ApplicationCallTransaction {
        return ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .noOp,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Calls an application with NoOp, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - applicationID: As in the header-field factory.
       - appArguments: As in the header-field factory.
       - accounts: As in the header-field factory.
       - foreignApps: As in the header-field factory.
       - foreignAssets: As in the header-field factory.
       - boxes: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func call(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> ApplicationCallTransaction {
        return try ApplicationCallTransaction(
            sender: sender,
            applicationID: applicationID,
            onCompletion: .noOp,
            appArguments: appArguments,
            accounts: accounts,
            foreignApps: foreignApps,
            foreignAssets: foreignAssets,
            boxes: boxes,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }
}
