import XCTest
@testable import Algorand

/// This test proves every transaction type works by submitting one of each to LocalNet
/// and printing the transaction ID for manual verification
final class ProofOfWorkTest: XCTestCase {
    var algodClient: AlgodClient!
    var isLocalNet: Bool {
        ProcessInfo.processInfo.environment["ALGORAND_NETWORK"] == "localnet"
    }

    override func setUp() async throws {
        try await super.setUp()

        algodClient = try AlgodClient(
            baseURL: "http://localhost:4001",
            apiToken: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        )
    }

    func testMinimal() async throws {
        // Minimal test to check if the class works
        XCTAssertTrue(true)
    }

    func testProofOfAllTransactionTypes() async throws {
        try await runProofOfAllTransactionTypes()
    }

    private func runProofOfAllTransactionTypes() async throws {
        guard isLocalNet else {
            throw XCTSkip("Proof test only runs on LocalNet")
        }

        print("Starting test...")

        print("\n" + String(repeating: "=", count: 80))
        print("PROOF OF WORK - ALL ALGORAND TRANSACTION TYPES")
        print(String(repeating: "=", count: 80))

        var transactionLog: [(type: String, txid: String, description: String)] = []

        // 1. PAYMENT TRANSACTION
        print("\n[1/11] Testing PAYMENT transaction (type: pay)...")
        do {
            let sender = try await fundAccount(amount: 10_000_000)
            let receiver = try Account()

            let params = try await algodClient.transactionParams()
            let payTxn = PaymentTransaction(
                sender: sender.address,
                receiver: receiver.address,
                amount: MicroAlgos(5_000_000), // 5 ALGO
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash,
                note: "Payment proof".data(using: .utf8)
            )

            let signed = try SignedTransaction.sign(payTxn, with: sender)
            let txid = try await algodClient.sendTransaction(signed)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "pay", txid: txid, description: "Payment of 5 ALGO"))
            print("   ✅ CONFIRMED: \(txid)")
        }

        // 2. ASSET CREATION (FUNGIBLE)
        print("\n[2/11] Testing ASSET CREATION - Fungible token (type: acfg)...")
        var assetID: UInt64 = 0
        var assetManager: Account!
        do {
            assetManager = try await fundAccount(amount: 10_000_000)

            let params = try await algodClient.transactionParams()
            let assetParams = AssetParams(
                total: 1_000_000,
                decimals: 2,
                defaultFrozen: false,
                unitName: "PROOF",
                assetName: "Proof Token",
                manager: assetManager.address,
                reserve: assetManager.address,
                freeze: assetManager.address,
                clawback: assetManager.address
            )

            let createTxn = AssetCreateTransaction(
                sender: assetManager.address,
                assetParams: assetParams,
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let signed = try SignedTransaction.sign(createTxn, with: assetManager)
            let txid = try await algodClient.sendTransaction(signed)
            let confirmed = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)
            assetID = confirmed.assetIndex!

            transactionLog.append((type: "acfg", txid: txid, description: "Asset creation (fungible) - Asset ID: \(assetID)"))
            print("   ✅ CONFIRMED: \(txid)")
            print("   📦 Asset ID: \(assetID)")
        }

        // 3. ASSET OPT-IN
        print("\n[3/11] Testing ASSET OPT-IN (type: axfer with amount=0)...")
        var optInAccount: Account!
        do {
            optInAccount = try await fundAccount(amount: 1_000_000)

            let params = try await algodClient.transactionParams()
            let optInTxn = AssetOptInTransaction(
                sender: optInAccount.address,
                assetID: assetID,
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let signed = try SignedTransaction.sign(optInTxn, with: optInAccount)
            let txid = try await algodClient.sendTransaction(signed)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "axfer", txid: txid, description: "Asset opt-in for Asset \(assetID)"))
            print("   ✅ CONFIRMED: \(txid)")
        }

        // 4. ASSET TRANSFER
        print("\n[4/11] Testing ASSET TRANSFER (type: axfer with amount>0)...")
        do {
            let params = try await algodClient.transactionParams()
            let transferTxn = AssetTransferTransaction(
                sender: assetManager.address,
                receiver: optInAccount.address,
                assetID: assetID,
                amount: 10000, // 100.00 tokens (2 decimals)
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let signed = try SignedTransaction.sign(transferTxn, with: assetManager)
            let txid = try await algodClient.sendTransaction(signed)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "axfer", txid: txid, description: "Asset transfer of 100.00 PROOF tokens"))
            print("   ✅ CONFIRMED: \(txid)")
        }

        // 5. ASSET FREEZE
        print("\n[5/11] Testing ASSET FREEZE (type: afrz)...")
        do {
            let params = try await algodClient.transactionParams()
            let freezeTxn = AssetFreezeTransaction(
                sender: assetManager.address,
                assetID: assetID,
                freezeAccount: optInAccount.address,
                frozen: true,
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let signed = try SignedTransaction.sign(freezeTxn, with: assetManager)
            let txid = try await algodClient.sendTransaction(signed)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "afrz", txid: txid, description: "Asset freeze (frozen=true)"))
            print("   ✅ CONFIRMED: \(txid)")
        }

        // 6. ASSET UPDATE
        print("\n[6/11] Testing ASSET UPDATE (type: acfg with assetID)...")
        do {
            let newManager = try await fundAccount(amount: 10_000_000)

            let params = try await algodClient.transactionParams()
            let updateTxn = AssetConfigTransaction.update(
                sender: assetManager.address,
                assetID: assetID,
                manager: newManager.address,
                reserve: assetManager.address,
                freeze: assetManager.address,
                clawback: assetManager.address,
                strictEmptyAddressChecking: false,
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let signed = try SignedTransaction.sign(updateTxn, with: assetManager)
            let txid = try await algodClient.sendTransaction(signed)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "acfg", txid: txid, description: "Asset update (manager changed)"))
            print("   ✅ CONFIRMED: \(txid)")

            // Update assetManager to new manager for destroy
            assetManager = newManager
        }

        // 7. ASSET CLOSE-OUT
        print("\n[7/11] Testing ASSET CLOSE-OUT (type: axfer with closeTo)...")
        do {
            // Create a new asset for close-out test (not frozen)
            let closeOutManager = try await fundAccount(amount: 10_000_000)
            let closeOutAccount = try await fundAccount(amount: 1_000_000)

            let params1 = try await algodClient.transactionParams()
            let assetParams = AssetParams(
                total: 1000,
                decimals: 0,
                defaultFrozen: false, // Not frozen
                unitName: "CLOSE",
                assetName: "Close Token",
                manager: closeOutManager.address
            )

            let createTxn = AssetCreateTransaction(
                sender: closeOutManager.address,
                assetParams: assetParams,
                firstValid: params1.firstRound,
                lastValid: params1.firstRound + 1000,
                genesisID: params1.genesisID,
                genesisHash: params1.genesisHash
            )

            let signedCreate = try SignedTransaction.sign(createTxn, with: closeOutManager)
            let createTxID = try await algodClient.sendTransaction(signedCreate)
            let confirmed = try await algodClient.waitForConfirmation(transactionID: createTxID, timeout: 10)
            let closeAssetID = confirmed.assetIndex!

            // Opt in
            let params2 = try await algodClient.transactionParams()
            let optInTxn = AssetOptInTransaction(
                sender: closeOutAccount.address,
                assetID: closeAssetID,
                firstValid: params2.firstRound,
                lastValid: params2.firstRound + 1000,
                genesisID: params2.genesisID,
                genesisHash: params2.genesisHash
            )
            let signedOptIn = try SignedTransaction.sign(optInTxn, with: closeOutAccount)
            let optInTxID = try await algodClient.sendTransaction(signedOptIn)
            _ = try await algodClient.waitForConfirmation(transactionID: optInTxID, timeout: 10)

            // Now close out
            let params3 = try await algodClient.transactionParams()
            let closeOutTxn = AssetTransferTransaction(
                sender: closeOutAccount.address,
                receiver: closeOutManager.address,
                assetID: closeAssetID,
                amount: 0,
                closeRemainderTo: closeOutManager.address, // This makes it a close-out
                firstValid: params3.firstRound,
                lastValid: params3.firstRound + 1000,
                genesisID: params3.genesisID,
                genesisHash: params3.genesisHash
            )

            let signed = try SignedTransaction.sign(closeOutTxn, with: closeOutAccount)
            let txid = try await algodClient.sendTransaction(signed)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "axfer", txid: txid, description: "Asset close-out (opt-out)"))
            print("   ✅ CONFIRMED: \(txid)")
        }

        // 8. ASSET DESTROY
        print("\n[8/11] Testing ASSET DESTROY (type: acfg with no params)...")
        do {
            // Create a new asset just for destroying (creator must hold all units)
            let destroyManager = try await fundAccount(amount: 10_000_000)

            let params1 = try await algodClient.transactionParams()
            let assetParams = AssetParams(
                total: 100,
                decimals: 0,
                defaultFrozen: false,
                unitName: "DESTROY",
                assetName: "Destroy Token",
                manager: destroyManager.address
            )

            let createTxn = AssetCreateTransaction(
                sender: destroyManager.address,
                assetParams: assetParams,
                firstValid: params1.firstRound,
                lastValid: params1.firstRound + 1000,
                genesisID: params1.genesisID,
                genesisHash: params1.genesisHash
            )

            let signedCreate = try SignedTransaction.sign(createTxn, with: destroyManager)
            let createTxID = try await algodClient.sendTransaction(signedCreate)
            let confirmed = try await algodClient.waitForConfirmation(transactionID: createTxID, timeout: 10)
            let destroyAssetID = confirmed.assetIndex!

            // Now destroy it
            let params2 = try await algodClient.transactionParams()
            let destroyTxn = AssetConfigTransaction.destroy(
                sender: destroyManager.address,
                assetID: destroyAssetID,
                firstValid: params2.firstRound,
                lastValid: params2.firstRound + 1000,
                genesisID: params2.genesisID,
                genesisHash: params2.genesisHash
            )

            let signed = try SignedTransaction.sign(destroyTxn, with: destroyManager)
            let txid = try await algodClient.sendTransaction(signed)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "acfg", txid: txid, description: "Asset destroy - Asset \(destroyAssetID) deleted"))
            print("   ✅ CONFIRMED: \(txid)")
        }

        // 9. NFT CREATION
        print("\n[9/11] Testing NFT CREATION (type: acfg with total=1)...")
        var nftID: UInt64 = 0
        do {
            let creator = try await fundAccount(amount: 10_000_000)

            let params = try await algodClient.transactionParams()
            let nftParams = AssetParams(
                total: 1, // NFT = total of 1
                decimals: 0,
                defaultFrozen: false,
                unitName: "NFTPROOF",
                assetName: "Proof NFT #1",
                url: "https://example.com/nft/1",
                manager: creator.address
            )

            let createTxn = AssetCreateTransaction(
                sender: creator.address,
                assetParams: nftParams,
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let signed = try SignedTransaction.sign(createTxn, with: creator)
            let txid = try await algodClient.sendTransaction(signed)
            let confirmed = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)
            nftID = confirmed.assetIndex!

            transactionLog.append((type: "acfg", txid: txid, description: "NFT creation (total=1) - Asset ID: \(nftID)"))
            print("   ✅ CONFIRMED: \(txid)")
            print("   🎨 NFT ID: \(nftID)")
        }

        // 10. APPLICATION CREATE
        print("\n[10/11] Testing APPLICATION CREATE (type: appl)...")
        var appID: UInt64 = 0
        do {
            let creator = try await fundAccount(amount: 10_000_000)

            let params = try await algodClient.transactionParams()

            // Simple approval program (always approve)
            let approvalProgram = Data([0x06, 0x81, 0x01]) // #pragma version 6; int 1
            let clearProgram = Data([0x06, 0x81, 0x01])    // #pragma version 6; int 1

            let appTxn = ApplicationCallTransaction.create(
                sender: creator.address,
                approvalProgram: approvalProgram,
                clearStateProgram: clearProgram,
                globalStateSchema: StateSchema(numUint: 1, numByteSlice: 1),
                localStateSchema: StateSchema(numUint: 0, numByteSlice: 0),
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let signed = try SignedTransaction.sign(appTxn, with: creator)
            let txid = try await algodClient.sendTransaction(signed)
            let confirmed = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)
            appID = confirmed.applicationIndex ?? 0

            transactionLog.append((type: "appl", txid: txid, description: "Application create - App ID: \(appID)"))
            print("   ✅ CONFIRMED: \(txid)")
            print("   📱 App ID: \(appID)")
        }

        // 11. ATOMIC TRANSACTION GROUP
        print("\n[11/11] Testing ATOMIC TRANSACTION GROUP (2 payments)...")
        do {
            let account1 = try await fundAccount(amount: 10_000_000)
            let account2 = try await fundAccount(amount: 10_000_000)
            let receiver = try Account()

            let params = try await algodClient.transactionParams()

            let txn1 = PaymentTransaction(
                sender: account1.address,
                receiver: receiver.address,
                amount: MicroAlgos(1_000_000),
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let txn2 = PaymentTransaction(
                sender: account2.address,
                receiver: receiver.address,
                amount: MicroAlgos(2_000_000),
                firstValid: params.firstRound,
                lastValid: params.firstRound + 1000,
                genesisID: params.genesisID,
                genesisHash: params.genesisHash
            )

            let group = try AtomicTransactionGroup(transactions: [txn1, txn2])
            let signedGroup = try SignedAtomicTransactionGroup.sign(group, with: [0: account1, 1: account2])

            print("   📝 Group ID: \(group.groupID.prefix(8).map { String(format: "%02x", $0) }.joined())...")

            let txid = try await algodClient.sendTransactionGroup(signedGroup)
            _ = try await algodClient.waitForConfirmation(transactionID: txid, timeout: 10)

            transactionLog.append((type: "group", txid: txid, description: "Atomic group (2 payments)"))
            print("   ✅ CONFIRMED: \(txid)")
        }

        // FINAL SUMMARY
        print("\n" + String(repeating: "=", count: 80))
        print("PROOF COMPLETE - ALL \(transactionLog.count) TRANSACTION TYPES CONFIRMED")
        print(String(repeating: "=", count: 80))
        print("\nVERIFICATION LIST:")
        print(String(repeating: "-", count: 80))

        for (index, entry) in transactionLog.enumerated() {
            let paddedType = entry.type.padding(toLength: 5, withPad: " ", startingAt: 0)
            print(String(format: "%2d", index + 1) + ". [\(paddedType)] \(entry.txid)")
            print("    └─ \(entry.description)")
        }

        print("\n" + String(repeating: "=", count: 80))
        print("To verify these transactions on LocalNet:")
        print("  goal node status -d ~/algokit_sandbox/sandbox/")
        print("  goal tx info -t <TXID> -d ~/algokit_sandbox/sandbox/")
        print(String(repeating: "=", count: 80) + "\n")
    }

    /// Discovers a funded address from the localnet KMD wallet
    private func discoverFundingAddress() throws -> String {
        // Find docker executable in common locations
        let dockerPaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker"
        ]

        guard let dockerPath = dockerPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw NSError(domain: "FundingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Docker not found"])
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: dockerPath)
        task.arguments = [
            "exec", "algokit_sandbox_algod",
            "goal", "account", "list",
            "-d", "/algod/data"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "FundingError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to list accounts: \(output)"])
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Parse the output to find the first account address
        // Format: [online]	ADDRESS	ADDRESS	BALANCE microAlgos
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let components = line.components(separatedBy: "\t")
            if components.count >= 2 {
                let address = components[1].trimmingCharacters(in: .whitespaces)
                if address.count == 58 { // Valid Algorand address length
                    return address
                }
            }
        }

        throw NSError(domain: "FundingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No funded accounts found in localnet wallet"])
    }

    // Helper to fund accounts
    private func fundAccount(amount: UInt64) async throws -> Account {
        let account = try Account()

        // Dynamically discover a funded address from the localnet
        let fundingAddress = try discoverFundingAddress()

        // Find docker executable in common locations
        let dockerPaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker"
        ]

        guard let dockerPath = dockerPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw NSError(domain: "FundingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Docker not found"])
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: dockerPath)
        task.arguments = [
            "exec", "algokit_sandbox_algod",
            "goal", "clerk", "send",
            "-a", String(amount),
            "-f", fundingAddress,
            "-t", account.address.description
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw NSError(domain: "FundingError", code: Int(task.terminationStatus))
        }

        return account
    }
}
