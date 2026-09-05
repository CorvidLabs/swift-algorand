@preconcurrency import Foundation

/**
 The proof that authorizes a transaction: the signature category a signed envelope carries.

 A signed transaction carries exactly one category. go-algorand's `SignedTxn` knows four (`sig`,
 `msig`, `lsig`, `pqsig`); this SDK models the two it can produce.

 | Case | Wire key | Consensus |
 |---|---|---|
 | ``ed25519(_:)`` | `sig` | every version |
 | ``postQuantum(_:)`` | `pqsig` | v42 and later, Falcon-1024 |
 */
public enum TransactionAuthorization: Sendable, Hashable {

    /// A single Ed25519 signature over the signing preimage. The bytes are carried verbatim.
    case ed25519(Data)

    /// A native post-quantum proof: scheme, salt, public key, and signature.
    case postQuantum(PQSignature)

    // MARK: - Internal Properties

    /// The raw signature bytes, whichever scheme produced them.
    internal var signatureBytes: Data {
        switch self {
        case .ed25519(let signature): return signature
        case .postQuantum(let proof): return proof.signature
        }
    }

    // MARK: - Internal Methods

    /**
     Verifies that this proof can authorize `authorizer` before it is attached or encoded.

     An Ed25519 signature is opaque: its bytes are carried as given and the network checks them
     against the authorizer's public key. A post-quantum proof is self-describing, so the check
     the network will make can be made here: the scheme, salt, and public key must derive
     `authorizer`, or the node rejects the transaction with `pq signature authorizer mismatch`.

     - Parameter authorizer: The address whose authority is being exercised: `sgnr` when present,
       otherwise the sender.
     - Throws: `TransactionAuthorizationError.malformed` if a post-quantum proof has the wrong
       sizes, or `TransactionAuthorizationError.unauthorizedProof` if it derives another address.
     */
    internal func validate(authorizer: Address) throws {
        switch self {
        case .ed25519:
            return
        case .postQuantum(let proof):
            try proof.validateShape()
            let derived = try proof.derivedAddress()
            guard derived == authorizer else {
                throw TransactionAuthorizationError.unauthorizedProof(derived: derived, authorizer: authorizer)
            }
        }
    }

    /// The envelope field this category occupies: `sig` or `pqsig`.
    internal var envelopeField: (key: String, value: MessagePackValue) {
        switch self {
        case .ed25519(let signature): return ("sig", .binary(signature))
        case .postQuantum(let proof): return ("pqsig", proof.messagePackValue())
        }
    }
}

// MARK: - Errors

/// Failures detected while attaching an authorization to a transaction or encoding the envelope.
public enum TransactionAuthorizationError: Error, LocalizedError, Sendable, Equatable {

    /// An explicit `authAddr` was supplied that is not the address of the signer producing the proof.
    case authAddrMismatch(expected: Address, actual: Address)

    /// A post-quantum proof derives an address other than the one it must authorize.
    case unauthorizedProof(derived: Address, authorizer: Address)

    /// A proof or scheme tag has a size the network's decoder would reject.
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .authAddrMismatch(let expected, let actual):
            return "Auth address mismatch: the signer is \(expected) but authAddr names \(actual)"
        case .unauthorizedProof(let derived, let authorizer):
            return "Unauthorized proof: it derives \(derived) but must authorize \(authorizer)"
        case .malformed(let detail):
            return "Malformed authorization: \(detail)"
        }
    }
}
