# IMDPunks

10,000 immutable, fully on-chain pixel portraits. ERC-721 name `IMDPunks`, symbol `IMDPUNK`. No sale proceeds, launch token, pool, fees, royalties, administrator, pause, upgrade, burn, or withdrawal function.

## Build and check

```sh
forge build
forge test
forge fmt --check
```

The compiler is pinned to Solidity **0.8.26**, with optimization, IR compilation, Paris EVM instructions and `bytecode_hash = "none"`. Dependencies are ordinary vendored source files: OpenZeppelin Contracts **5.0.2** (the ERC-721 and Base64 dependency closure) and forge-std **1.9.7**. Their licenses are included in `lib/`. No package download, FFI, environment variables or filesystem permissions are needed by the tests. The verifier supplies the pinned compiler.

The large test gas allowance permits exhaustive collection loops in a single test transaction; deployment has its own 10,000,000 gas assertion. Dynamic test linking and test-call isolation are explicitly disabled so factory tests execute real creation bytecode and include nested deployment gas.

## Deployment

Deploy **`IMDPunks(address reserve_)`**, passing exactly:

```text
0x2E28b29560a6d4812E58680484c685D0352f8ff9
```

Send **zero ETH**. `launch.json` specifies this deployment. The constructor rejects the zero address, accepts an explicit recipient, and never assigns rights to `msg.sender`. The address is a recipient, not an administrator. The deployment operator is responsible for using the specified address and compiler/settings and for recording the deployed addresses. No transaction has been broadcast to a live network by this project.

The constructor creates `IMDPunkArt`, which creates `PunkSprites`. These child addresses are immutable and available through `art()` and `art().sprites()`. All art, palettes, accessory names and metadata logic are in those deployed contracts. There are no external services, setters or initialization transactions. Each runtime is below the EIP-170 limit, and the entire application creation code is below the EIP-3860 limit. See `docs/review.md` for measured gas and verification results.

## Ownership and claims

At deployment the reserve owns **200** tokens: **0–197, 777, 888**. The constructor emits an individual `Transfer(0, reserve, id)` for each token and credits its balance with 200. Initial ownership is derived from the fixed reserved-number predicate. After a first transfer, ordinary OpenZeppelin ownership storage takes precedence. OpenZeppelin's `_ownerOf` extension and `_increaseBalance` are used together; no transfer can burn or erase that explicit ownership.

Anyone may call nonpayable `claim(number)` for an unminted number in **0–9999**. The exact requested number is minted with `_mint`. Each caller gets **five public claims for life**. Receiving or transferring tokens does not consume or restore claim allowance. Reserve allocation consumes no public claims. Claims by contracts are supported without a receiver callback; such contracts are responsible for being able to transfer their tokens. Safe transfers use the standard receiver callback.

`totalSupply()` is the number already minted: **200 initially**, increasing to **10,000**. The fixed collection cap is `MAX_SUPPLY() == 10000`. There is no other mint route and no burn route. `claimedBy(address)` records successful public claims. `isMinted(number)` returns false for out-of-range numbers. `ownerOf`, `getApproved`, and `tokenURI` revert for nonexistent tokens.

The limit is per **address**, not per person; creating other addresses is possible. Token IDs and accessories are public and deterministic, and a competing transaction may claim the requested number first. There is no hidden randomness or fairness oracle.

Every application entry point and constructor is nonpayable, with no payable fallback or receive function. Ordinary ETH transfers fail. As with all EVM contracts, protocol-level forced ETH credits cannot be prevented; there is deliberately no withdrawal mechanism.

## Art and metadata

`typeOf(number)` returns `Alien`, `Ape`, `Zombie`, `Female`, or `Male`. It uses `(number * 7919 + 4321) % 10000`, with the specified boundaries. The type totals are **9 / 24 / 88 / 3,840 / 6,039** and do not depend on hashes.

`imageOf(number)` returns a **`data:image/svg+xml;base64,` URI**, including for unminted numbers. `tokenURI(number)` returns **`data:application/json;base64,`** containing the name, description, image URI, Type, one attribute per occupied accessory slot, and a numeric Accessory count. Both reject numbers outside the collection; tokenURI additionally requires ownership to exist.

The SVG has `viewBox="0 0 24 24"`, `shape-rendering="crispEdges"`, a single flat muted blue-grey background, and one rectangle per maximal horizontal foreground run. Its raster is a bare head and neck: the male base is the exact supplied map; the female base is narrower and two rows lower, with lashes and a two-pixel lip-colour mouth. Male and rare-type neck outlines occupy columns **6–10**; female neck outlines occupy **7–10**. Rows **21–23** contain only those neck columns. No accessory paints below row 20.

Four flat human skin tones and separate Alien, Ape and Zombie palettes accompany the original authored accessory layers. Alien eyes and head line, Ape muzzle, and Zombie red eyes and mouth stain are applied to the male map. Accessories can cover base features. Hoods frame only the head; they have no shoulders or clothing below it.

There are **87 accessories**: 50 in the Male/Alien/Ape/Zombie set and 37 in the Female set. Female has no facial-hair slot and may have at most six accessories. Male-set types can have seven. Hash-derived slot selection samples without replacement. `art().traitsOf(number)` exposes seven ordered IDs (zero means empty): Head, Eyes, Mouth, Facial hair, Ear, Neck, Face mark. `art().sprites().accessory(id)` exposes each ID's name, slot, set and horizontal runs. The [catalog](docs/accessories.md) lists every accessory.

Observed distribution over all 10,000 IDs:

| Accessories | Punks |
|---|---:|
| 0 | 8 |
| 1 | 289 |
| 2 | 3,610 |
| 3 | 4,505 |
| 4 | 1,408 |
| 5 | 161 |
| 6 | 13 |
| 7 | 6 |

The head slot is filled on **8,507 (85.07%)** of portraits. All 87 accessory IDs occur. Selection and skin tone use `keccak256(abi.encode(number))`; types use only the arithmetic permutation.

`art().pixelsOf(number)`, `basePixels(typeIndex)`, and `paletteOf(number)` expose the row-major palette-index raster, base raster, and six-hex-digit-per-colour palette for inspection. Type indices are Alien 0, Ape 1, Zombie 2, Female 3, Male 4.

## Art authoring and independent checks

`tools/generate_sprites.py` is the original pixel authoring source. It uses only Python's standard library and regenerates `src/PunkSprites.sol` and `docs/accessories.md`. Run `forge fmt src/PunkSprites.sol` afterwards. The generated Solidity is already included; Python is not required to build or deploy.

For a second JSON/XML parser and a visual contact sheet, run a **local** Anvil:

```sh
anvil --port 18545
# In another terminal, after forge build:
python3 tools/check_art.py
```

This optional checker uses only Python's standard library, `cast`, compiled artifacts and Anvil's local unlocked/impersonated accounts. It measures a real factory transaction, parses 200 distinct metadata/SVG samples including the required IDs and all five types, and writes a nearest-neighbour contact sheet under `test/scratch/`. Nothing in that directory is needed for submission or deployment.

On-chain operation needs no maintenance account, scheduled calls, trusted data supplier or funding. The deployment operator should verify published source and constructor arguments, confirm reserve events/balances and obtain an independent contract/art review before release. This repository's tests and self-review do not constitute an independent audit.
