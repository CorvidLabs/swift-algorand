@preconcurrency import Foundation
import Testing
@testable import Algorand

/**
 The signed-transaction envelope after the post-quantum rewrite.

 `CanonicalEncodingTests` owns the golden vectors; this suite pins the behaviour around them: an
 Ed25519-only envelope is byte-identical to what the pre-rewrite encoder emitted, `sgnr` is
 inferred exactly when the signer is not the sender, an explicit `authAddr` is a guard rather than
 an override, the signing preimage is exposed unhashed, and a post-quantum proof is checked against
 the address it must authorize before an envelope is built.

 Fixtures are the ones `CanonicalEncodingTests` uses: TestNet genesis, account A as sender, account
 B as receiver, the fixed auth account for the rekeyed vector, and the three 1793-byte post-quantum
 keys. Throwing calls are hoisted out of `#expect` because the Swift 6.0 toolchain's macro does not
 accept them inside its expression.
 */

/// Requirement evidence: REQ-algorand-019, REQ-algorand-020, REQ-algorand-021, REQ-algorand-022, REQ-algorand-023.
@Suite
internal struct SignedTransactionEnvelopeTests {

    // MARK: - Fixtures

    /// Account A's seed: the sender of every envelope vector.
    internal static let accountASeedHex = "14a16b7d74ba2c495533d743658ee19bc27300ce302a4f19f3bb766a3c8cb02e"

    /// The auth account's seed: the signer of `signed_ed25519_rekeyed_sgnr`.
    internal static let authAccountSeedHex = "809b82f17241751a0b3bd4b7ed8597d351c4dc6617ff4daf230dc27f8312e37f"

    /// A group ID for the grouped-envelope tests: the `AtomicTransactionGroup` golden value.
    internal static let groupIDHex = "2e17dd6e388e7b5a34dc844cf3555711687f06b9633796ccaf082239247fd899"

    /// "sig" as a bin16 header for a 1538-byte value: `a3 's' 'i' 'g' c5 06 02`.
    internal static let falconSizedSignatureHeaderHex = "a3736967c50602"

    internal static func accountA() throws -> Account {
        try Account(privateKey: try hexData(accountASeedHex))
    }

    internal static func authAccount() throws -> Account {
        try Account(privateKey: try hexData(authAccountSeedHex))
    }

    internal static func unsignedTransactionBytes() throws -> Data {
        try hexData(CanonicalEncodingTests.signedEnvelopeUnsignedTxnHex)
    }

    /// The payment every envelope in this file wraps; identical to `makeEnvelopeTransaction`.
    internal func makeTransaction() throws -> PaymentTransaction {
        PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: MicroAlgos(1000),
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: try CanonicalEncodingTests.genesisHash()
        )
    }

    /// A 1793-byte golden post-quantum key and its canonical salt and address.
    internal static func pqKey(_ index: Int) throws -> (publicKey: Data, salt: UInt8, address: Address) {
        let vector = PostQuantumVectors.pqAddressCases[index]
        return (try hexData(vector.publicKeyHex), UInt8(vector.salt), try Address(string: vector.address))
    }

    /**
     The envelope exactly as the pre-rewrite encoder hand-wrote it:
     `0x82`, fixstr "sig", bin8(64), the signature, fixstr "txn", the transaction bytes.

     This is the oracle for byte identity. It is deliberately independent of `MessagePackWriter`.
     */
    internal static func legacyEnvelope(signature: Data, transaction: Data) -> Data {
        var output = Data()
        output.append(0x82)
        output.append(0xA3)
        output.append(contentsOf: "sig".utf8)
        output.append(0xC4)
        output.append(UInt8(signature.count))
        output.append(signature)
        output.append(0xA3)
        output.append(contentsOf: "txn".utf8)
        output.append(transaction)
        return output
    }

    // MARK: - Byte identity for Ed25519-only envelopes

    /// An Ed25519-only envelope must be byte-identical to the old fixed `{sig, txn}` layout, for a
    /// synthetic signature and for the golden vector's real one.
    @Test
    internal func testEd25519EnvelopeIsByteIdenticalToLegacyEncoder() throws {
        let transaction = try makeTransaction()
        let unsigned = try Self.unsignedTransactionBytes()

        let synthetic = Data((0..<64).map { UInt8($0) })
        let encoded = try SignedTransaction(transaction: transaction, signature: synthetic).encode()
        #expect(encoded == Self.legacyEnvelope(signature: synthetic, transaction: unsigned))
        #expect(encoded.count == 241)

        let golden = try hexData(CanonicalEncodingTests.signedEnvelopeSignatureHex)
        let goldenEncoded = try SignedTransaction(transaction: transaction, signature: golden).encode()
        #expect(goldenEncoded.hexString == CanonicalEncodingTests.signedEnvelopeHex)
        #expect(goldenEncoded == Self.legacyEnvelope(signature: golden, transaction: unsigned))
    }

    /// The same identity holds for a grouped transaction, and the reported ID is the grouped one.
    @Test
    internal func testGroupedEd25519EnvelopeIsByteIdenticalToLegacyEncoder() throws {
        let transaction = try makeTransaction()
        let groupID = try hexData(Self.groupIDHex)
        let grouped = try transaction.encode(groupID: groupID)
        let ungrouped = try transaction.encode(groupID: nil)
        #expect(grouped != ungrouped)

        let signature = Data(repeating: 0x5A, count: 64)
        let signed = SignedTransaction(transaction: transaction, signature: signature, groupID: groupID)
        let encoded = try signed.encode()
        let transactionID = try signed.id()
        #expect(encoded == Self.legacyEnvelope(signature: signature, transaction: grouped))
        #expect(transactionID == CanonicalEncodingTests.transactionID(forEncoded: grouped))
    }

    /// `signature` keeps returning the raw bytes for both authorization kinds.
    @Test
    internal func testSignatureAccessorReturnsRawBytesForBothSchemes() throws {
        let transaction = try makeTransaction()
        let ed25519 = Data(repeating: 0x11, count: 64)
        #expect(SignedTransaction(transaction: transaction, signature: ed25519).signature == ed25519)

        let key = try Self.pqKey(0)
        let falcon = Data(repeating: 0x22, count: 1423)
        let proof = PQSignature(scheme: .falcon1024, salt: key.salt, publicKey: key.publicKey, signature: falcon)
        #expect(SignedTransaction(transaction: transaction, authorization: .postQuantum(proof)).signature == falcon)
    }

    // MARK: - sgnr inference

    /// The sender signing for itself: no `sgnr`, two-key map, unchanged bytes.
    @Test
    internal func testSignerEqualToSenderOmitsSgnr() throws {
        let transaction = try makeTransaction()
        let account = try Self.accountA()
        #expect(account.address == transaction.sender)

        let signed = try SignedTransaction.sign(transaction, with: account)
        let encoded = try signed.encode()
        let unsigned = try Self.unsignedTransactionBytes()
        let preimage = try transaction.bytesToSign()

        #expect(signed.authAddr == nil)
        #expect(encoded.first == 0x82)
        #expect(!encoded.containsSubsequence(Data([0xA4, 0x73, 0x67, 0x6E, 0x72])))
        #expect(encoded == Self.legacyEnvelope(signature: signed.signature, transaction: unsigned))
        #expect(account.verify(signature: signed.signature, for: preimage))
    }

    /// Golden vector `signed_ed25519_rekeyed_sgnr`: the auth account signing for account A must
    /// emit `sgnr` = the auth account. The fixed regions are exact on every platform; the whole
    /// 280-byte envelope is exact where Ed25519 is deterministic.
    @Test
    internal func testSignerDifferentFromSenderInfersSgnr() throws {
        let transaction = try makeTransaction()
        let account = try Self.authAccount()
        let expectedAuthAddress = try CanonicalEncodingTests.authAccount()
        #expect(account.address == expectedAuthAddress)
        #expect(account.address != transaction.sender)

        let signed = try SignedTransaction.sign(transaction, with: account)
        let encoded = try signed.encode()
        let golden = try hexData(PostQuantumVectors.rekeyedEnvelopeHex)
        let preimage = try transaction.bytesToSign()

        #expect(signed.authAddr == account.address)
        #expect(encoded.count == golden.count)
        #expect(encoded.prefix(46) == golden.prefix(46), "0x83, sgnr, bin8(32), address, sig, bin8(64)")
        #expect(encoded.suffix(4 + 166) == golden.suffix(4 + 166), "txn and the transaction bytes")
        #expect(account.verify(signature: signed.signature, for: preimage))

        if CanonicalEncodingTests.ed25519SignaturesAreDeterministic {
            #expect(encoded == golden)
        }
    }

    /// An explicit `authAddr` is accepted only when it names the signer.
    @Test
    internal func testExplicitAuthAddrMustNameTheSigner() throws {
        let transaction = try makeTransaction()
        let sender = try Self.accountA()
        let auth = try Self.authAccount()

        // Naming the signer changes nothing: inferred and explicit agree.
        let explicit = try SignedTransaction.sign(transaction, with: auth, authAddr: auth.address)
        let explicitEncoded = try explicit.encode()
        #expect(explicit.authAddr == auth.address)
        #expect(explicitEncoded.first == 0x83)

        let senderExplicit = try SignedTransaction.sign(transaction, with: sender, authAddr: sender.address)
        let senderExplicitEncoded = try senderExplicit.encode()
        #expect(senderExplicit.authAddr == nil, "sgnr equal to the sender is never emitted")
        #expect(senderExplicitEncoded.first == 0x82)

        // Naming anyone else is a caller mistake, and a typed one.
        let authNamedSender = TransactionAuthorizationError.authAddrMismatch(
            expected: auth.address,
            actual: sender.address
        )
        #expect(throws: authNamedSender) {
            try SignedTransaction.sign(transaction, with: auth, authAddr: sender.address)
        }
        let senderNamedAuth = TransactionAuthorizationError.authAddrMismatch(
            expected: sender.address,
            actual: auth.address
        )
        #expect(throws: senderNamedAuth) {
            try SignedTransaction.sign(transaction, with: sender, authAddr: auth.address)
        }
    }

    // MARK: - TransactionSigner

    /// The protocol path and the static path assemble the same envelope.
    @Test
    internal func testAccountSignsThroughTheProtocolPath() async throws {
        let transaction = try makeTransaction()
        let auth = try Self.authAccount()
        let sender = try Self.accountA()
        let preimage = try transaction.bytesToSign()
        let unsigned = try Self.unsignedTransactionBytes()

        let rekeyed = try await auth.sign(transaction)
        let rekeyedEncoded = try rekeyed.encode()
        #expect(rekeyed.authAddr == auth.address)
        #expect(rekeyedEncoded.first == 0x83)
        #expect(auth.verify(signature: rekeyed.signature, for: preimage))

        let plain = try await sender.sign(transaction)
        let plainEncoded = try plain.encode()
        #expect(plain.authAddr == nil)
        #expect(plainEncoded == Self.legacyEnvelope(signature: plain.signature, transaction: unsigned))

        let mismatch = TransactionAuthorizationError.authAddrMismatch(expected: auth.address, actual: sender.address)
        await #expect(throws: mismatch) {
            try await auth.sign(transaction, authAddr: sender.address)
        }
    }

    /// A caller-supplied signer receives the exact unhashed preimage and its proof is carried
    /// verbatim; `sgnr` follows the signer's declared address.
    @Test
    internal func testCustomSignerReceivesThePreimageAndControlsSgnr() async throws {
        let transaction = try makeTransaction()
        let signature = Data(repeating: 0xC3, count: 64)
        let recorder = PreimageRecorder()
        let unsigned = try Self.unsignedTransactionBytes()

        let asSender = FixedSigner(address: transaction.sender, authorization: .ed25519(signature), recorder: recorder)
        let signed = try await asSender.sign(transaction)
        let signedEncoded = try signed.encode()
        let standalonePreimage = try transaction.bytesToSign()
        let recordedStandalone = await recorder.preimages
        #expect(recordedStandalone == [standalonePreimage])
        #expect(signed.authAddr == nil)
        #expect(signedEncoded == Self.legacyEnvelope(signature: signature, transaction: unsigned))

        let other = try CanonicalEncodingTests.accountC()
        let asOther = FixedSigner(address: other, authorization: .ed25519(signature), recorder: recorder)
        let groupID = try hexData(Self.groupIDHex)
        let rekeyed = try await asOther.sign(transaction, groupID: groupID)
        let groupedPreimage = try transaction.bytesToSign(groupID: groupID)
        let recordedGrouped = await recorder.preimages.last
        #expect(recordedGrouped == groupedPreimage)
        #expect(rekeyed.authAddr == other)
        #expect(rekeyed.groupID == groupID)

        let encoded = try rekeyed.encode()
        #expect(encoded.prefix(8).hexString == "83a473676e72c420")
        #expect(encoded.dropFirst(8).prefix(32) == other.bytes)
    }

    // MARK: - Signing preimage

    /// `bytesToSign` is `"TX"` followed by the canonical encoding, unhashed, grouped or not.
    @Test
    internal func testBytesToSignIsThePrefixedCanonicalEncoding() throws {
        let transaction = try makeTransaction()
        let prefix = Data("TX".utf8)
        let unsigned = try Self.unsignedTransactionBytes()

        let standalone = try transaction.bytesToSign()
        let standaloneExplicit = try transaction.bytesToSign(groupID: nil)
        #expect(standalone == prefix + unsigned)
        #expect(standaloneExplicit == standalone)

        let groupID = try hexData(Self.groupIDHex)
        let grouped = try transaction.bytesToSign(groupID: groupID)
        let groupedEncoding = try transaction.encode(groupID: groupID)
        #expect(grouped == prefix + groupedEncoding)
        #expect(grouped != standalone)

        let transactionID = try transaction.id()
        #expect(SHA512_256.hash(data: standalone).base32EncodedString() == transactionID)
    }

    // MARK: - Post-quantum signing

    /// `PQSigner` derives the canonical salt and address for each golden key and carries them,
    /// with the callback's signature, in the proof.
    @Test
    internal func testPostQuantumSignerDerivesCanonicalSaltAndAddress() async throws {
        for index in 0..<PostQuantumVectors.pqAddressCases.count {
            let key = try Self.pqKey(index)
            let signature = Data(repeating: UInt8(0x30 + index), count: 1423)
            let signer = try PQSigner(publicKey: key.publicKey) { _ in signature }

            #expect(signer.scheme == .falcon1024)
            #expect(signer.salt == key.salt)
            #expect(signer.address == key.address)

            let authorization = try await signer.authorize(Data("TX".utf8))
            #expect(authorization == .postQuantum(
                PQSignature(scheme: .falcon1024, salt: key.salt, publicKey: key.publicKey, signature: signature)
            ))
        }
    }

    /// A non-zero salt is written as `slt`, after `sig`; a zero salt is omitted.
    @Test
    internal func testPostQuantumSaltIsOmittedWhenZeroAndPresentOtherwise() async throws {
        let signature = Data(repeating: 0x77, count: 1423)
        let receiver = try CanonicalEncodingTests.accountB()
        let genesisHash = try CanonicalEncodingTests.genesisHash()
        let sltKey = Data([0xA3, 0x73, 0x6C, 0x74])

        for index in 0..<PostQuantumVectors.pqAddressCases.count {
            let key = try Self.pqKey(index)
            let signer = try PQSigner(publicKey: key.publicKey) { _ in signature }
            let transaction = PaymentTransaction(
                sender: signer.address,
                receiver: receiver,
                amount: MicroAlgos(1),
                fee: MicroAlgos(1000),
                firstValid: 51,
                lastValid: 1051,
                genesisID: CanonicalEncodingTests.genesisID,
                genesisHash: genesisHash
            )
            let signed = try await signer.sign(transaction)
            let encoded = try signed.encode()

            // {pqsig: {pk, sch, sig[, slt]}, txn}: 0x82, "pqsig" (7 bytes), inner fixmap (1),
            // "pk" bin16(1793) (6 + 1793), "sch" bin8(2) "f1" (8), "sig" bin16(1423) (7 + 1423).
            #expect(encoded.prefix(7).hexString == "82a57071736967")
            let pkHeader = "a2706bc50701"
            let schHeader = "a3736368c4026631"
            let sigHeader = "a3736967c5058f"
            #expect(encoded.dropFirst(7).prefix(1).hexString == (key.salt == 0 ? "83" : "84"))
            #expect(encoded.dropFirst(8).prefix(6).hexString == pkHeader)
            #expect(encoded.dropFirst(14 + 1793).prefix(8).hexString == schHeader)
            #expect(encoded.dropFirst(22 + 1793).prefix(7).hexString == sigHeader)

            let afterSignature = encoded.dropFirst(29 + 1793 + 1423)
            if key.salt == 0 {
                #expect(!encoded.containsSubsequence(sltKey))
                #expect(afterSignature.prefix(4).hexString == "a374786e")
            } else {
                #expect(afterSignature.prefix(5) == sltKey + Data([key.salt]))
                #expect(afterSignature.dropFirst(5).prefix(4).hexString == "a374786e")
            }
        }
    }

    /// A post-quantum signer acting for a rekeyed Ed25519 sender carries its address as `sgnr`.
    @Test
    internal func testRekeyedPostQuantumSignerCarriesSgnr() async throws {
        let transaction = try makeTransaction()
        let key = try Self.pqKey(1)
        let signer = try PQSigner(publicKey: key.publicKey) { _ in Data(repeating: 0x01, count: 1538) }

        let signed = try await signer.sign(transaction)
        let encoded = try signed.encode()
        let bin16Header = try hexData(Self.falconSizedSignatureHeaderHex)
        #expect(signed.authAddr == key.address)
        #expect(encoded.first == 0x83, "pqsig, sgnr, txn")
        #expect(encoded.containsSubsequence(Data([0xA4, 0x73, 0x67, 0x6E, 0x72, 0xC4, 0x20]) + key.address.bytes))
        #expect(encoded.containsSubsequence(bin16Header), "1538-byte signature uses bin16")
        #expect(encoded.suffix(4 + 166).hexString == "a374786e" + CanonicalEncodingTests.signedEnvelopeUnsignedTxnHex)
    }

    /// The proof must derive the address it authorizes: a signer that returns a proof for a key
    /// other than the one behind its declared address is refused at sign time, and a hand-built
    /// envelope with the same defect is refused at encode time.
    @Test
    internal func testPostQuantumProofMustDeriveTheAuthorizer() async throws {
        let transaction = try makeTransaction()
        let key = try Self.pqKey(0)
        let proof = PQSignature(
            scheme: .falcon1024,
            salt: key.salt,
            publicKey: key.publicKey,
            signature: Data(repeating: 0x09, count: 1423)
        )

        // Declares account A's authority, proves ownership of the PQ key instead.
        let impostor = FixedSigner(
            address: transaction.sender,
            authorization: .postQuantum(proof),
            recorder: PreimageRecorder()
        )
        let unauthorizedForSender = TransactionAuthorizationError.unauthorizedProof(
            derived: key.address,
            authorizer: transaction.sender
        )
        await #expect(throws: unauthorizedForSender) {
            try await impostor.sign(transaction)
        }

        // Same proof, wrong salt: derives an address nobody controls.
        let wrongSalt = PQSignature(
            scheme: .falcon1024,
            salt: key.salt &+ 1,
            publicKey: key.publicKey,
            signature: proof.signature
        )
        let wrongSaltAddress = try Address.postQuantum(
            scheme: .falcon1024,
            salt: key.salt &+ 1,
            publicKey: key.publicKey
        )
        let wrongSaltSigner = FixedSigner(
            address: key.address,
            authorization: .postQuantum(wrongSalt),
            recorder: PreimageRecorder()
        )
        let unauthorizedSalt = TransactionAuthorizationError.unauthorizedProof(
            derived: wrongSaltAddress,
            authorizer: key.address
        )
        await #expect(throws: unauthorizedSalt) {
            try await wrongSaltSigner.sign(transaction)
        }

        // Direct construction bypasses sign time; encode time catches it against the sender.
        let direct = SignedTransaction(transaction: transaction, authorization: .postQuantum(proof))
        #expect(throws: unauthorizedForSender) {
            try direct.encode()
        }

        // With sgnr naming the derived address the same envelope is authorized.
        let rekeyed = SignedTransaction(
            transaction: transaction,
            authorization: .postQuantum(proof),
            authAddr: key.address
        )
        let rekeyedEncoded = try rekeyed.encode()
        #expect(rekeyedEncoded.first == 0x83)
    }

    /// Sizes the network's decoder enforces are refused before anything is signed or encoded.
    @Test
    internal func testPostQuantumSizesAreEnforced() async throws {
        let transaction = try makeTransaction()
        let key = try Self.pqKey(2)
        let bin16Header = try hexData(Self.falconSizedSignatureHeaderHex)

        #expect(throws: TransactionAuthorizationError.self) {
            try PQSigner(publicKey: Data(repeating: 0x00, count: 1280)) { _ in Data() }
        }

        let empty = try PQSigner(publicKey: key.publicKey) { _ in Data() }
        await #expect(throws: TransactionAuthorizationError.malformed("Post-quantum signature is empty")) {
            try await empty.sign(transaction)
        }

        let oversized = try PQSigner(publicKey: key.publicKey) { _ in Data(repeating: 0xFF, count: 1539) }
        await #expect(throws: TransactionAuthorizationError.self) {
            try await oversized.sign(transaction)
        }

        let maximal = try PQSigner(publicKey: key.publicKey) { _ in Data(repeating: 0xFF, count: 1538) }
        let signed = try await maximal.sign(transaction)
        let encoded = try signed.encode()
        #expect(encoded.containsSubsequence(bin16Header))

        let shortKey = PQSignature(
            scheme: .falcon1024,
            salt: 0,
            publicKey: Data(repeating: 0x01, count: 1792),
            signature: Data([0x01])
        )
        #expect(throws: TransactionAuthorizationError.self) {
            try SignedTransaction(transaction: transaction, authorization: .postQuantum(shortKey)).encode()
        }
    }

    // MARK: - Scheme tag and errors

    /// Falcon-1024's tag is the lowercase ASCII `"f1"`, two bytes, carried as a binary.
    @Test
    internal func testPostQuantumSchemeTag() throws {
        #expect(PQScheme.falcon1024.bytes == Data([0x66, 0x31]))
        #expect(PQScheme.falcon1024.description == "f1")

        let parsed = try PQScheme(bytes: Data("f1".utf8))
        #expect(parsed == .falcon1024)

        let reserved = try PQScheme(bytes: Data("f2".utf8))
        #expect(reserved != .falcon1024)
        #expect(reserved.description == "f2")

        #expect(throws: TransactionAuthorizationError.self) {
            try PQScheme(bytes: Data("f10".utf8))
        }
        #expect(throws: TransactionAuthorizationError.self) {
            try PQScheme(bytes: Data())
        }
    }

    /// Every error case describes itself, naming the addresses involved.
    @Test
    internal func testAuthorizationErrorsDescribeThemselves() throws {
        let sender = try CanonicalEncodingTests.accountA()
        let auth = try CanonicalEncodingTests.authAccount()

        let mismatch = TransactionAuthorizationError.authAddrMismatch(expected: auth, actual: sender)
        let unauthorized = TransactionAuthorizationError.unauthorizedProof(derived: auth, authorizer: sender)
        let malformed = TransactionAuthorizationError.malformed("detail")

        #expect(mismatch.errorDescription?.contains(auth.description) == true)
        #expect(mismatch.errorDescription?.contains(sender.description) == true)
        #expect(unauthorized.errorDescription?.contains(auth.description) == true)
        #expect(unauthorized.errorDescription?.contains(sender.description) == true)
        #expect(malformed.errorDescription == "Malformed authorization: detail")
    }
}

// MARK: - Test signers

/// Records every preimage handed to a signer.
fileprivate actor PreimageRecorder {
    fileprivate var preimages: [Data] = []

    fileprivate func record(_ preimage: Data) {
        preimages.append(preimage)
    }
}

/// A signer that returns a fixed authorization for a declared address.
fileprivate struct FixedSigner: TransactionSigner {
    fileprivate let address: Address
    fileprivate let authorization: TransactionAuthorization
    fileprivate let recorder: PreimageRecorder

    fileprivate func authorize(_ bytesToSign: Data) async throws -> TransactionAuthorization {
        await recorder.record(bytesToSign)
        return authorization
    }
}
