// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, Vm} from "forge-std/Test.sol";
import {IMDPunks} from "../src/IMDPunks.sol";
import {IMDPunkArt} from "../src/IMDPunkArt.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract PunkFactory {
    function deploy(address reserve) external returns (IMDPunks) {
        return new IMDPunks(reserve);
    }
}

contract ClaimingContract {
    function claim(IMDPunks punks, uint256 id) external {
        punks.claim(id);
    }
}

contract ReenteringReceiver is IERC721Receiver {
    IMDPunks immutable punks;
    uint256 public observedBalance;
    address public observedOwner;
    bool public sixthFailed;

    constructor(IMDPunks punks_) {
        punks = punks_;
    }

    function prime() external {
        for (uint256 i = 500; i < 505; ++i) {
            punks.claim(i);
        }
    }

    function onERC721Received(address, address, uint256 id, bytes calldata) external returns (bytes4) {
        observedOwner = punks.ownerOf(id);
        observedBalance = punks.balanceOf(address(this));
        try punks.claim(505) {}
        catch {
            sixthFailed = true;
        }
        punks.transferFrom(address(this), address(0xB0B), id);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract RejectingReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0;
    }
}

contract IMDPunksTest is Test {
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    IMDPunks internal punks;

    function setUp() public {
        punks = new IMDPunks(RESERVE);
    }

    function test_factoryDeploymentBudgetEventsAndReserve() public {
        PunkFactory factory = new PunkFactory();
        vm.recordLogs();
        uint256 before = gasleft();
        IMDPunks fresh = factory.deploy(RESERVE);
        uint256 used = before - gasleft();
        // Include a conservative allowance for intrinsic/calldata gas for the full initcode transaction.
        uint256 envelope = 53_000 + (type(IMDPunks).creationCode.length + 32) * 16;
        Vm.Log[] memory logs = vm.getRecordedLogs();
        emit log_named_uint("Factory deployment execution gas", used);
        emit log_named_uint("Deployment with full calldata allowance", used + envelope);
        assertLt(used + envelope, 10_000_000);
        assertEq(logs.length, 200);
        for (uint256 i; i < 200; ++i) {
            uint256 id = i < 198 ? i : i == 198 ? 777 : 888;
            assertEq(fresh.ownerOf(id), RESERVE);
            assertTrue(fresh.isMinted(id));
            assertEq(logs[i].emitter, address(fresh));
            assertEq(logs[i].topics.length, 4);
            assertEq(logs[i].topics[0], keccak256("Transfer(address,address,uint256)"));
            assertEq(logs[i].topics[1], bytes32(0));
            assertEq(logs[i].topics[2], bytes32(uint256(uint160(RESERVE))));
            assertEq(uint256(logs[i].topics[3]), id);
            assertEq(logs[i].data.length, 0);
        }
        assertEq(fresh.balanceOf(RESERVE), 200);
        assertEq(fresh.balanceOf(address(factory)), 0);
        assertEq(fresh.totalSupply(), 200);
        assertEq(fresh.claimedBy(RESERVE), 0);
        assertLe(type(IMDPunks).creationCode.length + 32, 49_152);
        _checkRuntime(address(fresh));
        _checkRuntime(address(fresh.art()));
        // Tables in the sprite contract are data, not executable opcodes.
        assertLe(address(fresh.art().sprites()).code.length, 24_576);
    }

    function _checkRuntime(address target) internal view {
        bytes memory code = target.code;
        assertGt(code.length, 0);
        assertLe(code.length, 24_576);
        for (uint256 i; i < code.length; ++i) {
            uint8 op = uint8(code[i]);
            if (op >= 0x60 && op <= 0x7f) {
                i += op - 0x5f;
                continue;
            }
            assertTrue(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden opcode");
        }
    }

    function test_identityAndInterfaces() public view {
        assertEq(punks.name(), "IMDPunks");
        assertEq(punks.symbol(), "IMDPUNK");
        assertEq(punks.NAME(), "IMDPunks");
        assertEq(punks.SYMBOL(), "IMDPUNK");
        assertEq(punks.MAX_SUPPLY(), 10_000);
        assertTrue(punks.supportsInterface(0x01ffc9a7));
        assertTrue(punks.supportsInterface(0x80ac58cd));
        assertTrue(punks.supportsInterface(0x5b5e139f));
        assertFalse(punks.supportsInterface(0xffffffff));
        assertFalse(punks.supportsInterface(0x2a55205a));
        assertFalse(punks.isMinted(198));
        assertFalse(punks.isMinted(type(uint256).max));
    }

    function test_zeroReserveRejectedAndNoETHEntry() public {
        vm.expectRevert(IMDPunks.InvalidReserve.selector);
        new IMDPunks(address(0));
        vm.deal(ALICE, 1 ether);
        vm.startPrank(ALICE);
        (bool ok,) = address(punks).call{value: 1}(abi.encodeCall(punks.claim, (200)));
        assertFalse(ok);
        (ok,) = address(punks).call{value: 1}("");
        assertFalse(ok);
        (ok,) = address(punks.art()).call{value: 1}("");
        assertFalse(ok);
        (ok,) = address(punks.art().sprites()).call{value: 1}("");
        assertFalse(ok);
        vm.stopPrank();
        assertEq(address(punks).balance, 0);
        assertEq(punks.totalSupply(), 200);
        assertFalse(punks.isMinted(200));
    }

    function test_claimExactNumberAndRevertPaths() public {
        vm.startPrank(ALICE);
        vm.expectRevert(IMDPunks.InvalidNumber.selector);
        punks.claim(10_000);
        vm.expectRevert(IMDPunks.InvalidNumber.selector);
        punks.claim(type(uint256).max);
        for (uint256 i; i < 200; ++i) {
            vm.expectRevert(IMDPunks.AlreadyMinted.selector);
            punks.claim(i < 198 ? i : i == 198 ? 777 : 888);
        }
        punks.claim(9999);
        assertEq(punks.ownerOf(9999), ALICE);
        assertEq(punks.balanceOf(ALICE), 1);
        assertEq(punks.claimedBy(ALICE), 1);
        assertEq(punks.totalSupply(), 201);
        vm.expectRevert(IMDPunks.AlreadyMinted.selector);
        punks.claim(9999);
        vm.stopPrank();
        vm.prank(BOB);
        vm.expectRevert(IMDPunks.AlreadyMinted.selector);
        punks.claim(9999);
        assertEq(punks.claimedBy(BOB), 0);
    }

    function test_fiveClaimsForLifeDespiteTransfersAndApprovals() public {
        for (uint256 i = 200; i < 205; ++i) {
            vm.prank(ALICE);
            punks.claim(i);
            vm.prank(ALICE);
            punks.transferFrom(ALICE, BOB, i);
        }
        assertEq(punks.balanceOf(ALICE), 0);
        assertEq(punks.claimedBy(ALICE), 5);
        assertEq(punks.claimedBy(BOB), 0);
        vm.prank(ALICE);
        vm.expectRevert(IMDPunks.ClaimLimit.selector);
        punks.claim(205);
        vm.prank(BOB);
        punks.transferFrom(BOB, ALICE, 200);
        vm.prank(ALICE);
        punks.setApprovalForAll(BOB, true);
        vm.prank(BOB);
        punks.transferFrom(ALICE, BOB, 200);
        vm.prank(ALICE);
        vm.expectRevert(IMDPunks.ClaimLimit.selector);
        punks.claim(205);
        vm.prank(BOB);
        punks.claim(205);
        assertEq(punks.ownerOf(205), BOB);
        assertEq(punks.totalSupply(), 206);
    }

    function test_allReservesTransferOutBackAndSelfWithoutBalanceDrift() public {
        for (uint256 i; i < 200; ++i) {
            uint256 id = i < 198 ? i : i == 198 ? 777 : 888;
            vm.prank(RESERVE);
            punks.transferFrom(RESERVE, RESERVE, id);
            assertEq(punks.balanceOf(RESERVE), 200 - i);
            vm.prank(RESERVE);
            punks.approve(ALICE, id);
            vm.prank(ALICE);
            punks.transferFrom(RESERVE, BOB, id);
            assertEq(punks.getApproved(id), address(0));
            assertEq(punks.ownerOf(id), BOB);
            assertEq(punks.balanceOf(RESERVE), 199 - i);
            assertEq(punks.balanceOf(BOB), i + 1);
            vm.prank(ALICE);
            vm.expectRevert(IMDPunks.AlreadyMinted.selector);
            punks.claim(id);
        }
        for (uint256 i; i < 200; ++i) {
            uint256 id = i < 198 ? i : i == 198 ? 777 : 888;
            vm.prank(BOB);
            punks.transferFrom(BOB, RESERVE, id);
            assertEq(punks.ownerOf(id), RESERVE);
        }
        assertEq(punks.balanceOf(RESERVE), 200);
        assertEq(punks.balanceOf(BOB), 0);
        assertEq(punks.totalSupply(), 200);
        assertEq(punks.claimedBy(RESERVE), 0);
    }

    function test_authorizationAndInvalidTransfers() public {
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, ALICE, 0));
        punks.transferFrom(RESERVE, ALICE, 0);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidApprover.selector, ALICE));
        punks.approve(ALICE, 0);
        vm.prank(RESERVE);
        punks.setApprovalForAll(ALICE, true);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721IncorrectOwner.selector, BOB, 0, RESERVE));
        punks.transferFrom(BOB, ALICE, 0);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0)));
        punks.transferFrom(RESERVE, address(0), 0);
        assertEq(punks.balanceOf(RESERVE), 200);
        vm.prank(ALICE);
        punks.transferFrom(RESERVE, ALICE, 0);
        vm.prank(RESERVE);
        punks.setApprovalForAll(ALICE, false);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, ALICE, 1));
        punks.transferFrom(RESERVE, ALICE, 1);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 200));
        punks.ownerOf(200);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 200));
        punks.getApproved(200);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, address(0)));
        punks.balanceOf(address(0));
    }

    function test_safeTransferRejectionRollsBackImplicitOwnershipAndApproval() public {
        RejectingReceiver rejector = new RejectingReceiver();
        vm.prank(RESERVE);
        punks.approve(ALICE, 777);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(rejector)));
        punks.safeTransferFrom(RESERVE, address(rejector), 777);
        assertEq(punks.ownerOf(777), RESERVE);
        assertEq(punks.balanceOf(RESERVE), 200);
        assertEq(punks.balanceOf(address(rejector)), 0);
        assertEq(punks.getApproved(777), ALICE);
    }

    function test_claimUsesMintWithoutCallbackAndSafeTransferReentrySeesUpdatedState() public {
        ClaimingContract wallet = new ClaimingContract();
        wallet.claim(punks, 300);
        assertEq(punks.ownerOf(300), address(wallet));
        ReenteringReceiver receiver = new ReenteringReceiver(punks);
        receiver.prime();
        vm.prank(RESERVE);
        punks.safeTransferFrom(RESERVE, address(receiver), 888, hex"1234");
        assertEq(receiver.observedOwner(), address(receiver));
        assertEq(receiver.observedBalance(), 6);
        assertTrue(receiver.sixthFailed());
        assertEq(punks.ownerOf(888), BOB);
        assertEq(punks.balanceOf(RESERVE), 199);
        assertEq(punks.balanceOf(address(receiver)), 5);
        assertEq(punks.claimedBy(address(receiver)), 5);
        assertFalse(punks.isMinted(505));
    }

    function test_selloutExactly10000AndNoFurtherMint() public {
        uint256 claimed;
        for (uint256 id; id < 10_000; ++id) {
            if (id < 198 || id == 777 || id == 888) continue;
            address claimer = address(uint160(0x100000 + claimed / 5));
            vm.prank(claimer);
            punks.claim(id);
            ++claimed;
        }
        assertEq(claimed, 9800);
        assertEq(punks.totalSupply(), 10_000);
        for (uint256 id; id < 10_000; ++id) {
            assertTrue(punks.isMinted(id));
        }
        vm.prank(ALICE);
        vm.expectRevert(IMDPunks.AlreadyMinted.selector);
        punks.claim(9999);
        vm.prank(ALICE);
        vm.expectRevert(IMDPunks.InvalidNumber.selector);
        punks.claim(10_000);
    }

    function testFuzz_claimAccounting(uint256 seed, address recipient) public {
        vm.assume(recipient != address(0) && recipient != ALICE && recipient != RESERVE);
        uint256 id = bound(seed, 198, 9999);
        vm.assume(id != 777 && id != 888);
        vm.prank(ALICE);
        punks.claim(id);
        vm.prank(ALICE);
        punks.transferFrom(ALICE, recipient, id);
        assertEq(punks.ownerOf(id), recipient);
        assertEq(punks.balanceOf(ALICE), 0);
        assertEq(punks.balanceOf(recipient), 1);
        assertEq(punks.claimedBy(ALICE), 1);
        assertEq(punks.claimedBy(recipient), 0);
        assertEq(punks.totalSupply(), 201);
    }
}
