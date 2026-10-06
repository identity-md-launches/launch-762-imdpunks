# Implementation review and evidence

This is the implementing contributor's local review, not an independent security audit. No production transaction, wallet key, remote RPC endpoint or live deployment was used.

## Required adversarial attempts

| Attempt | Result and evidence |
|---|---|
| Mint a number twice or past 9999 | Reserved IDs, duplicate public claims, 10000 and uint256 maximum revert. A full sellout claims all 9,800 public IDs with distinct groups of five; every ID is minted and supply ends at exactly 10,000. Neither burning nor another mint entry point exists. |
| Restore the five-claim allowance | Five claims followed by transfers leave the caller's lifetime count at five. Incoming transfers, outgoing transfers and operator transfers do not change it. A receiver already at the cap also fails to make a sixth claim from its callback. |
| Claim a reserved number | All 200 reserved IDs fail public claims, including after transfer out of the reserve. |
| Break reserve accounting on first transfer | Every reserved ID is self-transferred, approved, transferred out, and transferred back. Balance totals, owner, cleared approvals and unchanged supply are asserted. A receiver rejecting the first safe transfer leaves the initial owner, balance and approval intact. |
| Produce broken tokenURI JSON | Unminted, out-of-range and maximum uint256 requests revert. Two independent parsers validate 200 distinct successful samples including 0, 777, 888, 9999 and every type. Metadata values are bounded decimal integers or fixed ASCII strings with no JSON control characters. |

## Security reasoning

- Public claims validate number, uniqueness and lifetime count before recording the claim and supply. `_mint` is the sole public-claim mint path and performs no external receiver callback. The fixed finite ID domain and uniqueness check impose the supply cap independently of the supply counter.
- OpenZeppelin 5.0.2 provides the ERC-721 transfer, approval and receiver behavior. Initial reserve ownership is derived only when explicit ownership storage is zero. The constructor credits exactly 200 matching balances using the documented `_ownerOf` / `_increaseBalance` extension mechanism. Transfers cannot target zero, and no public burn method exists, so transferred reserves cannot fall back to a stale initial owner.
- Safe transfer callbacks occur after owner, balances and approvals are updated. The malicious receiver test observes that completed state, attempts a sixth claim, and transfers the received token onward without corrupting reserve accounting.
- The deployer has no privilege. Reserve recipients have ordinary token-holder rights only. No administrative selector, proxy, external initializer, delegatecall, callcode, selfdestruct, arbitrary call target, ERC-20 interaction, fee, payable entry point or withdrawal exists in application source.
- The renderer and sprite store have no mutable configuration. Metadata calls target immutable constructor-created contracts; their view methods cannot mutate token state. Raster and string loops are bounded. Assembly is limited to copying constant-data slices and appending into a preallocated buffer; SVG output is checked against the independently parsed run geometry and palette.
- Number validation precedes type arithmetic and hashing. Accessory names are immutable printable ASCII without quotes or backslashes. JSON and SVG are embedded data URIs and need no server or IPFS content.
- Deterministic selection allows users to target desirable IDs, and a pending claim can be front-run by an earlier claim for the same number. The five-claim rule is per address and offers no protection against multiple addresses, including fresh claimer contracts deployed in one transaction. These are intended properties of public exact-number claims, not secure-randomness claims. Launch communications should disclose both properties.

## Revision evidence

The supplied Alien/Zombie proof was copied unchanged into `test/scratch/` and all three tests failed on the starting implementation. The six permanent tests in `test/ArtRegression.t.sol` also failed before production edits, reproducing the rare-eye shift, narrow eye-overlay shift, Female chin damage, and affected rendered tokens.

- Alien and Zombie right-eye recolours now cover the Male map's x15–16 pair on row 12, preserving skin at x14.
- Only the Male-set eye patch and eye shadow move their right-eye anchor to x15. All other eye accessories retain their geometry.
- Only the Female frown and lipstick get narrower footprints, preserving the chin outline and surrounding background.
- Regenerating the sprite tables and catalog changes exactly IDs **29, 30, 79 and 80**. A decoded-table comparison confirmed identical names, slots, sets and the other 83 accessory layers.
- After the fixes, all three supplied proof tests and all six permanent regressions pass. The proof includes every Alien/Zombie token without an eye accessory; the accessory regressions cover all four Male-set types, both Female mouth layers, and real tokens 36, 42, 64, 473 and 127.
- A scratch reproduction deployed ten claimers in one transaction and collected 50 tokens at one sink. Each claimer recorded five claims and rejected a sixth; the sink recorded zero claims and supply reached 250. A separate transaction-ordering test confirmed that the first claim of number 473 succeeds and the later claim reverts without consuming allowance. Both tests pass; the specified mint behavior is unchanged.

`.imd-responses.json` records a verdict and reproduction details for each reviewer finding. The three artwork findings are fixed. The informational claim-limit report is disputed only as a defect: its behavior is confirmed and already matches the task's per-address rule.

## Local verification

Solidity **0.8.26**, optimizer 200 runs, IR enabled, Paris EVM, metadata bytecode hash disabled. Vendored OpenZeppelin Contracts **5.0.2** and forge-std **1.9.7**. Foundry **1.8.3** was used locally.

- `forge build`: passed.
- `forge test`: **38 permanent tests passed**, including 256 fuzz cases, plus the three supplied proof tests and two claim-design reproductions in scratch.
- All 10,000 arithmetic types checked against the required totals.
- All 10,000 accessory selections checked for slot uniqueness, type eligibility, count, distribution and reachability of all 87 IDs.
- All 10,000 final rasters checked for plain neck columns and background everywhere else in rows 21–23.
- Exact male base-map comparison, including a real zero-accessory male token; female and rare-type base features also checked.
- 200 metadata samples decoded and parsed in Foundry. Their SVG rectangles are checked for bounds, colour, non-overlap, maximal horizontal runs and complete agreement with the rendered pixels.
- `python3 tools/check_art.py`: 200 independent Python JSON and XML parses passed against real local Anvil deployments. A nearest-neighbour contact sheet was visually inspected for flat pixels, head/neck silhouette and accessory readability.
- `forge fmt --check`: passed.

Deployment through the test factory consumed **4,998,578 execution gas**; adding a conservative full-initcode calldata/intrinsic allowance gives **5,427,994 gas**. A separate real local Anvil factory transaction used **5,022,519 gas** including transaction overhead. The 10,000,000 gas test is enforced independently of the larger exhaustive-test gas allowance. The factory test checks all 200 constructor events and correct initial owner/balance/supply.

| Contract | Runtime bytes |
|---|---:|
| IMDPunks | 5,280 |
| IMDPunkArt | 9,495 |
| PunkSprites | 7,443 |

IMDPunks creation code is **23,494 bytes**, plus 32 bytes of constructor arguments. Runtime-size and forbidden-escape-opcode checks pass for the application and renderer. Sprite byte arrays are data, and their source contains no executable escape operation.

The compiler's advisory lints flag expected patterns: the explicitly required `_mint`, immutable view calls in bounded rendering loops, concatenation for output strings (not hashing or authentication), and constructor events after creating immutable child contracts. These were reviewed in their actual contexts. No Slither or Mythril was run locally. Release responsibilities remain source verification, review of the reserve constructor argument, and independent contract/art review.
