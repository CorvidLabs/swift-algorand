---
hi: 1
families: [BUILD]
owner: leif
---

# Building and paying for transactions

## Intent

Building a transaction should feel like filling in a form that cannot be filled in wrong. The fee, the validity window and the genesis data should come from the network rather than from me copying numbers around, and the one thing that is easy to get subtly wrong, the exact bytes, should never be my problem. When the SDK has to say no, it should say so while I am building, not after the network has rejected what I signed.

## Criteria

- **BUILD-1**  I can build every transaction Algorand uses for payments, assets, applications and key registration without learning its wire format.
- **BUILD-2**  What I build is encoded exactly as the network re-encodes it, so a signature never fails because of how the bytes were laid out.
- **BUILD-3**  A builder missing something it needs refuses to build instead of handing me a transaction that only looks valid.
- **BUILD-4**  The fee is right by default, priced from the network's own parameters.
  - **BUILD-4.a**  I can pin an exact fee, including zero for a transaction someone else in the group pays for.
  - **BUILD-4.b**  Before signing, I can ask a group what it owes in total.
  - **BUILD-4.c**  A group that underpays is caught before I submit it, with both numbers in the error.
- **BUILD-5**  A group of up to sixteen transactions succeeds or fails together, in the order I gave.
- **BUILD-6**  Amount arithmetic tells me when it overflows or divides by zero instead of crashing my app.
- **BUILD-7**  The transaction ID I am given is the ID the chain will record.
- **BUILD-8**  When the SDK does not model a transaction type, I can bring my own encoding and still sign and submit it.
