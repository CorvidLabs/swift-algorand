import Foundation
import Testing
@testable import Algorand

/// Post-quantum golden-vector tests owned by the envelope change: the edwards25519 point predicate
/// against Go's `Point.SetBytes` semantics, the post-quantum address derivations, and the signed
/// post-quantum envelope. Fixtures live in `PostQuantumVectors`.
/// Requirement evidence: REQ-algorand-020, REQ-algorand-021, REQ-algorand-022.
@Suite
internal struct PostQuantumVectorTests {

    /// The point predicate must follow `edwards25519.Point.SetBytes`: non-canonical encodings
    /// (`y >= p`, sign bit set with `x == 0`) are points, and subgroup membership is irrelevant.
    @Test
    internal func testEdwards25519PointPredicateMatchesGoSetBytes() throws {
        for vector in PostQuantumVectors.ed25519DecodeCases {
            let encoded = try hexData(vector.encodingHex)
            #expect(
                Edwards25519.isPoint(encoded) == vector.isPoint,
                "\(vector.encodingHex) must \(vector.isPoint ? "" : "not ")decode as an Edwards25519 point"
            )
        }

        #expect(!Edwards25519.isPoint(Data(repeating: 0x58, count: 31)), "Only 32-byte encodings are points.")
    }

    /// Canonical salt and address for each golden key: the lowest salt in 0...255 whose
    /// `SHA512_256("PQA" + "f1" + salt + publicKey)` is not an Edwards25519 point.
    @Test
    internal func testPostQuantumAddressDerivationMatchesGoldenVectors() throws {
        #expect(PQScheme.falcon1024.description == PostQuantumVectors.pqSchemeFalcon1024)

        for vector in PostQuantumVectors.pqAddressCases {
            let publicKey = try hexData(vector.publicKeyHex)
            #expect(publicKey.count == PostQuantumVectors.falconDet1024PublicKeySize)

            let derived = try Address.postQuantum(scheme: .falcon1024, publicKey: publicKey)
            #expect(Int(derived.salt) == vector.salt, "canonical salt differs for \(vector.address)")
            #expect(derived.address.description == vector.address)
            #expect(derived.address.isPostQuantumCompliant)

            let explicit = try Address.postQuantum(scheme: .falcon1024, salt: UInt8(vector.salt), publicKey: publicKey)
            #expect(explicit == derived.address)

            // Every lower salt was rejected because its digest decodes as a point.
            for rejected in 0..<vector.salt {
                let address = try Address.postQuantum(scheme: .falcon1024, salt: UInt8(rejected), publicKey: publicKey)
                #expect(!address.isPostQuantumCompliant, "salt \(rejected) must be an Edwards25519 point")
            }
        }
    }

    /// Golden vector `pq_signed_payment`: a 2-key map {pqsig, txn}, where pqsig is
    /// {pk: bin16(1793), sch: bin8("f1"), sig: bin16(1538)} with `slt` omitted because the canonical
    /// salt is 0, and no `sgnr` because the post-quantum address is the sender.
    @Test
    internal func testPostQuantumSignedEnvelopeMatchesGoldenVector() async throws {
        let vector = PostQuantumVectors.pqAddressCases[0]
        let publicKey = try hexData(vector.publicKeyHex)
        let signature = try hexData(PostQuantumVectors.pqSignatureHex)
        #expect(signature.count == PostQuantumVectors.falconDet1024SignatureSize)

        let signer = try PQSigner(publicKey: publicKey) { _ in signature }
        #expect(signer.salt == 0)
        #expect(signer.address.description == vector.address)

        let transaction = PaymentTransaction(
            sender: signer.address,
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: MicroAlgos(1000),
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: try CanonicalEncodingTests.genesisHash()
        )
        let signed = try await signer.sign(transaction)
        let encoded = try signed.encode()

        let transactionID = try signed.id()
        #expect(signed.authAddr == nil)
        #expect(signed.signature == signature)
        #expect(encoded.count == 3530)
        #expect(encoded.hexString == PostQuantumVectors.pqSignedPaymentHex)
        #expect(transactionID == PostQuantumVectors.pqSignedPaymentTxID)
    }
}
