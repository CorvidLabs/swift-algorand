@preconcurrency import Foundation
import Testing
@testable import Algorand

/**
 Coverage for the two box-reference translation paths that the golden vectors do not reach.

 `CanonicalEncodingTests` pins the byte output for references that resolve to the current
 application or to an already-declared foreign application. The cases below are the ones with no
 recorded wire form: a reference to an application the caller never declared, which must extend
 `apfa`, and a reference that cannot be added because `apfa` is already full.
 */

/// Requirement evidence: REQ-algorand-006, REQ-algorand-015.
@Suite
internal struct CanonicalBoxReferenceTests {

    // MARK: - Fixtures

    private static let genesisID = "testnet-v1.0"
    private static let applicationID: UInt64 = 1284326447

    private func makeSender() throws -> Address {
        try Address(string: "2TVXIFN4ALYYL4BS2QF5RYBCMBOXZPW3734FA6JQMUUR4FI5YSLGIQWKAY")
    }

    private func makeGenesisHash() -> Data {
        Data(repeating: 0x5A, count: 32)
    }

    private func makeTransaction(
        foreignApps: [UInt64]?,
        boxes: [(UInt64, Data)]
    ) throws -> ApplicationCallTransaction {
        ApplicationCallTransaction.call(
            sender: try makeSender(),
            applicationID: Self.applicationID,
            foreignApps: foreignApps,
            boxes: boxes,
            fee: MicroAlgos(1000),
            firstValid: 51,
            lastValid: 1051,
            genesisID: Self.genesisID,
            genesisHash: makeGenesisHash()
        )
    }

    // MARK: - Tests

    /// A box on an undeclared application appends it to `apfa` and indexes it one-based.
    @Test
    internal func testUndeclaredApplicationIsAppendedToForeignApps() throws {
        let translation = try CanonicalBoxReferences(
            boxes: [(555, Data("b".utf8))],
            applicationID: Self.applicationID,
            foreignApplications: []
        )

        #expect(translation.foreignApplications == [555])
        #expect(translation.references.map(\.index) == [1])
    }

    /// Appending happens once per application, however many boxes name it.
    @Test
    internal func testRepeatedReferencesShareOneForeignAppSlot() throws {
        let translation = try CanonicalBoxReferences(
            boxes: [(555, Data("a".utf8)), (777, Data("b".utf8)), (555, Data("c".utf8))],
            applicationID: Self.applicationID,
            foreignApplications: [999]
        )

        #expect(translation.foreignApplications == [999, 555, 777])
        #expect(translation.references.map(\.index) == [2, 3, 2])
    }

    /// The called application and an explicit zero both mean "index 0", and neither extends `apfa`.
    @Test
    internal func testCurrentApplicationNeverExtendsForeignApps() throws {
        let translation = try CanonicalBoxReferences(
            boxes: [(0, Data("a".utf8)), (Self.applicationID, Data("b".utf8))],
            applicationID: Self.applicationID,
            foreignApplications: []
        )

        #expect(translation.foreignApplications.isEmpty)
        #expect(translation.references.map(\.index) == [0, 0])
    }

    /// Appending is emitted in the encoded transaction, not just in the translation.
    @Test
    internal func testEncodedTransactionCarriesTheAppendedForeignApp() throws {
        let transaction = try makeTransaction(foreignApps: nil, boxes: [(555, Data("b".utf8))])
        let encoded = try transaction.encode()

        // "apfa" as a fixstr key, then fixarray(1) holding uint16 555 (0xCD 0x02 0x2B).
        #expect(
            encoded.hexString.contains("a46170666191cd022b"),
            "The appended foreign application must appear in apfa: \(encoded.hexString)"
        )
        // "apbx" holding one map with i = 1.
        #expect(
            encoded.hexString.contains("a46170627891" + "82a16901a16ec40162"),
            "The box reference must carry the one-based index: \(encoded.hexString)"
        )
    }

    /// A reference that cannot be added throws rather than silently emitting an unresolvable index.
    @Test
    internal func testUnresolvableReferenceThrows() throws {
        let full: [UInt64] = [1, 2, 3, 4, 5, 6, 7, 8]
        #expect(full.count == CanonicalBoxReferences.maximumForeignApplications)

        do {
            _ = try CanonicalBoxReferences(
                boxes: [(999, Data("b".utf8))],
                applicationID: Self.applicationID,
                foreignApplications: full
            )
            Issue.record("Expected AlgorandError.invalidTransaction, but the translation succeeded")
        } catch AlgorandError.invalidTransaction(let message) {
            #expect(message.contains("999"), "The message must name the application: \(message)")
        } catch {
            Issue.record("Expected AlgorandError.invalidTransaction, got \(error)")
        }
    }

    /// The same failure must surface from `encode(groupID:)`, not only from the translator.
    @Test
    internal func testEncodingPropagatesTheUnresolvableReferenceError() throws {
        let transaction = try makeTransaction(
            foreignApps: [1, 2, 3, 4, 5, 6, 7, 8],
            boxes: [(999, Data("b".utf8))]
        )

        do {
            _ = try transaction.encode()
            Issue.record("Expected AlgorandError.invalidTransaction, but encode() succeeded")
        } catch AlgorandError.invalidTransaction {
            // The expected failure.
        } catch {
            Issue.record("Expected AlgorandError.invalidTransaction, got \(error)")
        }
    }
}
