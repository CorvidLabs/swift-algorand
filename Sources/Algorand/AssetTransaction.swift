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

    /// Converts a decimal amount to base units
    /// Example: 10.5 with 2 decimals = 1050 base units
    public func toBaseUnits(_ decimalAmount: Double) -> UInt64 {
        let multiplier = pow(10.0, Double(decimals))
        return UInt64(decimalAmount * multiplier)
    }

    /// Converts base units to decimal amount
    /// Example: 1050 base units with 2 decimals = 10.5
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

    public func encode(groupID: Data? = nil) throws -> Data {
        // Build asset parameters map
        var apar: [String: MessagePackValue] = [:]
        apar["t"] = .uint(assetParams.total)

        // Only include dc if non-zero (omit if 0 per Algorand convention)
        if assetParams.decimals > 0 {
            apar["dc"] = .uint(assetParams.decimals)
        }

        // Only include df if true (omit if false per Algorand spec)
        if assetParams.defaultFrozen {
            apar["df"] = .bool(true)
        }

        if let unitName = assetParams.unitName {
            apar["un"] = .string(unitName)
        }
        if let assetName = assetParams.assetName {
            apar["an"] = .string(assetName)
        }
        if let url = assetParams.url {
            apar["au"] = .string(url)
        }
        if let metadataHash = assetParams.metadataHash {
            apar["am"] = .binary(metadataHash)
        }
        if let manager = assetParams.manager {
            apar["m"] = .binary(manager.bytes)
        }
        if let reserve = assetParams.reserve {
            apar["r"] = .binary(reserve.bytes)
        }
        if let freeze = assetParams.freeze {
            apar["f"] = .binary(freeze.bytes)
        }
        if let clawback = assetParams.clawback {
            apar["c"] = .binary(clawback.bytes)
        }

        // Build transaction map
        var map: [String: MessagePackValue] = [:]
        map["apar"] = .map(apar)
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("acfg")

        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let rekeyTo = rekeyTo {
            map["rekey"] = .binary(rekeyTo.bytes)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: map)
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

    public func encode(groupID: Data? = nil) throws -> Data {
        var map: [String: MessagePackValue] = [:]

        // For opt-in, aamt should be 0 but might be omitted per Algorand spec
        // map["aamt"] = .uint(0)  // Omitting zero amount
        map["arcv"] = .binary(sender.bytes)  // Receive to self for opt-in
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("axfer")
        map["xaid"] = .uint(assetID)

        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let rekeyTo = rekeyTo {
            map["rekey"] = .binary(rekeyTo.bytes)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: map)
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

    public func encode(groupID: Data? = nil) throws -> Data {
        var map: [String: MessagePackValue] = [:]

        // afrz field: only include if true (canonical encoding omits false values)
        if frozen {
            map["afrz"] = .bool(true)
        }
        map["fadd"] = .binary(freezeAccount.bytes)
        map["faid"] = .uint(assetID)
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("afrz")

        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let rekeyTo = rekeyTo {
            map["rekey"] = .binary(rekeyTo.bytes)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: map)
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

    public func encode(groupID: Data? = nil) throws -> Data {
        var map: [String: MessagePackValue] = [:]

        map["caid"] = .uint(assetID)
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("acfg")

        // If all addresses are nil, this is a destroy transaction
        // Otherwise, update the specified addresses in nested apar map
        if manager != nil || reserve != nil || freeze != nil || clawback != nil {
            var apar: [String: MessagePackValue] = [:]

            if let manager = manager {
                apar["m"] = .binary(manager.bytes)
            }
            if let reserve = reserve {
                apar["r"] = .binary(reserve.bytes)
            }
            if let freeze = freeze {
                apar["f"] = .binary(freeze.bytes)
            }
            if let clawback = clawback {
                apar["c"] = .binary(clawback.bytes)
            }

            map["apar"] = .map(apar)
        }

        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let rekeyTo = rekeyTo {
            map["rekey"] = .binary(rekeyTo.bytes)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: map)
    }
}

extension AssetConfigTransaction {
    /// Destroys an asset (sender must be manager and hold all units)
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

    /// Updates asset configuration addresses
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

    public func encode(groupID: Data? = nil) throws -> Data {
        var map: [String: MessagePackValue] = [:]

        // Only include amount if non-zero (omit zero per Algorand convention)
        if amount > 0 {
            map["aamt"] = .uint(amount)
        }
        map["arcv"] = .binary(receiver.bytes)
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("axfer")
        map["xaid"] = .uint(assetID)

        if let closeRemainderTo = closeRemainderTo {
            map["aclose"] = .binary(closeRemainderTo.bytes)
        }
        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let rekeyTo = rekeyTo {
            map["rekey"] = .binary(rekeyTo.bytes)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: map)
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

    public func encode(groupID: Data? = nil) throws -> Data {
        var map: [String: MessagePackValue] = [:]

        if amount > 0 {
            map["aamt"] = .uint(amount)
        }
        map["arcv"] = .binary(assetReceiver.bytes)
        map["asnd"] = .binary(assetSender.bytes)
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("axfer")
        map["xaid"] = .uint(assetID)

        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let rekeyTo = rekeyTo {
            map["rekey"] = .binary(rekeyTo.bytes)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: map)
    }
}
