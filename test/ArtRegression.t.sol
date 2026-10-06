// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "../src/IMDPunks.sol";
import {IMDPunkArt} from "../src/IMDPunkArt.sol";

contract ArtRegressionTest is Test {
    IMDPunkArt internal art;

    function setUp() public {
        art = new IMDPunks(0x2E28b29560a6d4812E58680484c685D0352f8ff9).art();
    }

    function test_rareEyesUseExactlyTheMaleMapEyePairs() public view {
        for (uint8 kind; kind <= 2; kind += 2) {
            bytes memory pixels = art.basePixels(kind);
            uint8 color = kind == 0 ? 1 : 14;
            assertEq(uint8(pixels[12 * 24 + 8]), 2, "skin before left eye");
            assertEq(uint8(pixels[12 * 24 + 9]), color);
            assertEq(uint8(pixels[12 * 24 + 10]), color);
            assertEq(uint8(pixels[12 * 24 + 11]), 2, "skin after left eye");
            assertEq(uint8(pixels[12 * 24 + 14]), 2, "skin before right eye");
            assertEq(uint8(pixels[12 * 24 + 15]), color);
            assertEq(uint8(pixels[12 * 24 + 16]), color);
            assertEq(uint8(pixels[12 * 24 + 17]), 1, "right outline");
        }
    }

    function test_maleSetPatchCoversBothRightEyePixels() public view {
        for (uint8 kind; kind < 5; ++kind) {
            if (kind == 3) continue;
            bytes memory base = art.basePixels(kind);
            bytes memory pixels = _overlay(kind, 29);
            for (uint256 y = 12; y <= 14; ++y) {
                assertEq(uint8(pixels[y * 24 + 13]), uint8(base[y * 24 + 13]), "patch shifted too far left");
                for (uint256 x = 14; x <= 16; ++x) {
                    assertEq(uint8(pixels[y * 24 + x]), 1, "patch must cover whole right eye");
                }
            }
            assertEq(uint8(pixels[12 * 24 + 9]), uint8(base[12 * 24 + 9]));
            assertEq(uint8(pixels[12 * 24 + 10]), uint8(base[12 * 24 + 10]));
        }
    }

    function test_maleSetEyeShadowKeepsTwoPixelEyes() public view {
        for (uint8 kind; kind < 5; ++kind) {
            if (kind == 3) continue;
            bytes memory pixels = _overlay(kind, 30);
            assertEq(uint8(pixels[12 * 24 + 8]), 17, "left shadow");
            assertEq(uint8(pixels[12 * 24 + 9]), 1);
            assertEq(uint8(pixels[12 * 24 + 10]), 1);
            assertEq(uint8(pixels[12 * 24 + 11]), 2);
            assertEq(uint8(pixels[12 * 24 + 14]), 17, "right shadow, not a third eye pixel");
            assertEq(uint8(pixels[12 * 24 + 15]), 1);
            assertEq(uint8(pixels[12 * 24 + 16]), 1);
        }
    }

    function test_femaleFrownPreservesOutlineAndBackground() public view {
        bytes memory pixels = _overlay(3, 79);
        _assertFemaleSilhouette(pixels);
        assertEq(uint8(pixels[18 * 24 + 12]), 1);
        assertEq(uint8(pixels[18 * 24 + 13]), 1);
        assertEq(uint8(pixels[19 * 24 + 11]), 1);
        assertEq(uint8(pixels[19 * 24 + 12]), 2);
        assertEq(uint8(pixels[19 * 24 + 13]), 2);
    }

    function test_femaleLipstickPreservesOutlineAndBackground() public view {
        bytes memory pixels = _overlay(3, 80);
        _assertFemaleSilhouette(pixels);
        assertEq(uint8(pixels[18 * 24 + 12]), 24);
        assertEq(uint8(pixels[18 * 24 + 13]), 24);
        for (uint256 x = 11; x <= 13; ++x) {
            assertEq(uint8(pixels[19 * 24 + x]), 14);
        }
    }

    function test_reportedTokensRenderCorrectedEyesAndChin() public view {
        (uint8[7] memory ids,) = art.traitsOf(36);
        assertEq(ids[1], 29);
        assertEq(uint8(art.pixelsOf(36)[12 * 24 + 16]), 1);
        (ids,) = art.traitsOf(42);
        assertEq(ids[1], 30);
        assertEq(uint8(art.pixelsOf(42)[12 * 24 + 16]), 1);
        (ids,) = art.traitsOf(64);
        assertEq(ids[0], 0);
        assertEq(ids[2], 79);
        bytes memory female = art.pixelsOf(64);
        assertEq(uint8(female[18 * 24 + 15]), 1);
        assertEq(uint8(female[19 * 24 + 15]), 0);
        assertEq(uint8(art.pixelsOf(473)[12 * 24 + 14]), 2);
        assertEq(uint8(art.pixelsOf(127)[12 * 24 + 16]), 14);
    }

    function _assertFemaleSilhouette(bytes memory pixels) internal view {
        bytes memory base = art.basePixels(3);
        for (uint256 i; i < base.length; ++i) {
            if (base[i] == bytes1(0) || base[i] == bytes1(uint8(1))) {
                assertEq(uint8(pixels[i]), uint8(base[i]), "mouth changed outline or background");
            }
        }
    }

    function _overlay(uint8 kind, uint256 accessory) internal view returns (bytes memory pixels) {
        pixels = art.basePixels(kind);
        (,,, bytes memory runs) = art.sprites().accessory(accessory);
        for (uint256 i; i < runs.length; i += 4) {
            uint256 y = uint8(runs[i]);
            uint256 x = uint8(runs[i + 1]);
            uint256 width = uint8(runs[i + 2]);
            for (uint256 j; j < width; ++j) {
                pixels[y * 24 + x + j] = runs[i + 3];
            }
        }
    }
}
