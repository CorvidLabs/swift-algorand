import XCTest
@testable import Algorand

final class ApplicationTransactionTests: XCTestCase {
    func testApplicationCreate() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")
        let approvalProgram = Data([0x06, 0x81, 0x01]) // Simple TEAL program
        let clearProgram = Data([0x06, 0x81, 0x01])
        let globalSchema = StateSchema(numUint: 2, numByteSlice: 3)
        let localSchema = StateSchema(numUint: 1, numByteSlice: 1)

        let txn = ApplicationCallTransaction.create(
            sender: sender,
            approvalProgram: approvalProgram,
            clearStateProgram: clearProgram,
            globalStateSchema: globalSchema,
            localStateSchema: localSchema,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.applicationID, 0) // 0 means creation
        XCTAssertEqual(txn.onCompletion, .noOp)
        XCTAssertEqual(txn.approvalProgram, approvalProgram)
        XCTAssertEqual(txn.clearStateProgram, clearProgram)
        XCTAssertEqual(txn.globalStateSchema?.numUint, 2)
        XCTAssertEqual(txn.globalStateSchema?.numByteSlice, 3)
        XCTAssertEqual(txn.localStateSchema?.numUint, 1)
        XCTAssertEqual(txn.localStateSchema?.numByteSlice, 1)

        // Test encoding doesn't throw
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testApplicationCall() throws {
        let sender = try Account().address
        let appID: UInt64 = 12345
        let args = [
            Data("arg1".utf8),
            Data("arg2".utf8)
        ]
        let account1 = try Account().address
        let accounts = [account1]

        let txn = ApplicationCallTransaction.call(
            sender: sender,
            applicationID: appID,
            appArguments: args,
            accounts: accounts,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.applicationID, appID)
        XCTAssertEqual(txn.onCompletion, .noOp)
        XCTAssertEqual(txn.appArguments?.count, 2)
        XCTAssertEqual(txn.accounts?.count, 1)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testApplicationOptIn() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")

        let txn = ApplicationCallTransaction.optIn(
            sender: sender,
            applicationID: 999,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.onCompletion, .optIn)
        XCTAssertEqual(txn.applicationID, 999)
    }

    func testApplicationCloseOut() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")

        let txn = ApplicationCallTransaction.closeOut(
            sender: sender,
            applicationID: 999,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.onCompletion, .closeOut)
        XCTAssertEqual(txn.applicationID, 999)
    }

    func testApplicationClearState() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")

        let txn = ApplicationCallTransaction.clearState(
            sender: sender,
            applicationID: 999,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.onCompletion, .clearState)
    }

    func testApplicationUpdate() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")
        let newApprovalProgram = Data([0x06, 0x81, 0x02])
        let newClearProgram = Data([0x06, 0x81, 0x02])

        let txn = ApplicationCallTransaction.update(
            sender: sender,
            applicationID: 999,
            approvalProgram: newApprovalProgram,
            clearStateProgram: newClearProgram,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.onCompletion, .updateApplication)
        XCTAssertEqual(txn.approvalProgram, newApprovalProgram)
    }

    func testApplicationDelete() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")

        let txn = ApplicationCallTransaction.delete(
            sender: sender,
            applicationID: 999,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.onCompletion, .deleteApplication)
        XCTAssertEqual(txn.applicationID, 999)
    }

    func testApplicationWithForeignAppsAndAssets() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")

        let txn = ApplicationCallTransaction.call(
            sender: sender,
            applicationID: 100,
            foreignApps: [200, 300],
            foreignAssets: [400, 500, 600],
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.foreignApps?.count, 2)
        XCTAssertEqual(txn.foreignAssets?.count, 3)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testApplicationWithBoxes() throws {
        let sender = try Address(string: "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM")
        let boxes: [(UInt64, Data)] = [
            (0, Data("box1".utf8)),
            (100, Data("box2".utf8))
        ]

        let txn = ApplicationCallTransaction.call(
            sender: sender,
            applicationID: 100,
            boxes: boxes,
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(count: 32)
        )

        XCTAssertEqual(txn.boxes?.count, 2)

        // Test encoding
        let encoded = try txn.encode()
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testApplicationSigning() throws {
        let account = try Account()
        let sender = account.address

        let txn = ApplicationCallTransaction.call(
            sender: sender,
            applicationID: 12345,
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
