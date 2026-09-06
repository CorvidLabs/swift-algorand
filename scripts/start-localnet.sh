#!/bin/bash
set -euo pipefail

# Starts the Algorand LocalNet defined in docker-compose.yml and reports what came up.

ALGOD_URL="http://localhost:4001"
INDEXER_URL="http://localhost:8980"

# Prefer the Compose v2 subcommand, fall back to the standalone binary.
if docker compose version > /dev/null 2>&1; then
    COMPOSE=(docker compose)
elif command -v docker-compose > /dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    echo "Neither 'docker compose' nor 'docker-compose' is available. Install Docker Compose and try again."
    exit 1
fi

echo "Starting Algorand LocalNet..."
echo ""

if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

# Port 4001 in use usually means another LocalNet (for example AlgoKit's) is already up.
if curl -s -m 3 "${ALGOD_URL}/v2/status" > /dev/null 2>&1; then
    echo "Something is already answering on ${ALGOD_URL}."
    echo "If that is another LocalNet, use it as-is or stop it before starting this stack."
    echo ""
fi

"${COMPOSE[@]}" up -d

echo "Waiting for the network to initialize (30 seconds)..."
sleep 30

if curl -s -m 5 "${ALGOD_URL}/v2/status" > /dev/null; then
    echo "Algod is answering on ${ALGOD_URL}"
else
    echo "Algod is not answering yet. Give it a few more seconds, then: curl ${ALGOD_URL}/v2/status"
fi

if curl -s -m 5 "${INDEXER_URL}/health" > /dev/null; then
    echo "Indexer is answering on ${INDEXER_URL}"
else
    echo "Indexer is not answering yet. It takes longer than algod on first start."
fi

echo ""
echo "LocalNet is up."
echo ""
echo "Next steps:"
echo "   1. Run the full suite against it (CI must be unset):"
echo "        ALGORAND_NETWORK=localnet swift test"
echo ""
echo "   2. Run only the integration suite:"
echo "        ALGORAND_NETWORK=localnet swift test --filter 'AlgorandTests.IntegrationTests'"
echo ""
echo "   3. Run only the tests that need no network at all:"
echo "        swift test --skip IntegrationTest --skip ProofOfWorkTest"
echo ""
echo "   4. Stop LocalNet when done:"
echo "        ${COMPOSE[*]} down"
echo ""
echo "Note: the read-only integration tests pass against this stack. The ones that submit"
echo "transactions fund accounts through a Docker container named 'algokit_sandbox_algod'"
echo "and need a default kmd wallet - see documentation/TESTING.md before relying on them."
