# swift-algorand

Swift developers building on Algorand should not have to drop into another language, or hand-roll MessagePack, to move value. swift-algorand should be the SDK a Swift app on an iPhone, a Mac or a Linux server reaches for: native async/await, types that make the dangerous thing hard to write, and bytes that match go-algorand exactly, so what you sign is what the network verifies.

It should stay small and honest: one library, almost no dependencies, no crash on bad input, no silent fallback, no key material it does not need, and a clear seam for keys that live somewhere safer than the process. When the network changes, as consensus v42 did with usage-based fees and post-quantum accounts, the SDK should follow it precisely rather than approximately.

## Features

<!-- hi:index -->
- [build](hi/build.md): BUILD (11 criteria)
- [node](hi/node.md): NODE (8 criteria)
- [sign](hi/sign.md): SIGN (8 criteria)
<!-- /hi:index -->
