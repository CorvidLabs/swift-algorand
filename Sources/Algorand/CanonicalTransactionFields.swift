@preconcurrency import Foundation

/**
 Builds an Algorand transaction field map with go-algorand's `omitempty` codec semantics applied
 uniformly, at the point of assignment.

 Every transaction struct in go-algorand carries `_struct codec:",omitempty,omitemptyarray"`, so its
 msgp-generated marshaller drops any field holding its Go zero value. A node that receives a
 transaction decodes it, re-encodes it through that marshaller, and verifies the signature over the
 re-encoded bytes. An SDK that signs a preimage containing an explicit zero therefore signs bytes the
 node never reconstructs, and the node answers "At least one signature didn't pass verification".

 The omission rule belongs to the *value*, not to the field, so it lives in these setters rather than
 in each transaction type's `encode(groupID:)`. Hand-written per-type maps are precisely why the same
 omission bug appeared in every transaction type at once.

 Go's zero values map onto Swift as follows, and the setters are named for the Go type they mirror:

 - `uint64` / `uint32` -> ``set(_:uint:)``, dropped when `0`
 - `bool` -> ``set(_:bool:)``, dropped when `false` (and written as a MessagePack bool, never as `1`)
 - `string` -> ``set(_:string:)``, dropped when empty
 - `[]byte` -> ``set(_:blob:)``, dropped when the slice is empty (a slice of zero bytes is kept)
 - `[N]byte` -> ``set(_:digest:)``, dropped when every byte is zero (an array is never "empty")
 - `basics.Address` -> ``set(_:address:)``, dropped when it is the all-zero address
 - slice fields -> ``set(_:array:)``, dropped when the array is empty (`omitemptyarray`)
 - nested structs -> ``set(_:map:)``, dropped when the nested struct is itself entirely zero
 */
internal struct CanonicalTransactionFields {

    // MARK: - Properties

    /// The fields that survived omission, keyed by their Algorand wire name.
    private var fields: [String: MessagePackValue] = [:]

    /// Whether every field was omitted, which is how a nested struct decides it is itself zero.
    internal var isEmpty: Bool {
        fields.isEmpty
    }

    /// The accumulated fields as a MessagePack map, for embedding where an empty map is still legal.
    internal var mapValue: MessagePackValue {
        .map(fields)
    }

    // MARK: - Initializers

    internal init() {}

    // MARK: - Typed Setters

    /// Sets an unsigned-integer field, omitting it when zero.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The value, dropped when `0`.
    internal mutating func set(_ key: String, uint value: UInt64) {
        guard value != 0 else { return }
        fields[key] = .uint(value)
    }

    /// Sets a boolean field as a MessagePack bool, omitting it when false.
    ///
    /// go-algorand marshals these with `msgp.AppendBool` and reads them with `ReadBoolBytes`. Writing
    /// the integer `1` instead of `0xc3` still decodes -- the codec coerces it -- but the node's
    /// re-encoding produces `0xc3`, so the signature no longer matches.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The value, dropped when `false`.
    internal mutating func set(_ key: String, bool value: Bool) {
        guard value else { return }
        fields[key] = .bool(true)
    }

    /// Sets a string field, omitting it when empty.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The value, dropped when it has no characters.
    internal mutating func set(_ key: String, string value: String) {
        guard !value.isEmpty else { return }
        fields[key] = .string(value)
    }

    /// Sets a variable-length byte-slice field, omitting it when absent or empty.
    ///
    /// This is the `[]byte` rule: a slice of zero bytes is a *present* value and is kept.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The value, dropped when `nil` or empty.
    internal mutating func set(_ key: String, blob value: Data?) {
        guard let value, !value.isEmpty else { return }
        fields[key] = .binary(value)
    }

    /// Sets a fixed-size byte-array field, omitting it when absent or entirely zero.
    ///
    /// This is the `[N]byte` rule, which covers `gh`, `grp`, `lx`, `votekey`, `selkey`, `sprfkey`
    /// and `am`. A Go array has no "empty" state, so the only value msgp drops is the all-zero one.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The value, dropped when `nil` or every byte is zero.
    internal mutating func set(_ key: String, digest value: Data?) {
        guard let value, value.contains(where: { $0 != 0 }) else { return }
        fields[key] = .binary(value)
    }

    /// Sets an address field, omitting it when absent or the all-zero address.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The address, dropped when `nil` or all-zero.
    internal mutating func set(_ key: String, address value: Address?) {
        set(key, digest: value?.bytes)
    }

    /// Sets an array field, omitting it when empty, per `omitemptyarray`.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The elements, dropped when there are none.
    internal mutating func set(_ key: String, array value: [MessagePackValue]) {
        guard !value.isEmpty else { return }
        fields[key] = .array(value)
    }

    /// Sets a nested-struct field, omitting it when every field of the nested struct was omitted.
    /// - Parameters:
    ///   - key: The Algorand wire name.
    ///   - value: The nested fields, dropped when they are all zero.
    internal mutating func set(_ key: String, map value: CanonicalTransactionFields) {
        guard !value.isEmpty else { return }
        fields[key] = value.mapValue
    }

    // MARK: - Header

    /**
     Installs the fields of go-algorand's `transactions.Header`, which every transaction type shares.

     Routing all eight transaction types through this one call is what keeps `fee`, `fv`, `lv`,
     `gen`, `note`, `lx`, `grp` and `rekey` consistent between them.

     - Parameters:
       - type: The transaction type tag, such as `"pay"`.
       - sender: The sending address.
       - fee: The fee in microAlgos.
       - firstValid: The first valid round.
       - lastValid: The last valid round.
       - genesisID: The genesis ID.
       - genesisHash: The 32-byte genesis hash.
       - note: The optional note.
       - lease: The optional 32-byte lease.
       - rekeyTo: The optional rekey target.
       - groupID: The optional 32-byte atomic-group ID.
     */
    internal mutating func setHeader(
        type: String,
        sender: Address,
        fee: MicroAlgos,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data?,
        lease: Data?,
        rekeyTo: Address?,
        groupID: Data?
    ) {
        set("type", string: type)
        set("snd", address: sender)
        set("fee", uint: fee.value)
        set("fv", uint: firstValid)
        set("lv", uint: lastValid)
        set("gen", string: genesisID)
        set("gh", digest: genesisHash)
        set("grp", digest: groupID)
        set("lx", digest: lease)
        set("note", blob: note)
        set("rekey", address: rekeyTo)
    }

    // MARK: - Encoding

    /**
     Encodes the surviving fields as canonically-ordered MessagePack.

     - Returns: The transaction bytes, ready to be prefixed with `"TX"` and signed.
     - Throws: `AlgorandError.encodingError` if the map is too large to encode.
     */
    internal func encoded() throws -> Data {
        var writer = MessagePackWriter()
        return try writer.write(map: fields)
    }
}
