// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "src/IMDPunks.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract InvariantRejector is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        revert("receiver rejected");
    }
}

/// @notice An independent ledger: never learn expected ownership or claim eligibility from the NFT.
contract PunkLedgerHandler is Test {
    IMDPunks public immutable punks;
    InvariantRejector public immutable rejector;
    address[8] public actors;
    uint256[] public minted;
    mapping(uint256 => address) public owners;
    mapping(uint256 => address) public approvals;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public claims;
    mapping(address => mapping(address => bool)) public operators;
    uint256 public successfulClaims;
    uint256 public successfulTransfers;
    uint256 public rejectedCalls;

    constructor(IMDPunks target, address reserve) {
        punks = target;
        rejector = new InvariantRejector();
        actors[0] = reserve;
        for (uint256 i = 1; i < actors.length; ++i) {
            actors[i] = address(uint160(0xA000 + i));
        }
        for (uint256 i; i < 200; ++i) {
            uint256 id = i < 198 ? i : i == 198 ? 777 : 888;
            minted.push(id);
            owners[id] = reserve;
        }
        balances[reserve] = 200;
    }

    function mintedCount() external view returns (uint256) {
        return minted.length;
    }

    // Includes fresh IDs, repeated mints, all reserved IDs and integer-range extremes.
    function claim(uint256 actorSeed, uint256 idSeed, uint256 modeSeed) public {
        address caller = _actor(actorSeed);
        uint256 mode = bound(modeSeed, 0, 3);
        uint256 id;
        if (mode == 0) id = bound(idSeed, 198, 9999);
        else if (mode == 1) id = _token(idSeed);
        else if (mode == 2) id = bound(idSeed, 10_000, type(uint256).max);
        else id = minted[bound(idSeed, 0, 199)];
        bool expected = id < 10_000 && owners[id] == address(0) && claims[caller] < 5;
        vm.prank(caller);
        (bool ok,) = address(punks).call(abi.encodeCall(punks.claim, (id)));
        assertEq(ok, expected, "claim acceptance differs from independent ledger");
        if (ok) {
            owners[id] = caller;
            ++balances[caller];
            ++claims[caller];
            ++successfulClaims;
            minted.push(id);
        } else {
            ++rejectedCalls;
        }
        assertEq(punks.isMinted(id), owners[id] != address(0), "rejected claim changed mint status");
    }

    function approve(uint256 idSeed, uint256 callerSeed, uint256 recipientSeed, bool clear) public {
        uint256 id = _token(idSeed);
        address owner = owners[id];
        // Half the calls exercise the owner path; the rest exercise operators and outsiders.
        address caller = callerSeed % 2 == 0 ? owner : _actor(callerSeed);
        address recipient = clear ? address(0) : _actor(recipientSeed);
        bool expected = caller == owner || operators[owner][caller];
        vm.prank(caller);
        (bool ok,) = address(punks).call(abi.encodeCall(punks.approve, (recipient, id)));
        assertEq(ok, expected, "approval authorization");
        if (ok) approvals[id] = recipient;
        else ++rejectedCalls;
    }

    function setOperator(uint256 ownerSeed, uint256 operatorSeed, bool enabled) public {
        address owner = _actor(ownerSeed);
        address operator = _actor(operatorSeed);
        vm.prank(owner);
        punks.setApprovalForAll(operator, enabled);
        operators[owner][operator] = enabled;
    }

    function transfer(uint256 idSeed, uint256 toSeed, uint256 callerSeed, bool safe) public {
        uint256 id = _token(idSeed);
        address from = owners[id];
        address to = _actor(toSeed); // Includes transfers back to the reserve and self-transfers.
        uint256 role = callerSeed % 3;
        address caller =
            role == 0 ? from : role == 1 && approvals[id] != address(0) ? approvals[id] : _actor(callerSeed);
        bool expected = caller == from || caller == approvals[id] || operators[from][caller];
        bytes memory data = safe
            ? abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,bytes)", from, to, id, abi.encode(idSeed)
            )
            : abi.encodeCall(punks.transferFrom, (from, to, id));
        vm.prank(caller);
        (bool ok,) = address(punks).call(data);
        assertEq(ok, expected, "transfer authorization");
        if (ok) {
            --balances[from];
            ++balances[to];
            owners[id] = to;
            approvals[id] = address(0);
            ++successfulTransfers;
        } else {
            ++rejectedCalls;
        }
    }

    function invalidTransfer(uint256 idSeed, uint256 actorSeed, bool zeroRecipient) public {
        uint256 id = _token(idSeed);
        address owner = owners[id];
        address wrongFrom = _actor(actorSeed);
        if (wrongFrom == owner) wrongFrom = owner == actors[0] ? actors[1] : actors[0];
        vm.prank(owner);
        (bool ok,) = address(punks)
            .call(
                abi.encodeCall(
                    punks.transferFrom, (zeroRecipient ? owner : wrongFrom, zeroRecipient ? address(0) : owner, id)
                )
            );
        assertFalse(ok, "invalid transfer succeeded");
        ++rejectedCalls;
    }

    function rejectedSafeTransfer(uint256 idSeed) public {
        uint256 id = _token(idSeed);
        address owner = owners[id];
        vm.prank(owner);
        (bool ok,) = address(punks)
            .call(abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", owner, address(rejector), id));
        assertFalse(ok, "reverting receiver accepted");
        assertEq(punks.balanceOf(address(rejector)), 0, "receiver retained rejected token");
        ++rejectedCalls;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[bound(seed, 0, actors.length - 1)];
    }

    function _token(uint256 seed) internal view returns (uint256) {
        return minted[bound(seed, 0, minted.length - 1)];
    }
}

/// forge-config: default.invariant.runs = 128
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract IMDPunksInvariantTest is Test {
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;
    IMDPunks internal punks;
    PunkLedgerHandler internal handler;

    function setUp() public {
        punks = new IMDPunks(RESERVE);
        handler = new PunkLedgerHandler(punks, RESERVE);
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = handler.claim.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.setOperator.selector;
        selectors[3] = handler.transfer.selector;
        selectors[4] = handler.invalidTransfer.selector;
        selectors[5] = handler.rejectedSafeTransfer.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_ownershipBalancesApprovalsAndLifetimeClaimsMatchLedger() public view {
        uint256 balances;
        uint256 claims;
        for (uint256 i; i < 8; ++i) {
            address actor = handler.actors(i);
            uint256 balance = punks.balanceOf(actor);
            uint256 claimed = punks.claimedBy(actor);
            assertEq(balance, handler.balances(actor), "balance drift");
            assertEq(claimed, handler.claims(actor), "permanent claim count drift");
            assertLe(claimed, 5, "claim cap exceeded");
            balances += balance;
            claims += claimed;
            for (uint256 j; j < 8; ++j) {
                address operator = handler.actors(j);
                assertEq(punks.isApprovedForAll(actor, operator), handler.operators(actor, operator));
            }
        }
        uint256 count = handler.mintedCount();
        assertEq(punks.totalSupply(), 200 + claims);
        assertEq(punks.totalSupply(), count);
        assertEq(punks.totalSupply(), balances);
        assertEq(claims, handler.successfulClaims());
        assertLe(punks.totalSupply(), 10_000);
        for (uint256 i; i < count; ++i) {
            uint256 id = handler.minted(i);
            assertLt(id, 10_000);
            assertTrue(punks.isMinted(id));
            assertEq(punks.ownerOf(id), handler.owners(id), "ownership drift");
            assertEq(punks.getApproved(id), handler.approvals(id), "approval drift");
        }
    }

    // A deterministic witness makes sure every handler action reaches useful state transitions.
    function test_handlerExercisesReserveRoundTripRevocationAndExhaustedClaimant() public {
        handler.approve(198, 0, 1, false); // Token 777, still implicitly owned by reserve.
        handler.rejectedSafeTransfer(198);
        handler.transfer(198, 2, 1, true); // Token-approved spender.
        handler.transfer(198, 0, 0, false); // Back to reserve.
        handler.setOperator(0, 1, true);
        handler.transfer(199, 3, 5, false); // Independent outsider fails.
        handler.transfer(199, 3, 1, false); // Operator transfers token 888.
        handler.setOperator(0, 1, false);
        handler.transfer(0, 3, 1, false); // Revoked operator fails.
        handler.invalidTransfer(0, 2, false);
        handler.invalidTransfer(0, 2, true);
        for (uint256 i; i < 5; ++i) {
            handler.claim(1, 300 + i, 0);
            handler.transfer(200 + i, 2, 0, false);
        }
        handler.claim(1, 305, 0); // Transferring all five away cannot reset eligibility.
        handler.claim(2, 10_000, 2);
        handler.claim(2, 198, 1);
        handler.claim(2, 199, 3);
        assertEq(handler.successfulClaims(), 5);
        assertEq(handler.successfulTransfers(), 8);
        assertGe(handler.rejectedCalls(), 9);
        invariant_ownershipBalancesApprovalsAndLifetimeClaimsMatchLedger();
    }
}
