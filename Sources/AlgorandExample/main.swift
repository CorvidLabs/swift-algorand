import Foundation
import Algorand

// MARK: - Setup Functions

func createAlgodClient(for network: String) throws -> AlgodClient {
    switch network {
    case "localnet":
        return try AlgodClient(
            baseURL: "http://localhost:4001",
            apiToken: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        )
    case "testnet":
        return try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")
    case "mainnet":
        return try AlgodClient(baseURL: "https://mainnet-api.algonode.cloud")
    default:
        print("⚠️  Unknown network, using localnet")
        return try AlgodClient(
            baseURL: "http://localhost:4001",
            apiToken: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        )
    }
}

func fundAccountOnLocalnet(_ account: Account) -> Bool {
    let fundingAddress = "KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM"
    let amount = 100_000_000 // 100 ALGO

    // Find docker executable in common locations
    let dockerPaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/usr/bin/docker"
    ]

    guard let dockerPath = dockerPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        print("   Could not find docker executable")
        return false
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

    do {
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    } catch {
        return false
    }
}

func ensureAccountIsFunded(_ account: Account, algod: AlgodClient, network: String) async throws -> Bool {
    if network == "localnet" {
        if fundAccountOnLocalnet(account) {
            print("   ✅ Funded with 100 ALGO")
            try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            return true
        } else {
            print("   ⚠️  Could not auto-fund. Please fund manually:")
            print("   docker exec algokit_sandbox_algod goal clerk send -a 100000000 -f KSKUUC4CXBCZNB2XWLZPSVPZQZXWHW7OKBSCO5IEKEJGQUAQOTWNG4KGUM -t \(account.address)")
            return false
        }
    } else {
        let accountInfo = try await algod.accountInformation(account.address)
        let balance = MicroAlgos(accountInfo.amount)
        print("   Balance: \(balance.algos) ALGO")
        
        if balance.value == 0 {
            print("\n   ⚠️  Account has no funds!")
            if network == "testnet" {
                print("   Fund it at: https://bank.testnet.algorand.network/")
            }
            print("   Address: \(account.address)")
            print("\n   Then run again with:")
            print("   ALGORAND_MNEMONIC=\"\(try account.mnemonic())\" swift run algorand-example")
            return false
        }
        return true
    }
}

// MARK: - Main Example

func runExample() async throws {
    print("=== Simple Algorand Example ===\n")
    
    let network = ProcessInfo.processInfo.environment["ALGORAND_NETWORK"] ?? "localnet"
    print("🌐 Network: \(network.uppercased())\n")
    
    let algod = try createAlgodClient(for: network)
    
    // Step 1: Create sender account
    print("1️⃣  Creating sender account...")
    let sender = try Account()
    print("   Address: \(sender.address)")
    print("   Mnemonic: \(try sender.mnemonic())\n")
    
    // Step 2: Fund the sender account
    print("2️⃣  Funding sender account...")
    guard try await ensureAccountIsFunded(sender, algod: algod, network: network) else {
        return
    }
    
    let senderInfo = try await algod.accountInformation(sender.address)
    let senderBalance = MicroAlgos(senderInfo.amount)
    print("   ✅ Sender balance: \(senderBalance.algos) ALGO\n")
    
    // Step 3: Create receiver account
    print("3️⃣  Creating receiver account...")
    let receiver = try Account()
    print("   Address: \(receiver.address)\n")
    
    // Step 4: Send transaction
    print("4️⃣  Sending transaction...")
    let params = try await algod.transactionParams()
    
    let transaction = try PaymentTransactionBuilder()
        .sender(sender.address)
        .receiver(receiver.address)
        .amount(MicroAlgos(algos: 1.0))
        .params(params)
        .note("Hello from Algorand Swift SDK!")
        .build()
    
    print("   From: \(sender.address)")
    print("   To: \(receiver.address)")
    print("   Amount: 1.0 ALGO")
    
    let signedTxn = try SignedTransaction.sign(transaction, with: sender)
    let txID = try await algod.sendTransaction(signedTxn)
    
    print("   ✅ Transaction submitted!")
    print("   Transaction ID: \(txID)\n")
    
    print("⏳ Waiting for confirmation...")
    let confirmedTxn = try await algod.waitForConfirmation(transactionID: txID)
    
    print("✅ Transaction confirmed in round \(confirmedTxn.confirmedRound!)\n")
    
    let finalSenderInfo = try await algod.accountInformation(sender.address)
    let finalReceiverInfo = try await algod.accountInformation(receiver.address)
    
    print("💰 Final balances:")
    print("   Sender: \(MicroAlgos(finalSenderInfo.amount).algos) ALGO")
    print("   Receiver: \(MicroAlgos(finalReceiverInfo.amount).algos) ALGO")
    
    print("\n=== Example Complete ===")
}

// Entry point
try await runExample()
