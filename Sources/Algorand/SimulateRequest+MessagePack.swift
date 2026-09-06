@preconcurrency import Foundation

// MARK: - Request Encoding

extension SimulateRequest {
    /**
     Encodes the request as the MessagePack body `POST /v2/transactions/simulate` expects.

     The shape, from go-algorand's `PreEncodedSimulateRequest`:

     ```
     { "txn-groups": [ { "txns": [ <SignedTxn>, ... ] } ], ...flags }
     ```

     `txns` is `[]SignedTxn`, a struct array, so each element must be that signed transaction's
     own canonical encoding spliced in verbatim - hence ``MessagePackValue/raw(_:)``. algod's
     decoder is strict about field names, so only the tags it declares are emitted, and every
     optional the caller left unset is omitted rather than sent as an explicit field.

     - Returns: The request body.
     - Throws: `AlgorandError.encodingError` if the map cannot be encoded.
     */
    internal func encodedForSimulate() throws -> Data {
        var groups: [MessagePackValue] = []
        groups.reserveCapacity(txnGroups.count)

        for group in txnGroups {
            let transactions = group.txns.map { MessagePackValue.raw($0) }
            groups.append(.map(["txns": .array(transactions)]))
        }

        var request: [String: MessagePackValue] = ["txn-groups": .array(groups)]

        if let round {
            request["round"] = .uint(round)
        }
        if let allowEmptySignatures {
            request["allow-empty-signatures"] = .bool(allowEmptySignatures)
        }
        if let allowMoreLogging {
            request["allow-more-logging"] = .bool(allowMoreLogging)
        }
        if let allowUnnamedResources {
            request["allow-unnamed-resources"] = .bool(allowUnnamedResources)
        }
        if let extraOpcodeBudget {
            request["extra-opcode-budget"] = .uint(extraOpcodeBudget)
        }
        if let execTraceConfig, let traceMap = execTraceConfig.messagePackMap {
            request["exec-trace-config"] = .map(traceMap)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: request)
    }
}

extension ExecTraceConfig {
    /// The `simulation.ExecTraceConfig` fields, or `nil` when none are set.
    ///
    /// Tags match go-algorand exactly: `enable`, `stack-change`, `scratch-change`, `state-change`.
    fileprivate var messagePackMap: [String: MessagePackValue]? {
        var map: [String: MessagePackValue] = [:]

        if let enable {
            map["enable"] = .bool(enable)
        }
        if let stackChange {
            map["stack-change"] = .bool(stackChange)
        }
        if let scratchChange {
            map["scratch-change"] = .bool(scratchChange)
        }
        if let stateChange {
            map["state-change"] = .bool(stateChange)
        }

        return map.isEmpty ? nil : map
    }
}
