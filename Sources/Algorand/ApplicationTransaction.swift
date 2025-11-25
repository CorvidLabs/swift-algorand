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
    public let boxes: [(UInt64, Data)]?  // (app_id, box_name)
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

    public func encode(groupID: Data? = nil) throws -> Data {
        var map: [String: MessagePackValue] = [:]

        // Required fields
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("appl")

        // Application ID (0 for creation)
        if applicationID > 0 {
            map["apid"] = .uint(applicationID)
        }

        // On-completion
        if onCompletion != .noOp {
            map["apan"] = .uint(onCompletion.rawValue)
        }

        // Approval and clear programs
        if let approvalProgram = approvalProgram {
            map["apap"] = .binary(approvalProgram)
        }
        if let clearStateProgram = clearStateProgram {
            map["apsu"] = .binary(clearStateProgram)
        }

        // State schemas
        if let globalSchema = globalStateSchema {
            var schemaMap: [String: MessagePackValue] = [:]
            if globalSchema.numUint > 0 {
                schemaMap["nui"] = .uint(globalSchema.numUint)
            }
            if globalSchema.numByteSlice > 0 {
                schemaMap["nbs"] = .uint(globalSchema.numByteSlice)
            }
            if !schemaMap.isEmpty {
                map["apgs"] = .map(schemaMap)
            }
        }

        if let localSchema = localStateSchema {
            var schemaMap: [String: MessagePackValue] = [:]
            if localSchema.numUint > 0 {
                schemaMap["nui"] = .uint(localSchema.numUint)
            }
            if localSchema.numByteSlice > 0 {
                schemaMap["nbs"] = .uint(localSchema.numByteSlice)
            }
            if !schemaMap.isEmpty {
                map["apls"] = .map(schemaMap)
            }
        }

        // Application arguments
        if let args = appArguments, !args.isEmpty {
            map["apaa"] = .array(args.map { .binary($0) })
        }

        // Accounts array
        if let accounts = accounts, !accounts.isEmpty {
            map["apat"] = .array(accounts.map { .binary($0.bytes) })
        }

        // Foreign apps
        if let foreignApps = foreignApps, !foreignApps.isEmpty {
            map["apfa"] = .array(foreignApps.map { .uint($0) })
        }

        // Foreign assets
        if let foreignAssets = foreignAssets, !foreignAssets.isEmpty {
            map["apas"] = .array(foreignAssets.map { .uint($0) })
        }

        // Boxes
        if let boxes = boxes, !boxes.isEmpty {
            var boxArray: [MessagePackValue] = []
            for (appID, boxName) in boxes {
                var boxMap: [String: MessagePackValue] = [:]
                if appID > 0 {
                    boxMap["i"] = .uint(appID)
                }
                boxMap["n"] = .binary(boxName)
                boxArray.append(.map(boxMap))
            }
            map["apbx"] = .array(boxArray)
        }

        // Extra pages
        if let extraPages = extraPages, extraPages > 0 {
            map["apep"] = .uint(extraPages)
        }

        // Optional fields
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
        fee: MicroAlgos = MicroAlgos(1000),
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
        fee: MicroAlgos = MicroAlgos(1000),
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

    /// Deletes an application
    public static func delete(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = MicroAlgos(1000),
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

    /// Opts into an application
    public static func optIn(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = MicroAlgos(1000),
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

    /// Closes out from an application
    public static func closeOut(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = MicroAlgos(1000),
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

    /// Clears state from an application
    public static func clearState(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = MicroAlgos(1000),
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

    /// Calls an application with NoOp
    public static func call(
        sender: Address,
        applicationID: UInt64,
        appArguments: [Data]? = nil,
        accounts: [Address]? = nil,
        foreignApps: [UInt64]? = nil,
        foreignAssets: [UInt64]? = nil,
        boxes: [(UInt64, Data)]? = nil,
        fee: MicroAlgos = MicroAlgos(1000),
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
}
