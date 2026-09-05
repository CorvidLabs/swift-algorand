#!/bin/bash
set -euo pipefail

# Checks that the public Algorand TestNet endpoints this SDK documents are reachable, and
# optionally reports the balance of an address you pass in.
#
# This script does not build, sign, or submit anything. The test suite has no TestNet
# coverage - every integration test skips unless ALGORAND_NETWORK=localnet - so the
# supported way to exercise TestNet is the runnable program in documentation/QUICKSTART.md.
#
# Usage:
#   ./scripts/test-testnet.sh
#   ./scripts/test-testnet.sh <ALGORAND_ADDRESS>

ALGOD_URL="https://testnet-api.algonode.cloud"
INDEXER_URL="https://testnet-idx.algonode.cloud"
DISPENSER_URL="https://bank.testnet.algorand.network/"
EXPLORER_URL="https://lora.algokit.io/testnet"

echo "Checking Algorand TestNet endpoints"
echo ""

if ! command -v curl > /dev/null 2>&1; then
    echo "curl is required and was not found on PATH."
    exit 1
fi

algod_status=$(curl -s -m 15 "${ALGOD_URL}/v2/status" || true)
if [ -z "${algod_status}" ]; then
    echo "Algod at ${ALGOD_URL} did not respond."
    exit 1
fi
echo "Algod   ${ALGOD_URL}"
echo "        ${algod_status}" | head -c 200
echo ""

indexer_health=$(curl -s -m 15 "${INDEXER_URL}/health" || true)
if [ -z "${indexer_health}" ]; then
    echo "Indexer at ${INDEXER_URL} did not respond."
else
    echo "Indexer ${INDEXER_URL}"
    echo "        ${indexer_health}" | head -c 200
    echo ""
fi

echo ""

if [ "$#" -ge 1 ]; then
    address="$1"
    echo "Looking up ${address}"
    account_info=$(curl -s -m 15 "${ALGOD_URL}/v2/accounts/${address}" || true)
    if [ -z "${account_info}" ]; then
        echo "No response from algod for that address."
        exit 1
    fi
    echo "${account_info}" | head -c 400
    echo ""
    echo ""
    echo "If the balance is zero, fund it at ${DISPENSER_URL}"
else
    echo "No address given. To check one:"
    echo "    ./scripts/test-testnet.sh <ALGORAND_ADDRESS>"
fi

echo ""
echo "To create an account and send a TestNet payment, copy the complete program in"
echo "documentation/QUICKSTART.md into your own package. It creates an account, prints the"
echo "mnemonic and the dispenser link, and sends a self-payment once the account is funded."
echo ""
echo "Dispenser: ${DISPENSER_URL}"
echo "Explorer:  ${EXPLORER_URL}"
