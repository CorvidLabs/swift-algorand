import XCTest
@testable import Algorand

final class KeyRegistrationTests: XCTestCase {
    func testKeyRegistrationOnline() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")
        let votePK = Data(count: 32) // 32 bytes for voting key
        let selectionPK = Data(count: 32) // 32 bytes for selection key
        let stateProofPK = Data(count: 64) // 64 bytes for state proof key

        let txn = KeyRegistrationTransaction.online(
            sender: sender,
            votePK: votePK,
            selectionPK: selectionPK,
            voteFirst: 1000,
            voteLast: 2000,
            voteKeyDilution: 10,
            stateProofPK: stateProofPK,
            firstValid: 100,
            lastValid: 500,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.votePK, votePK)
        XCTAssertEqual(txn.selectionPK, selectionPK)
        XCTAssertEqual(txn.voteFirst, 1000)
        XCTAssertEqual(txn.voteLast, 2000)
        XCTAssertEqual(txn.voteKeyDilution, 10)
        XCTAssertEqual(txn.stateProofPK, stateProofPK)
        XCTAssertNil(txn.nonparticipation)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testKeyRegistrationOffline() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")

        let txn = KeyRegistrationTransaction.offline(
            sender: sender,
            firstValid: 100,
            lastValid: 500,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertNil(txn.votePK)
        XCTAssertNil(txn.selectionPK)
        XCTAssertNil(txn.voteFirst)
        XCTAssertNil(txn.voteLast)
        XCTAssertNil(txn.voteKeyDilution)
        XCTAssertNil(txn.nonparticipation)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testKeyRegistrationNonparticipating() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")

        let txn = KeyRegistrationTransaction.nonparticipating(
            sender: sender,
            firstValid: 100,
            lastValid: 500,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.nonparticipation, true)
        XCTAssertNil(txn.votePK)
        XCTAssertNil(txn.selectionPK)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testKeyRegistrationSigning() throws {
        let account = try Account()
        let sender = account.address
        let votePK = Data(count: 32)
        let selectionPK = Data(count: 32)

        let txn = KeyRegistrationTransaction.online(
            sender: sender,
            votePK: votePK,
            selectionPK: selectionPK,
            voteFirst: 1000,
            voteLast: 2000,
            voteKeyDilution: 10,
            firstValid: 100,
            lastValid: 500,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        let signedTxn = try SignedTransaction.sign(txn, with: account)
        XCTAssertGreaterThan(signedTxn.signature.count, 0)
        XCTAssertFalse(try signedTxn.id().isEmpty)
    }
}
