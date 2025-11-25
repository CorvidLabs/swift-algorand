#!/bin/bash
set -e

echo "🌐 Testing on Algorand TestNet"
echo ""

if [ -z "$ALGORAND_MNEMONIC" ]; then
    echo "ℹ️  No ALGORAND_MNEMONIC set. Creating a new account..."
    echo ""

    ALGORAND_NETWORK=testnet swift run algorand-example

    echo ""
    echo "📝 To test transactions:"
    echo "   1. Fund your account at: https://bank.testnet.algorand.network/"
    echo "   2. Export your mnemonic (shown above):"
    echo "      export ALGORAND_MNEMONIC=\"your 25 word mnemonic\""
    echo "   3. Run this script again"
    echo ""
else
    echo "✅ Using account from ALGORAND_MNEMONIC"
    echo ""

    # First check balance
    echo "💰 Checking account balance..."
    ALGORAND_NETWORK=testnet swift run algorand-example

    echo ""
    read -p "📤 Send a test transaction? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Sending transaction..."
        ALGORAND_NETWORK=testnet SEND_TRANSACTION=1 swift run algorand-example
    else
        echo "Skipping transaction"
    fi
fi
