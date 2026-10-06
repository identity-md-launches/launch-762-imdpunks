// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "../src/IMDPunks.sol";
import {IMDPunkArt} from "../src/IMDPunkArt.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MetadataTest is Test {
    using Strings for uint256;
    IMDPunks internal punks;
    IMDPunkArt internal art;

    function setUp() public {
        punks = new IMDPunks(0x2E28b29560a6d4812E58680484c685D0352f8ff9);
        art = punks.art();
    }

    function test_metadataSamples000to049() public {
        _samples(0);
    }

    function test_metadataSamples050to099() public {
        _samples(50);
    }

    function test_metadataSamples100to149() public {
        _samples(100);
    }

    function test_metadataSamples150to199() public {
        _samples(150);
    }

    function _sampleID(uint256 i) internal pure returns (uint256) {
        if (i == 0) return 0;
        if (i == 1) return 777;
        if (i == 2) return 888;
        if (i == 3) return 9999;
        // 7679 is the inverse of 7919 modulo 10000; these cover all five types.
        if (i == 4) return ((10_000 - 4321) * 7679) % 10_000;
        if (i == 5) return ((10_009 - 4321) * 7679) % 10_000;
        if (i == 6) return ((10_033 - 4321) * 7679) % 10_000;
        if (i == 7) return ((10_121 - 4321) * 7679) % 10_000;
        if (i == 8) return ((13_961 - 4321) * 7679) % 10_000;
        return (i - 9) * 47 + 199;
    }

    function test_sampleSetIs200DistinctNumbersAndCoversEachType() public view {
        bool[5] memory seen;
        for (uint256 i; i < 200; ++i) {
            uint256 id = _sampleID(i);
            for (uint256 j; j < i; ++j) {
                assertTrue(id != _sampleID(j), "duplicate sample");
            }
            seen[art.typeIndex(id)] = true;
        }
        for (uint256 i; i < 5; ++i) {
            assertTrue(seen[i]);
        }
    }

    function _samples(uint256 start) internal {
        for (uint256 i = start; i < start + 50; ++i) {
            uint256 id = _sampleID(i);
            if (!punks.isMinted(id)) {
                vm.prank(address(uint160(0x20000 + i)));
                punks.claim(id);
            }
            // A fresh EVM frame for each parse prevents quadratic memory growth over large strings.
            this.checkSample(id);
        }
    }

    function checkSample(uint256 id) external view {
        string memory json = string(_decodeURI(punks.tokenURI(id), "data:application/json;base64,"));
        string[] memory keys = vm.parseJsonKeys(json, ".");
        assertEq(keys.length, 4);
        assertEq(vm.parseJsonString(json, ".name"), string.concat("IMDPunk #", id.toString()));
        assertGt(bytes(vm.parseJsonString(json, ".description")).length, 0);
        string memory image = vm.parseJsonString(json, ".image");
        assertEq(image, punks.imageOf(id));
        bytes memory svg = _decodeURI(image, "data:image/svg+xml;base64,");
        assertEq(string(svg), art.svgOf(id));
        _checkSVG(svg, art.pixelsOf(id), art.paletteOf(id));
        assertEq(vm.parseJsonString(json, ".attributes[0].trait_type"), "Type");
        assertEq(vm.parseJsonString(json, ".attributes[0].value"), punks.typeOf(id));
        (uint8[7] memory ids, uint8 count) = art.traitsOf(id);
        string[7] memory slots = ["Head", "Eyes", "Mouth", "Facial hair", "Ear", "Neck", "Face mark"];
        uint256 at = 1;
        for (uint256 slot; slot < 7; ++slot) {
            if (ids[slot] == 0) continue;
            string memory path = string.concat(".attributes[", at.toString(), "]");
            assertEq(vm.parseJsonString(json, string.concat(path, ".trait_type")), slots[slot]);
            (string memory label,,,) = art.sprites().accessory(ids[slot]);
            assertEq(vm.parseJsonString(json, string.concat(path, ".value")), label);
            ++at;
        }
        string memory last = string.concat(".attributes[", at.toString(), "]");
        assertEq(vm.parseJsonString(json, string.concat(last, ".trait_type")), "Accessory count");
        assertEq(vm.parseJsonUint(json, string.concat(last, ".value")), count);
        // Reject any hidden extra attributes after the count entry.
        assertEq(at, uint256(count) + 1);
        assertFalse(vm.keyExistsJson(json, string.concat(".attributes[", (at + 1).toString(), "]")));
    }

    function _decodeURI(string memory uri, string memory prefix) internal pure returns (bytes memory out) {
        bytes memory encoded = bytes(uri);
        uint256 start = _expect(encoded, 0, bytes(prefix));
        uint256 size = encoded.length - start;
        require(size > 0 && size % 4 == 0, "base64 size");
        bytes memory table = new bytes(256);
        bytes memory alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        for (uint256 i; i < 64; ++i) {
            table[uint8(alphabet[i])] = bytes1(uint8(i + 1));
        }
        uint256 pad = encoded[encoded.length - 1] == "=" ? 1 : 0;
        if (encoded[encoded.length - 2] == "=") ++pad;
        out = new bytes(size / 4 * 3 - pad);
        uint256 dst;
        for (uint256 i = start; i < encoded.length; i += 4) {
            uint256 word;
            for (uint256 j; j < 4; ++j) {
                uint256 v = uint8(table[uint8(encoded[i + j])]);
                if (v == 0) {
                    require(encoded[i + j] == "=" && i + j >= encoded.length - pad, "base64 alphabet");
                    v = 1;
                }
                word = (word << 6) | (v - 1);
            }
            if (dst < out.length) out[dst++] = bytes1(uint8(word >> 16));
            if (dst < out.length) out[dst++] = bytes1(uint8(word >> 8));
            if (dst < out.length) out[dst++] = bytes1(uint8(word));
        }
    }

    function _checkSVG(bytes memory svg, bytes memory pixels, bytes memory palette) internal pure {
        uint256 at = _expect(
            svg,
            0,
            bytes(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" shape-rendering="crispEdges"><rect width="24" height="24" fill="#718993"/>'
            )
        );
        bytes memory painted = new bytes(576);
        uint256 previousEnd;
        while (at < svg.length - 6) {
            at = _expect(svg, at, bytes('<rect x="'));
            uint256 x;
            (x, at) = _decimal(svg, at);
            at = _expect(svg, at, bytes('" y="'));
            uint256 y;
            (y, at) = _decimal(svg, at);
            at = _expect(svg, at, bytes('" width="'));
            uint256 width;
            (width, at) = _decimal(svg, at);
            at = _expect(svg, at, bytes('" height="1" fill="#'));
            require(x < 24 && y < 24 && width > 0 && x + width <= 24, "rect bounds");
            uint256 index = y * 24 + x;
            require(index >= previousEnd, "overlapping or unordered run");
            previousEnd = index + width;
            uint8 color = uint8(pixels[index]);
            require(color > 0 && color < 25, "background run");
            for (uint256 i; i < 6; ++i) {
                require(svg[at + i] == palette[uint256(color) * 6 + i], "SVG color");
            }
            at = _expect(svg, at + 6, bytes('"/>'));
            for (uint256 i; i < width; ++i) {
                require(pixels[index + i] == bytes1(color), "run crossed color");
                painted[index + i] = bytes1(color);
            }
            if (x + width < 24) require(pixels[index + width] != bytes1(color), "non-maximal run");
        }
        require(_expect(svg, at, bytes("</svg>")) == svg.length, "SVG trailing bytes");
        require(keccak256(painted) == keccak256(pixels), "SVG omitted pixels");
    }

    function _expect(bytes memory data, uint256 at, bytes memory literal) internal pure returns (uint256) {
        require(at + literal.length <= data.length, "truncated document");
        for (uint256 i; i < literal.length; ++i) {
            require(data[at + i] == literal[i], "document grammar");
        }
        return at + literal.length;
    }

    function _decimal(bytes memory data, uint256 at) internal pure returns (uint256 value, uint256 end) {
        end = at;
        while (end < data.length && data[end] >= "0" && data[end] <= "9") {
            value = value * 10 + uint8(data[end]) - 48;
            ++end;
        }
        require(end > at, "missing integer");
    }
}
