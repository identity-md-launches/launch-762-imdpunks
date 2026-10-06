# IMDPunks contract tests

Run offline using the dependencies already in `lib/`:

```sh
FOUNDRY_OUT=test/scratch/out FOUNDRY_CACHE_PATH=test/scratch/cache forge build
FOUNDRY_OUT=test/scratch/out FOUNDRY_CACHE_PATH=test/scratch/cache forge test
```

Build products and logs belong in `test/scratch/`; that directory is not part of the deliverable. No FFI, network, fork, or environment mutation from Solidity is required.

The existing unit tests check factory deployment and constructor events, all reserve transfers, permanent claim limits, receiver rejection and reentry, authorization failures, ETH rejection, and a complete 10,000-token sellout. Art tests enumerate every type and accessory selection and all 10,000 neck rasters. The Male base map is an independent literal from the brief.

`IMDPunksInvariant.t.sol` adds 128 random sequences of 64 actions over eight actors, including the reserve. Its independent ledger tracks ownership, balances, lifetime claims, token approvals and operator approvals. Actions include valid and invalid claims, approval changes, direct and safe transfers, wrong senders, zero recipients, and rejecting receivers. Every sequence step checks conservation and compares the contract with the ledger. Expected target reverts are checked explicitly; unexpected handler reverts fail the campaign. A deterministic handler test also exercises a reserve round trip, token and operator approvals, revocation, and an exhausted claimant who has transferred all five tokens away.

Metadata tests decode and parse JSON and SVG for 200 distinct specified samples, arbitrary fuzzed IDs, and enough additional IDs to cover every catalog accessory and counts zero through seven. They check exact attributes and reconstruct SVG runs against the raster. Lifecycle tests check images before minting and stable metadata across ownership, caller, timestamp and block-number changes.

The invariant actors form a closed accounting model; the exhaustive sellout test separately covers the global supply ceiling. Pixel and document checks establish the stated mechanical constraints, not a subjective aesthetic judgment or exhaustive coverage of every possible random sequence.
