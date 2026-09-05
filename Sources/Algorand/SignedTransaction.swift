@preconcurrency import Foundation

/**
 A signed transaction ready for submission.

 ### The envelope

 go-algorand's `SignedTxn` is a MessagePack map under `codec:",omitempty"`, so only the fields that
 are present appear. In canonical (sorted) order they are:

 ```
 lsig   logic signature      (not modelled)
 msig   multisig             (not modelled)
 pqsig  post-quantum proof   (consensus v42)
 sgnr   authorizing address  (rekeyed accounts only)
 sig    Ed25519 signature
 txn    the transaction
 ```

 Exactly one of `sig` and `pqsig` is present, chosen by ``authorization``; `sgnr` is present exactly
 when ``authAddr`` is set. An Ed25519-only envelope encodes byte-for-byte as it always has:
 `0x82`, `sig`, `txn`.

 ### Grouping

 The group ID is part of the transaction, not of the envelope. The signature and the transaction ID
 are therefore both computed over the encoding that includes it.
 */
public struct SignedTransaction: Sendable {

    // MARK: - Properties

    /// The transaction that was signed.
    public let transaction: any Transaction

    /// The proof authorizing the transaction.
    public let authorization: TransactionAuthorization

    /**
     The address that authorized the transaction when it is not the sender, carried as `sgnr`.

     Set for a rekeyed sender, whose spending authority belongs to another key. `nil` for the
     ordinary case where the sender signs for itself; consensus rejects a `sgnr` equal to the
     sender, so ``sign(_:with:groupID:authAddr:)`` and ``TransactionSigner/sign(_:groupID:authAddr:)``
     only ever set it when the signer's address differs from the sender.
     */
    public let authAddr: Address?

    /// The atomic group ID this transaction was signed under, if any.
    public let groupID: Data?

    /// The raw signature bytes, whichever scheme produced them: 64 bytes for Ed25519, or the
    /// post-quantum signature carried in the proof.
    public var signature: Data {
        authorization.signatureBytes
    }

    // MARK: - Initializers

    /**
     Creates a signed transaction from an authorization.

     - Parameters:
       - transaction: The transaction that was signed.
       - authorization: The proof authorizing it.
       - authAddr: The authorizing address when signing for a rekeyed sender, otherwise `nil`.
       - groupID: The atomic group ID the transaction was signed under, or `nil`.
     */
    public init(
        transaction: any Transaction,
        authorization: TransactionAuthorization,
        authAddr: Address? = nil,
        groupID: Data? = nil
    ) {
        self.transaction = transaction
        self.authorization = authorization
        self.authAddr = authAddr
        self.groupID = groupID
    }

    /**
     Creates an Ed25519-signed transaction.

     - Parameters:
       - transaction: The transaction that was signed.
       - signature: The signature bytes, carried verbatim under `sig`.
       - groupID: The atomic group ID the transaction was signed under, or `nil`.
     */
    public init(transaction: any Transaction, signature: Data, groupID: Data? = nil) {
        self.init(transaction: transaction, authorization: .ed25519(signature), authAddr: nil, groupID: groupID)
    }

    /**
     Assembles a signed transaction for a known signer, inferring `sgnr` and checking the proof.

     This is the one path every signing route goes through. `sgnr` is set when `signer` differs
     from the sender and omitted when it is the sender. A supplied `authAddr` must name `signer`;
     a post-quantum proof must derive `signer`.

     - Throws: `TransactionAuthorizationError.authAddrMismatch`, `.unauthorizedProof`, or
       `.malformed`.
     */
    internal init(
        transaction: any Transaction,
        authorization: TransactionAuthorization,
        signer: Address,
        authAddr requestedAuthAddr: Address?,
        groupID: Data?
    ) throws {
        if let requestedAuthAddr, requestedAuthAddr != signer {
            throw TransactionAuthorizationError.authAddrMismatch(expected: signer, actual: requestedAuthAddr)
        }

        try authorization.validate(authorizer: signer)

        self.init(
            transaction: transaction,
            authorization: authorization,
            authAddr: signer == transaction.sender ? nil : signer,
            groupID: groupID
        )
    }

    // MARK: - Signing

    /**
     Signs a transaction with an account's Ed25519 key.

     When the account is not the transaction's sender, the envelope carries the account's address
     as `sgnr`: the account is spending for a rekeyed sender. When it is the sender, `sgnr` is
     omitted.

     - Parameters:
       - transaction: The transaction to sign.
       - account: The account to sign with.
       - groupID: The atomic group ID, or `nil` for a standalone transaction.
       - authAddr: Optionally, the address the account is expected to act for. It must equal
         `account.address`; it never changes what is signed or emitted.
     - Returns: The signed transaction.
     - Throws: `TransactionAuthorizationError.authAddrMismatch` if `authAddr` is not the account's
       address, or `AlgorandError.encodingError` if encoding or signing fails.
     */
    public static func sign(
        _ transaction: any Transaction,
        with account: Account,
        groupID: Data? = nil,
        authAddr: Address? = nil
    ) throws -> SignedTransaction {
        let signature = try account.sign(try transaction.bytesToSign(groupID: groupID))

        return try SignedTransaction(
            transaction: transaction,
            authorization: .ed25519(signature),
            signer: account.address,
            authAddr: authAddr,
            groupID: groupID
        )
    }

    // MARK: - Public Methods

    /**
     The transaction ID: the hash of the bytes that were signed.

     A grouped transaction's on-chain ID is the hash of its *grouped* encoding, the one that carries
     `grp`. Re-encoding without the group ID would report an ID that does not exist on chain.

     - Returns: The base32-encoded transaction ID.
     - Throws: `AlgorandError.encodingError` if encoding fails.
     */
    public func id() throws -> String {
        SHA512_256.hash(data: try transaction.bytesToSign(groupID: groupID)).base32EncodedString()
    }

    /**
     Encodes the signed transaction to MessagePack for submission.

     Keys are emitted in canonical order and only when present, and binary lengths pick `bin8`,
     `bin16`, or `bin32` as MessagePack requires, so a 1538-byte Falcon signature encodes as
     readily as a 64-byte Ed25519 one. The transaction is spliced in already encoded, so the bytes
     under `txn` are exactly the bytes that were signed.

     - Returns: The encoded envelope.
     - Throws: `TransactionAuthorizationError` if the proof cannot authorize the transaction, or
       `AlgorandError.encodingError` if encoding fails.
     */
    public func encode() throws -> Data {
        try authorization.validate(authorizer: authAddr ?? transaction.sender)

        let field = authorization.envelopeField
        var fields: [String: MessagePackValue] = [field.key: field.value]
        if let authAddr {
            fields[Self.authAddrKey] = .binary(authAddr.bytes)
        }

        return try Self.envelope(fields: fields, encodedTransaction: try transaction.encode(groupID: groupID))
    }

    // MARK: - Private

    private static let authAddrKey = "sgnr"
    private static let transactionKey = "txn"

    /**
     Builds the envelope map: `fields` through `MessagePackWriter`, then `txn` spliced on the end.

     `txn` sorts after every other key `SignedTxn` can carry (`lsig`, `msig`, `pqsig`, `sgnr`,
     `sig`), so appending it last preserves canonical order. The writer produced a `fixmap` header
     for `fields.count` entries; with at most two authorization fields plus `txn`, the final count
     fits the same one-byte header, which is rewritten in place.
     */
    private static func envelope(fields: [String: MessagePackValue], encodedTransaction: Data) throws -> Data {
        guard fields.keys.allSatisfy({ $0 < transactionKey }) else {
            throw AlgorandError.encodingError("Signed transaction field sorts after \(transactionKey)")
        }

        let totalCount = fields.count + 1
        guard totalCount <= 15 else {
            throw AlgorandError.encodingError("Signed transaction envelope has \(totalCount) fields; fixmap holds 15")
        }

        var writer = MessagePackWriter()
        var envelope = try writer.write(map: fields)

        guard envelope.first == 0x80 + UInt8(fields.count) else {
            throw AlgorandError.encodingError("Signed transaction envelope did not start with a fixmap header")
        }

        envelope[envelope.startIndex] = 0x80 + UInt8(totalCount)
        envelope.append(0xA0 + UInt8(transactionKey.utf8.count))
        envelope.append(contentsOf: transactionKey.utf8)
        envelope.append(encodedTransaction)

        return envelope
    }
}
