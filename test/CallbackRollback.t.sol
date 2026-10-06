// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "src/IMDPunks.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ForwardingClaimReceiver is IERC721Receiver {
    IMDPunks internal immutable punks;
    address internal immutable sink;
    uint8 public mode;
    uint256 public callbacks;

    error RejectedAfterForwarding();

    constructor(IMDPunks punks_, address sink_) {
        punks = punks_;
        sink = sink_;
    }

    function setMode(uint8 mode_) external {
        mode = mode_;
    }

    function claim(uint256 id) external {
        punks.claim(id);
    }

    function onERC721Received(address, address, uint256 id, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(punks), "unexpected NFT");
        require(punks.ownerOf(id) == address(this), "ownership not updated before callback");
        require(punks.getApproved(id) == address(0), "approval not cleared before callback");
        ++callbacks;
        punks.claim(604);
        punks.transferFrom(address(this), sink, 604);
        punks.transferFrom(address(this), sink, id);
        punks.setApprovalForAll(sink, true);
        if (mode == 0) revert RejectedAfterForwarding();
        if (mode == 1) return bytes4(0);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract CallbackRollbackTest is Test {
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;
    address constant OPERATOR = address(0xA11CE);
    address constant SINK = address(0xB0B);
    IMDPunks internal punks;
    ForwardingClaimReceiver internal receiver;

    function setUp() public {
        punks = new IMDPunks(RESERVE);
        receiver = new ForwardingClaimReceiver(punks, SINK);
    }

    function test_revertingCallbackRollsBackFirstReserveTransferAndFifthClaim() public {
        _checkRollbackAndRetry(777, 4, false);
    }

    function test_wrongSelectorRollsBackFirstReserveTransferAndFirstClaim() public {
        _checkRollbackAndRetry(888, 0, true);
    }

    /// forge-config: default.fuzz.runs = 64
    function testFuzz_callbackRollbackPreservesReserveAndLifetimeAllowance(
        uint256 reserveSeed,
        uint256 claimSeed,
        bool wrongSelector
    ) public {
        uint256 index = bound(reserveSeed, 0, 199);
        uint256 id = index < 198 ? index : index == 198 ? 777 : 888;
        _checkRollbackAndRetry(id, bound(claimSeed, 0, 4), wrongSelector);
    }

    function _checkRollbackAndRetry(uint256 id, uint256 priorClaims, bool wrongSelector) internal {
        for (uint256 i; i < priorClaims; ++i) {
            receiver.claim(600 + i);
        }
        receiver.setMode(wrongSelector ? 1 : 0);
        vm.prank(RESERVE);
        punks.approve(OPERATOR, id);

        // The receiver first mints and forwards two NFTs, then rejects the outer transfer.
        // Match the final rejection so an earlier unexpected failure cannot satisfy this test.
        bytes memory expected = wrongSelector
            ? abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(receiver))
            : abi.encodeWithSelector(ForwardingClaimReceiver.RejectedAfterForwarding.selector);
        vm.prank(OPERATOR);
        vm.expectRevert(expected);
        punks.safeTransferFrom(RESERVE, address(receiver), id);

        assertEq(receiver.callbacks(), 0, "receiver state escaped rollback");
        assertEq(punks.ownerOf(id), RESERVE, "implicit reserve owner lost");
        assertEq(punks.getApproved(id), OPERATOR, "original approval lost");
        assertEq(punks.balanceOf(RESERVE), 200);
        assertEq(punks.balanceOf(SINK), 0);
        assertEq(punks.balanceOf(address(receiver)), priorClaims);
        assertEq(punks.claimedBy(address(receiver)), priorClaims, "rejected callback consumed allowance");
        assertEq(punks.totalSupply(), 200 + priorClaims);
        assertFalse(punks.isMinted(604), "nested mint survived rejection");
        assertFalse(punks.isApprovedForAll(address(receiver), SINK));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 604));
        punks.ownerOf(604);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 604));
        punks.tokenURI(604);

        // Retry the identical transfer with a valid callback; the original approval is still usable.
        receiver.setMode(2);
        vm.prank(OPERATOR);
        punks.safeTransferFrom(RESERVE, address(receiver), id);
        assertEq(receiver.callbacks(), 1);
        assertEq(punks.ownerOf(id), SINK);
        assertEq(punks.ownerOf(604), SINK);
        assertEq(punks.getApproved(id), address(0));
        assertEq(punks.balanceOf(RESERVE), 199);
        assertEq(punks.balanceOf(SINK), 2);
        assertEq(punks.balanceOf(address(receiver)), priorClaims);
        assertEq(punks.claimedBy(address(receiver)), priorClaims + 1);
        assertEq(punks.claimedBy(RESERVE), 0);
        assertEq(punks.claimedBy(SINK), 0);
        assertEq(punks.totalSupply(), 201 + priorClaims);
        assertTrue(punks.isApprovedForAll(address(receiver), SINK));
        for (uint256 i; i < priorClaims; ++i) {
            assertEq(punks.ownerOf(600 + i), address(receiver));
        }

        // The forwarded nested claim still counts permanently toward the receiver's five.
        for (uint256 i = priorClaims + 1; i < 5; ++i) {
            receiver.claim(610 + i);
        }
        vm.expectRevert(IMDPunks.ClaimLimit.selector);
        receiver.claim(620);
        assertFalse(punks.isMinted(620));
        assertEq(punks.claimedBy(address(receiver)), 5);
        assertEq(punks.balanceOf(address(receiver)), 4);
        assertEq(punks.totalSupply(), 205);
    }
}
