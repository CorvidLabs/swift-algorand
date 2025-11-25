@preconcurrency import Foundation
import XCTest
@testable import Algorand

final class AssetTests: XCTestCase {
    // MARK: - AssetParams Tests

    func testAssetParamsDecimalConversion() {
        let params = AssetParams(
            total: 1_000_000,
            decimals: 2,
            defaultFrozen: false
        )

        // Test converting decimal to base units
        XCTAssertEqual(params.toBaseUnits(10.5), 1050)
        XCTAssertEqual(params.toBaseUnits(100.0), 10_000)
        XCTAssertEqual(params.toBaseUnits(0.01), 1)

        // Test converting base units to decimal
        XCTAssertEqual(params.toDecimal(1050), 10.5)
        XCTAssertEqual(params.toDecimal(10_000), 100.0)
        XCTAssertEqual(params.toDecimal(1), 0.01)
    }

    func testAssetParamsZeroDecimals() {
        let params = AssetParams(
            total: 100,
            decimals: 0,  // NFT or integer-only token
            defaultFrozen: false
        )

        XCTAssertEqual(params.toBaseUnits(5.0), 5)
        XCTAssertEqual(params.toDecimal(5), 5.0)
    }

    func testAssetParamsHighDecimals() {
        let params = AssetParams(
            total: 1_000_000_000_000,
            decimals: 6,  // Like USDC
            defaultFrozen: false
        )

        XCTAssertEqual(params.toBaseUnits(1.5), 1_500_000)
        XCTAssertEqual(params.toDecimal(1_500_000), 1.5)
    }

    // MARK: - AssetCreateTransaction Tests

    func testAssetCreateTransactionEncoding() throws {
        let sender = try Address(string: "VJMUDJFJNRXCBGGIIBMBBYK26ZXNJT4RNWUNHZ7VNM54TWF33S7SB6XDQI")
        let genesisHash = Data(repeating: 0, count: 32)

        let assetParams = AssetParams(
            total: 1_000_000,
            decimals: 2,
            defaultFrozen: false,
            unitName: "TEST",
            assetName: "Test Token",
            url: "https://test.com",
            metadataHash: nil,
            manager: sender,
            reserve: sender,
            freeze: sender,
            clawback: sender
        )

        let transaction = AssetCreateTransaction(
            sender: sender,
            assetParams: assetParams,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let encoded = try transaction.encode(groupID: nil)
        XCTAssertFalse(encoded.isEmpty)

        // Verify it's valid MessagePack
        // Just check that encoding produces binary data
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testAssetCreateNFT() throws {
        let creator = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let nftParams = AssetParams(
            total: 1,      // Only 1 exists
            decimals: 0,   // No fractional ownership
            defaultFrozen: false,
            unitName: "NFT",
            assetName: "My NFT",
            url: "ipfs://Qm...",
            metadataHash: nil,
            manager: creator.address,
            reserve: creator.address,
            freeze: nil,
            clawback: nil
        )

        let transaction = AssetCreateTransaction(
            sender: creator.address,
            assetParams: nftParams,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let encoded = try transaction.encode(groupID: nil)
        XCTAssertFalse(encoded.isEmpty)

        // Verify it's valid MessagePack binary data
        XCTAssertGreaterThan(encoded.count, 0)
    }

    // MARK: - AssetOptInTransaction Tests

    func testAssetOptInTransactionEncoding() throws {
        let account = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let transaction = AssetOptInTransaction(
            sender: account.address,
            assetID: 12345,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let encoded = try transaction.encode(groupID: nil)
        XCTAssertFalse(encoded.isEmpty)

        // Verify it's valid MessagePack binary data
        XCTAssertGreaterThan(encoded.count, 0)
    }

    // MARK: - AssetTransferTransaction Tests

    func testAssetTransferTransactionEncoding() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let transaction = AssetTransferTransaction(
            sender: sender.address,
            receiver: receiver.address,
            assetID: 12345,
            amount: 1000,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let encoded = try transaction.encode(groupID: nil)
        XCTAssertFalse(encoded.isEmpty)

        // Verify it's valid MessagePack binary data
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testAssetTransferWithCloseout() throws {
        let sender = try Account()
        let receiver = try Account()
        let closeToAddress = try Account().address
        let genesisHash = Data(repeating: 0, count: 32)

        let transaction = AssetTransferTransaction(
            sender: sender.address,
            receiver: receiver.address,
            assetID: 12345,
            amount: 1000,
            closeRemainderTo: closeToAddress,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let encoded = try transaction.encode(groupID: nil)
        XCTAssertFalse(encoded.isEmpty)

        // Verify it's valid MessagePack binary data
        XCTAssertGreaterThan(encoded.count, 0)
    }

    // MARK: - Transaction Signing Tests

    func testSignAssetCreateTransaction() throws {
        let creator = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let assetParams = AssetParams(
            total: 1000,
            decimals: 0,
            defaultFrozen: false,
            unitName: "TEST",
            assetName: "Test"
        )

        let transaction = AssetCreateTransaction(
            sender: creator.address,
            assetParams: assetParams,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let signedTxn = try SignedTransaction.sign(transaction, with: creator)

        XCTAssertEqual(signedTxn.signature.count, 64)  // Ed25519 signature is 64 bytes
        XCTAssertFalse(try signedTxn.id().isEmpty)
    }

    func testSignAssetOptInTransaction() throws {
        let account = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let transaction = AssetOptInTransaction(
            sender: account.address,
            assetID: 12345,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let signedTxn = try SignedTransaction.sign(transaction, with: account)

        XCTAssertEqual(signedTxn.signature.count, 64)
    }

    func testSignAssetTransferTransaction() throws {
        let sender = try Account()
        let receiver = try Account()
        let genesisHash = Data(repeating: 0, count: 32)

        let transaction = AssetTransferTransaction(
            sender: sender.address,
            receiver: receiver.address,
            assetID: 12345,
            amount: 1000,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: genesisHash
        )

        let signedTxn = try SignedTransaction.sign(transaction, with: sender)

        XCTAssertEqual(signedTxn.signature.count, 64)
    }
}
