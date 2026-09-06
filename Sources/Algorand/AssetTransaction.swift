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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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
