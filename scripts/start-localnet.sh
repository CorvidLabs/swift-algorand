#!/bin/bash
set -e

echo "🚀 Starting Algorand LocalNet..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

# Start containers
docker-compose up -d

echo "⏳ Waiting for network to initialize (30 seconds)..."
sleep 30

# Check if algod is responding
if curl -s http://localhost:4001/v2/status > /dev/null; then
    echo "✅ Algod is running on http://localhost:4001"
else
    echo "⚠️  Algod might not be ready yet, give it a few more seconds"
fi

# Check if indexer is responding
if curl -s http://localhost:8980/health > /dev/null; then
    echo "✅ Indexer is running on http://localhost:8980"
else
    echo "⚠️  Indexer might still be initializing"
fi

echo ""
echo "🎉 LocalNet is ready!"
echo ""
echo "📋 Next steps:"
echo "   1. Run integration tests:"
echo "      ALGORAND_NETWORK=localnet swift test"
echo ""
echo "   2. Run the interactive example:"
echo "      ALGORAND_NETWORK=localnet swift run algorand-example"
echo ""
echo "   3. Stop localnet when done:"
echo "      docker-compose down"
echo ""
