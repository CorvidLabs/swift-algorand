@preconcurrency import Foundation

/// The domain-separation prefix that precedes a transaction's MessagePack encoding when it is
/// signed or hashed: `protocol.Transaction` in go-algorand.
private let transactionSigningPrefix = Data("TX".utf8)

extension Transaction {

    // MARK: - Public Methods

    /**
     The exact bytes a signer must sign for this transaction.

     This is `"TX"` followed by the canonical MessagePack encoding of the transaction, and it is
     **not** hashed: every signature category signs these bytes directly. Ed25519 hashes internally
     as part of EdDSA and Falcon hashes internally as part of its own construction, so wrapping the
     preimage in SHA512/256 produces a signature the network rejects.

     Exposing the preimage is what makes an external signing backend possible: a hardware wallet,
     a KMS, or a Falcon implementation the caller supplies through ``TransactionSigner`` signs these
     bytes without this package ever holding the private key.

     - Parameter groupID: The atomic group ID, or `nil` for a standalone transaction. A grouped
       transaction must be signed with its group ID present, or the signature is over a different
       transaction than the one submitted.
     - Returns: The bytes to sign.
     - Throws: `AlgorandError.encodingError` if encoding fails.
     */
    public func bytesToSign(groupID: Data? = nil) throws -> Data {
        transactionSigningPrefix + (try encode(groupID: groupID))
    }
}
