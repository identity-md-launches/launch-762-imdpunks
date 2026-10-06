// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "../src/IMDPunks.sol";
import {IMDPunkArt} from "../src/IMDPunkArt.sol";
import {PunkSprites} from "../src/PunkSprites.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ArtTest is Test {
    using Strings for uint256;
    IMDPunks internal punks;
    IMDPunkArt internal art;
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;

    function setUp() public {
        punks = new IMDPunks(RESERVE);
        art = punks.art();
    }

    function test_all10000TypesExactFormulaAndTotals() public view {
        uint256[5] memory counts;
        string[5] memory labels = ["Alien", "Ape", "Zombie", "Female", "Male"];
        for (uint256 id; id < 10_000; ++id) {
            uint256 rank = (id * 7919 + 4321) % 10_000;
            uint8 expected = rank <= 8 ? 0 : rank <= 32 ? 1 : rank <= 120 ? 2 : rank <= 3960 ? 3 : 4;
            assertEq(art.typeIndex(id), expected);
            assertEq(punks.typeOf(id), labels[expected]);
            ++counts[expected];
        }
        assertEq(counts[0], 9);
        assertEq(counts[1], 24);
        assertEq(counts[2], 88);
        assertEq(counts[3], 3840);
        assertEq(counts[4], 6039);
    }

    function test_all10000AccessorySlotsEligibilityDistributionAndReachability() public {
        uint256[8] memory counts;
        bool[88] memory seen;
        uint256 heads;
        for (uint256 id; id < 10_000; ++id) {
            (uint8[7] memory ids, uint8 count) = art.traitsOf(id);
            bool female = art.typeIndex(id) == 3;
            uint8[7] memory starts = female ? [uint8(51), 69, 76, 0, 82, 83, 85] : [uint8(1), 24, 31, 39, 45, 46, 48];
            uint8[7] memory sizes = female ? [uint8(18), 7, 6, 0, 1, 2, 3] : [uint8(23), 7, 8, 6, 1, 2, 3];
            uint256 occupied;
            for (uint256 slot; slot < 7; ++slot) {
                if (ids[slot] == 0) continue;
                assertGe(ids[slot], starts[slot]);
                assertLt(ids[slot], starts[slot] + sizes[slot]);
                if (female) assertTrue(slot != 3);
                for (uint256 other; other < slot; ++other) {
                    assertTrue(ids[slot] != ids[other]);
                }
                seen[ids[slot]] = true;
                ++occupied;
            }
            assertEq(occupied, count);
            assertLe(count, female ? 6 : 7);
            ++counts[count];
            if (ids[0] != 0) ++heads;
        }
        for (uint256 id = 1; id <= 87; ++id) {
            assertTrue(seen[id], "unreachable accessory");
        }
        assertGe(counts[0], 3);
        assertLe(counts[0], 25);
        assertGe(counts[1], 230);
        assertLe(counts[1], 370);
        assertGe(counts[2], 3400);
        assertLe(counts[2], 3800);
        assertGe(counts[3], 4300);
        assertLe(counts[3], 4700);
        assertGe(counts[4], 1250);
        assertLe(counts[4], 1550);
        assertGe(counts[5], 100);
        assertLe(counts[5], 240);
        assertGe(counts[6] + counts[7], 8);
        assertLe(counts[6] + counts[7], 40);
        assertGe(heads, 8200);
        assertLe(heads, 8800);
        emit log_named_uint("Head slots", heads);
        for (uint256 i; i < 8; ++i) {
            emit log_named_uint(string.concat("Accessory count ", i.toString()), counts[i]);
        }
    }

    function test_catalogIsBoundedFlatAndMatchesSlots() public view {
        PunkSprites sprites = art.sprites();
        assertEq(sprites.ACCESSORY_COUNT(), 87);
        for (uint256 id = 1; id <= 87; ++id) {
            (string memory label, uint8 slot, bool female, bytes memory runs) = sprites.accessory(id);
            assertTrue(female == (id >= 51));
            uint256 expectedSlot = id <= 23
                ? 0
                : id <= 30
                    ? 1
                    : id <= 38
                        ? 2
                        : id <= 44
                            ? 3
                            : id == 45
                                ? 4
                                : id <= 47
                                    ? 5
                                    : id <= 50
                                        ? 6
                                        : id <= 68 ? 0 : id <= 75 ? 1 : id <= 81 ? 2 : id == 82 ? 4 : id <= 84 ? 5 : 6;
            assertEq(slot, expectedSlot);
            assertGt(bytes(label).length, 0);
            bytes memory labelBytes = bytes(label);
            for (uint256 j; j < labelBytes.length; ++j) {
                uint8 c = uint8(labelBytes[j]);
                assertTrue(c >= 32 && c < 127 && c != 34 && c != 92, "JSON unsafe label");
            }
            assertEq(runs.length % 4, 0);
            bool[25] memory colors;
            uint256 colorCount;
            uint256 painted;
            for (uint256 j; j < runs.length; j += 4) {
                uint256 y = uint8(runs[j]);
                uint256 x = uint8(runs[j + 1]);
                uint256 width = uint8(runs[j + 2]);
                uint256 color = uint8(runs[j + 3]);
                assertLt(y, 21);
                assertGt(width, 0);
                assertLe(x + width, 24);
                assertLt(color, 25);
                if (!colors[color]) {
                    colors[color] = true;
                    ++colorCount;
                }
                painted += width;
            }
            assertLe(colorCount, 3);
            assertGe(painted, id == 48 || id == 85 ? 1 : 3);
        }
    }

    function test_maleBaseMatchesSuppliedMapPixelForPixelAndUnadornedPunk() public view {
        bytes memory expected = _maleExpected();
        assertEq(expected.length, 576);
        assertEq(art.basePixels(4), expected);
        bool found;
        for (uint256 id; id < 10_000; ++id) {
            if (art.typeIndex(id) != 4) continue;
            (, uint8 count) = art.traitsOf(id);
            if (count == 0) {
                assertEq(art.pixelsOf(id), expected);
                found = true;
                break;
            }
        }
        assertTrue(found, "no bare male portrait");
    }

    function _maleExpected() internal pure returns (bytes memory result) {
        // Independent literal oracle, exactly the assignment's rows 5..23.
        string[19] memory rows = [
            "........#######.........",
            ".......#sssssss#........",
            "......#shsssssss#.......",
            "......#sssssssss#.......",
            "......#sssssssss#.......",
            "......#sssssssss#.......",
            "......#ssbbsssbb#.......",
            ".....#sssekssssek#......",
            ".....#sssssssssss#......",
            "......#sssssssss#.......",
            "......#ssssssnns#.......",
            "......#sssssssss#.......",
            "......#sssssmmms#.......",
            "......#sssssssss#.......",
            "......#ssssssss#........",
            "......#sss######........",
            "......#sss#.............",
            "......#sss#.............",
            "......#sss#............."
        ];
        result = new bytes(576);
        for (uint256 y; y < 19; ++y) {
            bytes memory row = bytes(rows[y]);
            require(row.length == 24);
            for (uint256 x; x < 24; ++x) {
                bytes1 c = row[x];
                uint8 value;
                if (c == "#" || c == "b" || c == "e") value = 1;
                else if (c == "s") value = 2;
                else if (c == "h") value = 3;
                else if (c == "k") value = 4;
                else if (c == "n") value = 5;
                else if (c == "m") value = 6;
                result[(y + 5) * 24 + x] = bytes1(value);
            }
        }
    }

    function test_femaleAndRareBaseFeatures() public view {
        bytes memory female = art.basePixels(3);
        for (uint256 i; i < 7 * 24; ++i) {
            assertEq(uint8(female[i]), 0);
        }
        assertEq(uint8(female[7 * 24 + 9]), 1);
        assertEq(uint8(female[9 * 24 + 9]), 3);
        assertEq(uint8(female[12 * 24 + 9]), 1);
        assertEq(uint8(female[12 * 24 + 13]), 1);
        assertEq(uint8(female[18 * 24 + 12]), 6);
        assertEq(uint8(female[18 * 24 + 13]), 6);
        assertEq(uint8(female[18 * 24 + 14]), 2);
        bytes memory alien = art.basePixels(0);
        for (uint256 x = 8; x < 15; ++x) {
            assertEq(uint8(alien[6 * 24 + x]), 5);
        }
        assertEq(uint8(alien[12 * 24 + 10]), 1);
        assertEq(uint8(alien[12 * 24 + 15]), 1);
        bytes memory ape = art.basePixels(1);
        assertEq(uint8(ape[16 * 24 + 11]), 7);
        bytes memory zombie = art.basePixels(2);
        assertEq(uint8(zombie[12 * 24 + 9]), 14);
        assertEq(uint8(zombie[18 * 24 + 13]), 8);
    }

    // Chunking bounds each transaction's memory and gas while checking every actual rendered raster.
    function test_neckOnly0000to0999() public view {
        _neckOnly(0);
    }

    function test_neckOnly1000to1999() public view {
        _neckOnly(1000);
    }

    function test_neckOnly2000to2999() public view {
        _neckOnly(2000);
    }

    function test_neckOnly3000to3999() public view {
        _neckOnly(3000);
    }

    function test_neckOnly4000to4999() public view {
        _neckOnly(4000);
    }

    function test_neckOnly5000to5999() public view {
        _neckOnly(5000);
    }

    function test_neckOnly6000to6999() public view {
        _neckOnly(6000);
    }

    function test_neckOnly7000to7999() public view {
        _neckOnly(7000);
    }

    function test_neckOnly8000to8999() public view {
        _neckOnly(8000);
    }

    function test_neckOnly9000to9999() public view {
        _neckOnly(9000);
    }

    function _neckOnly(uint256 start) internal view {
        for (uint256 id = start; id < start + 1000; ++id) {
            bytes memory pixels = art.pixelsOf(id);
            assertEq(pixels.length, 576);
            bool female = art.typeIndex(id) == 3;
            uint256 left = female ? 7 : 6;
            for (uint256 y = 21; y < 24; ++y) {
                for (uint256 x; x < 24; ++x) {
                    uint256 expected = x < left || x > 10 ? 0 : x == left || x == 10 ? 1 : 2;
                    assertEq(uint8(pixels[y * 24 + x]), expected, "body or clothing below head");
                }
            }
        }
    }

    function test_outOfRangeArtAndUnmintedMetadataRevert() public {
        vm.expectRevert();
        punks.tokenURI(198);
        vm.expectRevert();
        punks.tokenURI(10_000);
        vm.expectRevert();
        punks.tokenURI(type(uint256).max);
        vm.expectRevert();
        punks.imageOf(10_000);
        vm.expectRevert();
        punks.typeOf(type(uint256).max);
        vm.expectRevert();
        art.pixelsOf(10_000);
        vm.expectRevert();
        art.traitsOf(type(uint256).max);
        vm.expectRevert();
        art.paletteOf(10_000);
        vm.expectRevert();
        art.basePixels(5);
        PunkSprites sprites = art.sprites();
        vm.expectRevert();
        sprites.accessory(0);
        vm.expectRevert();
        sprites.accessory(88);
    }
}
