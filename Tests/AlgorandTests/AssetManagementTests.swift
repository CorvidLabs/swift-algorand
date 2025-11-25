import XCTest
@testable import Algorand

final class AssetManagementTests: XCTestCase {
    func testAssetFreeze() throws {
        let sender = try Account().address
        let freezeAccount = try Account().address
        let assetID: UInt64 = 12345

        let txn = AssetFreezeTransaction(
            sender: sender,
            assetID: assetID,
            freezeAccount: freezeAccount,
            frozen: true,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.assetID, assetID)
        XCTAssertEqual(txn.freezeAccount, freezeAccount)
        XCTAssertEqual(txn.frozen, true)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testAssetUnfreeze() throws {
        let sender = try Account().address
        let freezeAccount = try Account().address

        let txn = AssetFreezeTransaction(
            sender: sender,
            assetID: 12345,
            freezeAccount: freezeAccount,
            frozen: false,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.frozen, false)
    }

    func testAssetDestroy() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")
        let assetID: UInt64 = 12345

        let txn = AssetConfigTransaction.destroy(
            sender: sender,
            assetID: assetID,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.assetID, assetID)
        XCTAssertNil(txn.manager)
        XCTAssertNil(txn.reserve)
        XCTAssertNil(txn.freeze)
        XCTAssertNil(txn.clawback)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testAssetUpdate() throws {
        let sender = try Account().address
        let newManager = try Account().address
        let newReserve = try Account().address
        let assetID: UInt64 = 12345

        let txn = AssetConfigTransaction.update(
            sender: sender,
            assetID: assetID,
            manager: newManager,
            reserve: newReserve,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.assetID, assetID)
        XCTAssertEqual(txn.manager, newManager)
        XCTAssertEqual(txn.reserve, newReserve)
        XCTAssertNil(txn.freeze)
        XCTAssertNil(txn.clawback)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testAssetUpdateAllAddresses() throws {
        let sender = try Account().address
        let manager = try Account().address
        let reserve = try Account().address
        let freeze = try Account().address
        let clawback = try Account().address

        let txn = AssetConfigTransaction.update(
            sender: sender,
            assetID: 12345,
            manager: manager,
            reserve: reserve,
            freeze: freeze,
            clawback: clawback,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.manager, manager)
        XCTAssertEqual(txn.reserve, reserve)
        XCTAssertEqual(txn.freeze, freeze)
        XCTAssertEqual(txn.clawback, clawback)
    }

    func testAssetFreezeSigning() throws {
        let account = try Account()
        let sender = account.address
        let freezeAccount = try Account().address

        let txn = AssetFreezeTransaction(
            sender: sender,
            assetID: 12345,
            freezeAccount: freezeAccount,
            frozen: true,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        let signedTxn = try SignedTransaction.sign(txn, with: account)
        XCTAssertGreaterThan(signedTxn.signature.count, 0)
        XCTAssertFalse(try signedTxn.id().isEmpty)
    }

    func testAssetDestroySigning() throws {
        let account = try Account()
        let sender = account.address

        let txn = AssetConfigTransaction.destroy(
            sender: sender,
            assetID: 12345,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        let signedTxn = try SignedTransaction.sign(txn, with: account)
        XCTAssertGreaterThan(signedTxn.signature.count, 0)
        XCTAssertFalse(try signedTxn.id().isEmpty)
    }
}
