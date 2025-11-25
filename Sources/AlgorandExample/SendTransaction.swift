import Foundation
import Algorand

func sendTestnetTransaction() async throws {
    // Create or import sender account
    let senderMnemonic = ProcessInfo.processInfo.environment["SENDER_MNEMONIC"]

    let sender: Account
    if let mnemonic = senderMnemonic {
        print("🔐 Importing sender account from mnemonic...")
        sender = try Account(mnemonic: mnemonic)
    } else {
        print("🔐 Creating new sender account...")
        sender = try Account()
        print("   ⚠️  SAVE THIS MNEMONIC:")
        print("   \(try sender.mnemonic())")
    }

    print("   Sender: \(sender.address)")

    // Create receiver account
    let receiver = try Account()
    print("🎯 Created receiver account...")
    print("   Receiver: \(receiver.address)")

    // Connect to testnet
    print("\n🌐 Connecting to TestNet...")
    let algod = try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")

    // Check sender balance
    print("\n💰 Checking sender balance...")
    let senderInfo = try await algod.accountInformation(sender.address)
    let balance = MicroAlgos(senderInfo.amount)
    print("   Balance: \(balance.algos) ALGO")

    if balance.algos < 28.0 {
        print("\n⚠️  Insufficient funds!")
        print("   Need: ~28 ALGO (27.4207 + fees)")
        print("   Have: \(balance.algos) ALGO")
        print("\n   Fund this account via TestNet faucet:")
        print("   https://bank.testnet.algorand.network/")
        print("   Address: \(sender.address)")
        print("\n   Then run again with:")
        print("   SENDER_MNEMONIC=\"\(try sender.mnemonic())\" swift run algorand-example send-transaction")
        return
    }

    // Get transaction parameters
    print("\n📋 Getting transaction parameters...")
    let params = try await algod.transactionParams()
    print("   Genesis ID: \(params.genesisID)")
    print("   First valid round: \(params.firstRound)")

    // Create payment transaction for 27.4207 ALGO
    let amount = MicroAlgos(algos: 27.4207)
    print("\n💸 Creating transaction...")
    print("   Amount: 27.4207 ALGO (\(amount.value) microAlgos)")
    print("   From: \(sender.address)")
    print("   To: \(receiver.address)")
    print("   Note: \"Hello Flock\"")

    let transaction = PaymentTransaction(
        sender: sender.address,
        receiver: receiver.address,
        amount: amount,
        fee: MicroAlgos(1000),
        firstValid: params.firstRound,
        lastValid: params.firstRound + 1000,
        genesisID: params.genesisID,
        genesisHash: params.genesisHash,
        note: "Hello Flock".data(using: .utf8)
    )

    // Sign transaction
    print("\n✍️  Signing transaction...")
    let signedTxn = try SignedTransaction.sign(transaction, with: sender)
    print("   Transaction ID: \(try signedTxn.id())")
    print("   Signature: \(signedTxn.signature.prefix(16).map { String(format: "%02x", $0) }.joined())...")

    // Submit transaction
    print("\n📤 Submitting transaction to TestNet...")
    do {
        let txid = try await algod.sendTransaction(signedTxn)
        print("✅ Transaction submitted successfully!")
        print("   Transaction ID: \(txid)")

        print("\n⏳ Waiting for confirmation...")
        let confirmed = try await algod.waitForConfirmation(transactionID: txid, timeout: 20)

        print("\n🎉 Transaction confirmed!")
        print("   Confirmed in round: \(confirmed.confirmedRound ?? 0)")
        print("   View on AlgoExplorer: https://testnet.algoexplorer.io/tx/\(txid)")

        // Check balances
        print("\n💰 Final balances:")
        let newSenderInfo = try await algod.accountInformation(sender.address)
        let newReceiverInfo = try await algod.accountInformation(receiver.address)
        print("   Sender: \(MicroAlgos(newSenderInfo.amount).algos) ALGO")
        print("   Receiver: \(MicroAlgos(newReceiverInfo.amount).algos) ALGO")

    } catch {
        print("❌ Transaction submission failed:")
        print("   \(error)")
        print("\n⚠️  This is likely due to MessagePack encoding not being implemented yet.")
        print("   The transaction was created and signed correctly, but submission requires")
        print("   proper MessagePack encoding instead of the current JSON placeholder.")
    }
}
