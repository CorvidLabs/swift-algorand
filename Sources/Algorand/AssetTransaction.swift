@preconcurrency import Foundation

/// Asset configuration parameters
public struct AssetParams: Sendable {
    /// Total number of base units of the asset
    public let total: UInt64

    /// Number of digits to use after the decimal point when displaying the asset
    public let decimals: UInt64

    /// Whether asset holdings of this asset are frozen by default
    public let defaultFrozen: Bool

    /// Asset unit name (max 8 characters)
    public let unitName: String?

    /// Asset name (max 32 characters)
    public let assetName: String?

    /// URL where more information about the asset can be retrieved (max 96 characters)
    public let url: String?

    /// Hash of metadata for this asset
    public let metadataHash: Data?

    /// Manager address - can change reserve, freeze, clawback, and manager
    public let manager: Address?

    /// Reserve address - where non-minted assets reside
    public let reserve: Address?

    /// Freeze address - can freeze/unfreeze asset holdings
    public let freeze: Address?

    /// Clawback address - can revoke asset holdings
    public let clawback: Address?

    public init(
        total: UInt64,
        decimals: UInt64 = 0,
        defaultFrozen: Bool = false,
        unitName: String? = nil,
        assetName: String? = nil,
        url: String? = nil,
        metadataHash: Data? = nil,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil
    ) {
        self.total = total
        self.decimals = decimals
        self.defaultFrozen = defaultFrozen
        self.unitName = unitName
        self.assetName = assetName
        self.url = url
        self.metadataHash = metadataHash
        self.manager = manager
        self.reserve = reserve
        self.freeze = freeze
        self.clawback = clawback
    }

    /**
     Converts a decimal amount to base units

     Example: 10.5 with 2 decimals = 1050 base units
     */
    public func toBaseUnits(_ decimalAmount: Double) -> UInt64 {
        let multiplier = pow(10.0, Double(decimals))
        return UInt64(decimalAmount * multiplier)
    }

    /**
     Converts base units to decimal amount

     Example: 1050 base units with 2 decimals = 10.5
     */
    public func toDecimal(_ baseUnits: UInt64) -> Double {
        let divisor = pow(10.0, Double(decimals))
        return Double(baseUnits) / divisor
    }
}

/// Asset creation transaction
public struct AssetCreateTransaction: Transaction {
    public let sender: Address
    public let assetParams: AssetParams
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
        assetParams: AssetParams,
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
        self.assetParams = assetParams
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
     Creates an asset-creation transaction from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - assetParams: As in the header-field initializer.
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
        assetParams: AssetParams,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = AssetCreateTransaction(
            sender: sender,
            assetParams: assetParams,
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
            assetParams: assetParams,
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

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        var apar = CanonicalTransactionFields()
        apar.set("t", uint: assetParams.total)
        apar.set("dc", uint: assetParams.decimals)
        apar.set("df", bool: assetParams.defaultFrozen)
        apar.set("un", string: assetParams.unitName ?? "")
        apar.set("an", string: assetParams.assetName ?? "")
        apar.set("au", string: assetParams.url ?? "")
        apar.set("am", digest: assetParams.metadataHash)
        apar.set("m", address: assetParams.manager)
        apar.set("r", address: assetParams.reserve)
        apar.set("f", address: assetParams.freeze)
        apar.set("c", address: assetParams.clawback)

        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "acfg",
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
        fields.set("apar", map: apar)

        return try fields.encoded()
    }
}

/// Asset opt-in transaction (amount = 0, sender = receiver)
public struct AssetOptInTransaction: Transaction {
    public let sender: Address
    public let assetID: UInt64
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
        assetID: UInt64,
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
        self.assetID = assetID
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
     Creates an asset opt-in from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - assetID: As in the header-field initializer.
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
        assetID: UInt64,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = AssetOptInTransaction(
            sender: sender,
            assetID: assetID,
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
            assetID: assetID,
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

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "axfer",
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

        // An opt-in is a zero-amount transfer to self, so `aamt` is omitted entirely.
        fields.set("arcv", address: sender)
        fields.set("xaid", uint: assetID)

        return try fields.encoded()
    }
}

/// Asset freeze transaction
public struct AssetFreezeTransaction: Transaction {
    public let sender: Address
    public let assetID: UInt64
    public let freezeAccount: Address
    public let frozen: Bool
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
        assetID: UInt64,
        freezeAccount: Address,
        frozen: Bool,
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
        self.assetID = assetID
        self.freezeAccount = freezeAccount
        self.frozen = frozen
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
     Creates an asset freeze from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - assetID: As in the header-field initializer.
       - freezeAccount: As in the header-field initializer.
       - frozen: As in the header-field initializer.
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
        assetID: UInt64,
        freezeAccount: Address,
        frozen: Bool,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = AssetFreezeTransaction(
            sender: sender,
            assetID: assetID,
            freezeAccount: freezeAccount,
            frozen: frozen,
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
            assetID: assetID,
            freezeAccount: freezeAccount,
            frozen: frozen,
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

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "afrz",
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

        fields.set("afrz", bool: frozen)
        fields.set("fadd", address: freezeAccount)
        fields.set("faid", uint: assetID)

        return try fields.encoded()
    }
}

/// Asset configuration transaction (for updates and destroy)
public struct AssetConfigTransaction: Transaction {
    public let sender: Address
    public let assetID: UInt64
    public let manager: Address?
    public let reserve: Address?
    public let freeze: Address?
    public let clawback: Address?
    public let strictEmptyAddressChecking: Bool
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
        assetID: UInt64,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil,
        strictEmptyAddressChecking: Bool = false,
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
        self.assetID = assetID
        self.manager = manager
        self.reserve = reserve
        self.freeze = freeze
        self.clawback = clawback
        self.strictEmptyAddressChecking = strictEmptyAddressChecking
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
     Creates an asset configuration from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - assetID: As in the header-field initializer.
       - manager: As in the header-field initializer.
       - reserve: As in the header-field initializer.
       - freeze: As in the header-field initializer.
       - clawback: As in the header-field initializer.
       - strictEmptyAddressChecking: As in the header-field initializer.
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
        assetID: UInt64,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil,
        strictEmptyAddressChecking: Bool = false,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = AssetConfigTransaction(
            sender: sender,
            assetID: assetID,
            manager: manager,
            reserve: reserve,
            freeze: freeze,
            clawback: clawback,
            strictEmptyAddressChecking: strictEmptyAddressChecking,
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
            assetID: assetID,
            manager: manager,
            reserve: reserve,
            freeze: freeze,
            clawback: clawback,
            strictEmptyAddressChecking: strictEmptyAddressChecking,
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

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        // With no addresses at all the `apar` struct is entirely zero, which is the destroy shape.
        var apar = CanonicalTransactionFields()
        apar.set("m", address: manager)
        apar.set("r", address: reserve)
        apar.set("f", address: freeze)
        apar.set("c", address: clawback)

        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "acfg",
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
        fields.set("caid", uint: assetID)
        fields.set("apar", map: apar)

        return try fields.encoded()
    }
}

extension AssetConfigTransaction {
    /**
     Destroys an asset (sender must be manager and hold all units)
     */
    public static func destroy(
        sender: Address,
        assetID: UInt64,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> AssetConfigTransaction {
        return AssetConfigTransaction(
            sender: sender,
            assetID: assetID,
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
     Destroys an asset (sender must be manager and hold all units), from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - assetID: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func destroy(
        sender: Address,
        assetID: UInt64,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> AssetConfigTransaction {
        return try AssetConfigTransaction(
            sender: sender,
            assetID: assetID,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Updates asset configuration addresses
     */
    public static func update(
        sender: Address,
        assetID: UInt64,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil,
        strictEmptyAddressChecking: Bool = false,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> AssetConfigTransaction {
        return AssetConfigTransaction(
            sender: sender,
            assetID: assetID,
            manager: manager,
            reserve: reserve,
            freeze: freeze,
            clawback: clawback,
            strictEmptyAddressChecking: strictEmptyAddressChecking,
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
     Updates asset configuration addresses, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - assetID: As in the header-field factory.
       - manager: As in the header-field factory.
       - reserve: As in the header-field factory.
       - freeze: As in the header-field factory.
       - clawback: As in the header-field factory.
       - strictEmptyAddressChecking: As in the header-field factory.
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
        assetID: UInt64,
        manager: Address? = nil,
        reserve: Address? = nil,
        freeze: Address? = nil,
        clawback: Address? = nil,
        strictEmptyAddressChecking: Bool = false,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> AssetConfigTransaction {
        return try AssetConfigTransaction(
            sender: sender,
            assetID: assetID,
            manager: manager,
            reserve: reserve,
            freeze: freeze,
            clawback: clawback,
            strictEmptyAddressChecking: strictEmptyAddressChecking,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }
}

/// Asset transfer transaction
public struct AssetTransferTransaction: Transaction {
    public let sender: Address
    public let receiver: Address
    public let assetID: UInt64
    public let amount: UInt64
    public let closeRemainderTo: Address?
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
        receiver: Address,
        assetID: UInt64,
        amount: UInt64,
        closeRemainderTo: Address? = nil,
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
        self.receiver = receiver
        self.assetID = assetID
        self.amount = amount
        self.closeRemainderTo = closeRemainderTo
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
     Creates an asset transfer from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - receiver: As in the header-field initializer.
       - assetID: As in the header-field initializer.
       - amount: As in the header-field initializer.
       - closeRemainderTo: As in the header-field initializer.
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
        receiver: Address,
        assetID: UInt64,
        amount: UInt64,
        closeRemainderTo: Address? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = AssetTransferTransaction(
            sender: sender,
            receiver: receiver,
            assetID: assetID,
            amount: amount,
            closeRemainderTo: closeRemainderTo,
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
            receiver: receiver,
            assetID: assetID,
            amount: amount,
            closeRemainderTo: closeRemainderTo,
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

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "axfer",
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

        fields.set("aamt", uint: amount)
        fields.set("arcv", address: receiver)
        fields.set("aclose", address: closeRemainderTo)
        fields.set("xaid", uint: assetID)

        return try fields.encoded()
    }
}

/// Asset clawback transaction
public struct AssetClawbackTransaction: Transaction {
    public let sender: Address
    public let assetID: UInt64
    public let assetSender: Address
    public let assetReceiver: Address
    public let amount: UInt64
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
        assetID: UInt64,
        assetSender: Address,
        assetReceiver: Address,
        amount: UInt64,
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
        self.assetID = assetID
        self.assetSender = assetSender
        self.assetReceiver = assetReceiver
        self.amount = amount
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
     Creates an asset clawback from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - assetID: As in the header-field initializer.
       - assetSender: As in the header-field initializer.
       - assetReceiver: As in the header-field initializer.
       - amount: As in the header-field initializer.
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
        assetID: UInt64,
        assetSender: Address,
        assetReceiver: Address,
        amount: UInt64,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = AssetClawbackTransaction(
            sender: sender,
            assetID: assetID,
            assetSender: assetSender,
            assetReceiver: assetReceiver,
            amount: amount,
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
            assetID: assetID,
            assetSender: assetSender,
            assetReceiver: assetReceiver,
            amount: amount,
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

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "axfer",
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

        fields.set("aamt", uint: amount)
        fields.set("arcv", address: assetReceiver)
        fields.set("asnd", address: assetSender)
        fields.set("xaid", uint: assetID)

        return try fields.encoded()
    }
}
