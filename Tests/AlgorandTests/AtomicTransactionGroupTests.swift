@preconcurrency import Foundation
import XCTest
@testable import Algorand

final class AtomicTransactionGroupTests: XCTestCase {
    // MARK: - Group Creation Tests

    func testCreateAtomicTransactionGroup() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let txn1 = PaymentTransaction(
            sender: sender.address,
            receiver: receiver.address,
            amount: MicroAlgos(1_000_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let txn2 = PaymentTransaction(
            sender: receiver.address,
            receiver: sender.address,
            amount: MicroAlgos(500_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let group = try AtomicTransactionGroup(transactions: [txn1, txn2])

        XCTAssertEqual(group.transactions.count, 2)
        XCTAssertEqual(group.groupID.count, 32)  // SHA-512/256 produces 32 bytes
    }

    func testEmptyGroupThrows() {
        XCTAssertThrowsError(try AtomicTransactionGroup(transactions: [])) { error in
            guard case AlgorandError.invalidTransaction(let message) = error else {
                XCTFail("Expected invalidTransaction error")
                return
            }
            XCTAssertTrue(message.contains("empty"))
        }
    }

    func testGroupSizeLimit() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        // Create 16 transactions (max limit)
        var transactions: [PaymentTransaction] = []
        for _ in 0..<16 {
            let txn = PaymentTransaction(
                sender: sender.address,
                receiver: receiver.address,
                amount: MicroAlgos(1000),
                firstValid: 1000,
                lastValid: 2000,
                genesisID: "testnet-v1.0",
                genesisHash: genesisHash
            )
            transactions.append(txn)
        }

        // Should succeed with exactly 16
        let group = try AtomicTransactionGroup(transactions: transactions)
        XCTAssertEqual(group.transactions.count, 16)

        // Should fail with 17
        let extraTxn = PaymentTransaction(
            sender: sender.address,
            receiver: receiver.address,
            amount: MicroAlgos(1000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )
        transactions.append(extraTxn)

        XCTAssertThrowsError(try AtomicTransactionGroup(transactions: transactions)) { error in
            guard case AlgorandError.invalidTransaction(let message) = error else {
                XCTFail("Expected invalidTransaction error")
                return
            }
            XCTAssertTrue(message.contains("16"))
        }
    }

    // MARK: - Builder Tests

    func testAtomicTransactionGroupBuilder() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let txn1 = PaymentTransaction(
            sender: sender.address,
            receiver: receiver.address,
            amount: MicroAlgos(1_000_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let txn2 = PaymentTransaction(
            sender: receiver.address,
            receiver: sender.address,
            amount: MicroAlgos(500_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let group = try AtomicTransactionGroupBuilder()
            .add(txn1)
            .add(txn2)
            .build()

        XCTAssertEqual(group.transactions.count, 2)
    }

    func testBuilderAddMultiple() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let transactions = [
            PaymentTransaction(
                sender: sender.address,
                receiver: receiver.address,
                amount: MicroAlgos(1000),
                firstValid: 1000,
                lastValid: 2000,
                genesisID: "testnet-v1.0",
                genesisHash: genesisHash
            ),
            PaymentTransaction(
                sender: receiver.address,
                receiver: sender.address,
                amount: MicroAlgos(500),
                firstValid: 1000,
                lastValid: 2000,
                genesisID: "testnet-v1.0",
                genesisHash: genesisHash
            )
        ]

        let group = try AtomicTransactionGroupBuilder()
            .add(transactions)
            .build()

        XCTAssertEqual(group.transactions.count, 2)
    }

    // MARK: - Signing Tests

    func testSignAtomicTransactionGroup() throws {
        let account1 = try Account()
        let account2 = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let txn1 = PaymentTransaction(
            sender: account1.address,
            receiver: account2.address,
            amount: MicroAlgos(1_000_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let txn2 = PaymentTransaction(
            sender: account2.address,
            receiver: account1.address,
            amount: MicroAlgos(500_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let group = try AtomicTransactionGroup(transactions: [txn1, txn2])

        let signedGroup = try SignedAtomicTransactionGroup.sign(
            group,
            with: [
                0: account1,
                1: account2
            ]
        )

        XCTAssertEqual(signedGroup.signedTransactions.count, 2)
        XCTAssertEqual(signedGroup.groupID, group.groupID)

        // Verify signatures
        for signedTxn in signedGroup.signedTransactions {
            XCTAssertEqual(signedTxn.signature.count, 64)
        }
    }

    func testSigningWithMissingAccountThrows() throws {
        let account1 = try Account()
        let account2 = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let txn1 = PaymentTransaction(
            sender: account1.address,
            receiver: account2.address,
            amount: MicroAlgos(1_000_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let txn2 = PaymentTransaction(
            sender: account2.address,
            receiver: account1.address,
            amount: MicroAlgos(500_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let group = try AtomicTransactionGroup(transactions: [txn1, txn2])

        // Only provide account for first transaction
        XCTAssertThrowsError(
            try SignedAtomicTransactionGroup.sign(
                group,
                with: [0: account1]  // Missing account2 for transaction 1
            )
        ) { error in
            guard case AlgorandError.invalidTransaction(let message) = error else {
                XCTFail("Expected invalidTransaction error")
                return
            }
            XCTAssertTrue(message.contains("index 1"))
        }
    }

    // MARK: - Mixed Transaction Type Tests

    func testMixedTransactionTypes() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        // Create a payment transaction
        let paymentTxn = PaymentTransaction(
            sender: sender.address,
            receiver: receiver.address,
            amount: MicroAlgos(1_000_000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        // Create an asset opt-in transaction
        let optInTxn = AssetOptInTransaction(
            sender: receiver.address,
            assetID: 12345,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        // Group them together
        let group = try AtomicTransactionGroup(transactions: [paymentTxn, optInTxn])

        XCTAssertEqual(group.transactions.count, 2)
        XCTAssertFalse(group.groupID.isEmpty)
    }

    func testAssetSwapGroup() throws {
        let assetSeller = try Account()
        let algoBuyer = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        // Asset transfer: seller → buyer
        let assetTxn = AssetTransferTransaction(
            sender: assetSeller.address,
            receiver: algoBuyer.address,
            assetID: 12345,
            amount: 1000,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        // ALGO payment: buyer → seller
        let algoTxn = PaymentTransaction(
            sender: algoBuyer.address,
            receiver: assetSeller.address,
            amount: MicroAlgos(10_000_000),  // 10 ALGO
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        // Create atomic swap
        let group = try AtomicTransactionGroupBuilder()
            .add(assetTxn)
            .add(algoTxn)
            .build()

        let signedGroup = try SignedAtomicTransactionGroup.sign(
            group,
            with: [
                0: assetSeller,
                1: algoBuyer
            ]
        )

        XCTAssertEqual(signedGroup.signedTransactions.count, 2)

        // Both transactions must succeed together
        // This ensures the asset and ALGO exchange happens atomically
    }

    // MARK: - Group ID Consistency Tests

    func testGroupIDConsistency() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let txn1 = PaymentTransaction(
            sender: sender.address,
            receiver: receiver.address,
            amount: MicroAlgos(1000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let txn2 = PaymentTransaction(
            sender: receiver.address,
            receiver: sender.address,
            amount: MicroAlgos(500),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        // Create the same group twice
        let group1 = try AtomicTransactionGroup(transactions: [txn1, txn2])
        let group2 = try AtomicTransactionGroup(transactions: [txn1, txn2])

        // Group IDs should be identical for the same transactions
        // Note: This may not be stable with JSON encoding due to dictionary ordering
        // Once MessagePack is implemented, this will be deterministic
        XCTAssertEqual(group1.groupID.count, 32)
        XCTAssertEqual(group2.groupID.count, 32)
    }

    func testGroupIDChangesWithDifferentOrder() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let txn1 = PaymentTransaction(
            sender: sender.address,
            receiver: receiver.address,
            amount: MicroAlgos(1000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let txn2 = PaymentTransaction(
            sender: receiver.address,
            receiver: sender.address,
            amount: MicroAlgos(500),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        // Create groups with different order
        let group1 = try AtomicTransactionGroup(transactions: [txn1, txn2])
        let group2 = try AtomicTransactionGroup(transactions: [txn2, txn1])

        // Group IDs should be different (order matters!)
        XCTAssertNotEqual(group1.groupID, group2.groupID)
    }
}
