---
hi: 1
families: [NODE]
owner: leif
---

# Talking to nodes and indexers

## Intent

Talking to Algorand should feel like any other modern Swift networking: async/await, safe across tasks, and predictable when things go wrong. A slow node should cost me one failed request, not a hung app. The awkward parts of the real network, like a load balancer sending my poll to a node that has not seen my transaction yet, should be handled for me, and every failure should reach me as an error I can catch.

## Criteria

- **NODE-1**  Talking to a node or an indexer is plain async/await and safe to share across tasks.
- **NODE-2**  A slow or unreachable node fails its own request within a bounded time instead of hanging my app.
- **NODE-3**  After submitting, I can wait for confirmation without being misled by a node that has not seen my transaction yet.
- **NODE-4**  I can dry-run a signed group against a node before spending anything.
- **NODE-5**  I can page through an account's history on an indexer.
- **NODE-6**  Every failure reaches me as an error I can catch, never a crash.
- **NODE-7**  I can point it at MainNet, TestNet, a local network or my own node without editing the SDK.
- **NODE-8**  It behaves the same on Apple platforms and on Linux.
