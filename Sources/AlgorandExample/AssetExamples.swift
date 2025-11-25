import Foundation
import Algorand

/// Comprehensive asset management examples based on algo-utils-examples patterns
enum AssetExamples {
    /// Example 1: Create a new fungible token
    static func createFungibleToken() async throws {
        print("📝 Example: Creating a Fungible Token")
        print(String(repeating: "=", count: 50))

        // Create manager account (controls the asset)
        let manager = try Account()
        print("🔐 Manager Account: \(manager.address)")

        // Get network parameters
        let algodClient = try AlgodClient(
            baseURL: ProcessInfo.processInfo.environment["ALGOD_URL"] ?? "http://localhost:4001",
            apiToken: ProcessInfo.processInfo.environment["ALGOD_TOKEN"]
        )

        let params = try await algodClient.transactionParams()

        // Create asset parameters for a token with 2 decimals (like USD)
        let assetParams = AssetParams(
            total: 1_000_000,        // 1 million base units = 10,000 tokens with 2 decimals
            decimals: 2,              // 2 decimal places
            defaultFrozen: false,
            unitName: "USDC",         // Token symbol
            assetName: "USD Coin",    // Full name
            url: "https://example.com",
            metadataHash: nil,
            manager: manager.address, // Manager can change config
            reserve: manager.address, // Where unminted tokens reside
            freeze: manager.address,  // Can freeze holdings
            clawback: manager.address // Can revoke holdings
        )

        print("💰 Token Details:")
        print("   Name: \(assetParams.assetName ?? "N/A")")
        print("   Symbol: \(assetParams.unitName ?? "N/A")")
        print("   Total Supply: \(assetParams.toDecimal(assetParams.total)) tokens")
        print("   Decimals: \(assetParams.decimals)")

        // Create the asset
        let createTxn = AssetCreateTransaction(
            sender: manager.address,
            assetParams: assetParams,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        let signedTxn = try SignedTransaction.sign(createTxn, with: manager)
        let txid = try await algodClient.sendTransaction(signedTxn)

        print("✅ Asset Creation Transaction: \(txid)")
        print("⏳ Waiting for confirmation...")

        let result = try await algodClient.waitForConfirmation(transactionID: txid)
        let assetID = result.assetIndex ?? 0

        print("🎉 Asset Created! ID: \(assetID)")
        print("")
    }

    /// Example 2: Opt-in to an asset
    static func optInToAsset(assetID: UInt64) async throws {
        print("📝 Example: Opting Into an Asset")
        print(String(repeating: "=", count: 50))

        // Create receiver account
        let receiver = try Account()
        print("🔐 Receiver Account: \(receiver.address)")

        let algodClient = try AlgodClient(
            baseURL: ProcessInfo.processInfo.environment["ALGOD_URL"] ?? "http://localhost:4001",
            apiToken: ProcessInfo.processInfo.environment["ALGOD_TOKEN"]
        )

        let params = try await algodClient.transactionParams()

        // Opt-in transaction (zero-amount transfer to self)
        let optInTxn = AssetOptInTransaction(
            sender: receiver.address,
            assetID: assetID,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        let signedTxn = try SignedTransaction.sign(optInTxn, with: receiver)
        let txid = try await algodClient.sendTransaction(signedTxn)

        print("✅ Opt-In Transaction: \(txid)")
        print("⏳ Waiting for confirmation...")

        _ = try await algodClient.waitForConfirmation(transactionID: txid)
        print("🎉 Successfully Opted In to Asset \(assetID)")
        print("")
    }

    /// Example 3: Transfer assets between accounts
    static func transferAsset(assetID: UInt64, amount: Double, decimals: UInt64) async throws {
        print("📝 Example: Transferring Assets")
        print(String(repeating: "=", count: 50))

        let sender = try Account()
        let receiver = try Account()

        print("🔐 Sender: \(sender.address)")
        print("🔐 Receiver: \(receiver.address)")

        let algodClient = try AlgodClient(
            baseURL: ProcessInfo.processInfo.environment["ALGOD_URL"] ?? "http://localhost:4001",
            apiToken: ProcessInfo.processInfo.environment["ALGOD_TOKEN"]
        )

        let params = try await algodClient.transactionParams()

        // Convert decimal amount to base units
        let assetParams = AssetParams(
            total: 0,
            decimals: decimals,
            defaultFrozen: false
        )
        let baseUnits = assetParams.toBaseUnits(amount)

        print("💸 Transferring \(amount) tokens (\(baseUnits) base units)")

        // Create transfer transaction
        let transferTxn = AssetTransferTransaction(
            sender: sender.address,
            receiver: receiver.address,
            assetID: assetID,
            amount: baseUnits,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        let signedTxn = try SignedTransaction.sign(transferTxn, with: sender)
        let txid = try await algodClient.sendTransaction(signedTxn)

        print("✅ Transfer Transaction: \(txid)")
        print("⏳ Waiting for confirmation...")

        _ = try await algodClient.waitForConfirmation(transactionID: txid)
        print("🎉 Successfully Transferred \(amount) tokens")
        print("")
    }

    /// Example 4: Atomic swap - Asset for ALGO
    static func atomicSwapAssetForAlgo(assetID: UInt64, assetAmount: UInt64, algoAmount: MicroAlgos) async throws {
        print("📝 Example: Atomic Swap - Asset for ALGO")
        print(String(repeating: "=", count: 50))

        let assetSeller = try Account()  // Has asset, wants ALGO
        let algoBuyer = try Account()     // Has ALGO, wants asset

        print("🔐 Asset Seller: \(assetSeller.address)")
        print("🔐 ALGO Buyer: \(algoBuyer.address)")

        let algodClient = try AlgodClient(
            baseURL: ProcessInfo.processInfo.environment["ALGOD_URL"] ?? "http://localhost:4001",
            apiToken: ProcessInfo.processInfo.environment["ALGOD_TOKEN"]
        )

        let params = try await algodClient.transactionParams()

        print("🔄 Swap Details:")
        print("   Asset Amount: \(assetAmount) units")
        print("   ALGO Amount: \(algoAmount.algos) ALGO")

        // Transaction 1: Asset transfer from seller to buyer
        let assetTxn = AssetTransferTransaction(
            sender: assetSeller.address,
            receiver: algoBuyer.address,
            assetID: assetID,
            amount: assetAmount,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        // Transaction 2: ALGO payment from buyer to seller
        let algoTxn = PaymentTransaction(
            sender: algoBuyer.address,
            receiver: assetSeller.address,
            amount: algoAmount,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        // Create atomic transaction group
        let group = try AtomicTransactionGroupBuilder()
            .add(assetTxn)
            .add(algoTxn)
            .build()

        print("🔗 Group ID: \(group.groupID.base64EncodedString())")

        // Sign transactions
        let signedGroup = try SignedAtomicTransactionGroup.sign(
            group,
            with: [
                0: assetSeller,  // Signs the asset transfer
                1: algoBuyer     // Signs the ALGO payment
            ]
        )

        // Submit group
        let txid = try await algodClient.sendTransactionGroup(signedGroup)

        print("✅ Atomic Swap Transaction: \(txid)")
        print("⏳ Waiting for confirmation...")

        _ = try await algodClient.waitForConfirmation(transactionID: txid)
        print("🎉 Atomic Swap Completed Successfully!")
        print("   Both transactions executed together ✅")
        print("")
    }

    /// Example 5: Create an NFT (non-fungible token)
    static func createNFT() async throws {
        print("📝 Example: Creating an NFT")
        print(String(repeating: "=", count: 50))

        let creator = try Account()
        print("🔐 Creator Account: \(creator.address)")

        let algodClient = try AlgodClient(
            baseURL: ProcessInfo.processInfo.environment["ALGOD_URL"] ?? "http://localhost:4001",
            apiToken: ProcessInfo.processInfo.environment["ALGOD_TOKEN"]
        )

        let params = try await algodClient.transactionParams()

        // NFT parameters: total = 1, decimals = 0
        let nftParams = AssetParams(
            total: 1,                 // Only 1 unit exists
            decimals: 0,              // No fractional ownership
            defaultFrozen: false,
            unitName: "NFT",
            assetName: "My Awesome NFT",
            url: "ipfs://QmExample...",  // IPFS URL to metadata
            metadataHash: nil,
            manager: creator.address,
            reserve: creator.address,
            freeze: creator.address,
            clawback: creator.address
        )

        print("🖼️  NFT Details:")
        print("   Name: \(nftParams.assetName ?? "N/A")")
        print("   Total Supply: \(nftParams.total) (unique)")
        print("   Metadata URL: \(nftParams.url ?? "N/A")")

        let createTxn = AssetCreateTransaction(
            sender: creator.address,
            assetParams: nftParams,
            firstValid: params.firstRound,
            lastValid: params.firstRound + 1000,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash
        )

        let signedTxn = try SignedTransaction.sign(createTxn, with: creator)
        let txid = try await algodClient.sendTransaction(signedTxn)

        print("✅ NFT Creation Transaction: \(txid)")
        print("⏳ Waiting for confirmation...")

        let result = try await algodClient.waitForConfirmation(transactionID: txid)
        let assetID = result.assetIndex ?? 0

        print("🎉 NFT Created! ID: \(assetID)")
        print("")
    }

    /// Example 6: Check asset balance
    static func checkAssetBalance(address: Address, assetID: UInt64) async throws {
        print("📝 Example: Checking Asset Balance")
        print(String(repeating: "=", count: 50))

        let algodClient = try AlgodClient(
            baseURL: ProcessInfo.processInfo.environment["ALGOD_URL"] ?? "http://localhost:4001",
            apiToken: ProcessInfo.processInfo.environment["ALGOD_TOKEN"]
        )

        let accountInfo = try await algodClient.accountInformation(address)

        print("🔐 Account: \(address)")
        print("💰 ALGO Balance: \(MicroAlgos(accountInfo.amount).algos) ALGO")
        print("")
        print("📊 Asset Holdings:")

        if let assets = accountInfo.assets {
            for asset in assets {
                if asset.assetID == assetID {
                    print("   Asset ID \(assetID): \(asset.amount) base units")

                    // Try to get asset details for decimal conversion
                    // (In production, you'd query asset info from indexer)
                    print("   (To see decimal value, query asset info for decimals)")
                }
            }
        } else {
            print("   No asset holdings found")
        }
        print("")
    }
}
