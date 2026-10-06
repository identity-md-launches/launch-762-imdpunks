// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PunkSprites} from "./PunkSprites.sol";

/// @notice Immutable art renderer. All selection depends only on the portrait number.
contract IMDPunkArt {
    using Strings for uint256;
    PunkSprites public immutable sprites;

    constructor() {
        sprites = new PunkSprites();
    }

    function typeIndex(uint256 number) public pure returns (uint8) {
        require(number < 10_000, "number range");
        uint256 rank = (number * 7919 + 4321) % 10_000;
        if (rank < 9) return 0;
        if (rank < 33) return 1;
        if (rank < 121) return 2;
        if (rank < 3961) return 3;
        return 4;
    }

    function typeName(uint8 kind) public pure returns (string memory) {
        require(kind < 5, "type range");
        return ["Alien", "Ape", "Zombie", "Female", "Male"][kind];
    }

    /// @return ids One ID per slot: head, eyes, mouth, facial hair, ear, neck, face mark. Zero means empty.
    /// @return count Number of occupied slots. Female has no facial-hair slot and a maximum of six.
    function traitsOf(uint256 number) public pure returns (uint8[7] memory ids, uint8 count) {
        bool female = typeIndex(number) == 3;
        uint256 seed = uint256(keccak256(abi.encode(number)));
        uint256 roll = seed % 10_000;
        count = roll < 10
            ? 0
            : roll < 310
                ? 1
                : roll < 3910 ? 2 : roll < 8410 ? 3 : roll < 9810 ? 4 : roll < 9980 ? 5 : roll < 9990 ? 6 : 7;
        if (female && count == 7) count = 6;
        if (count == 0) return (ids, count);
        uint8 mask;
        uint8 selected;
        if ((seed >> 16) % 100 < 85 || count == (female ? 6 : 7)) {
            mask = 1;
            selected = 1;
        }
        // Shuffle the other slots without replacement. Rehashing is deterministic, not a randomness oracle.
        uint8[6] memory order = [uint8(1), 2, 3, 4, 5, 6];
        if (female) order[2] = 6;
        uint256 remaining = female ? 5 : 6;
        uint256 cursor = seed >> 32;
        while (selected < count) {
            uint256 pick = cursor % remaining;
            uint8 slot = order[pick];
            mask |= uint8(1 << slot);
            order[pick] = order[remaining - 1];
            --remaining;
            ++selected;
            cursor = uint256(keccak256(abi.encode(cursor)));
        }
        uint8[7] memory starts = female ? [uint8(51), 69, 76, 0, 82, 83, 85] : [uint8(1), 24, 31, 39, 45, 46, 48];
        uint8[7] memory sizes = female ? [uint8(18), 7, 6, 0, 1, 2, 3] : [uint8(23), 7, 8, 6, 1, 2, 3];
        for (uint256 slot; slot < 7; ++slot) {
            if ((mask & uint8(1 << slot)) != 0) {
                ids[slot] = starts[slot] + uint8((seed >> (48 + slot * 24)) % sizes[slot]);
            }
        }
    }

    /// @notice Palette-index raster for independent inspection, in row-major order.
    function basePixels(uint8 kind) public pure returns (bytes memory pixels) {
        require(kind < 5, "type range");
        pixels = new bytes(576);
        if (kind == 3) {
            _run(pixels, 7, 9, 5, 1);
            _run(pixels, 8, 8, 7, 1);
            _run(pixels, 8, 9, 5, 2);
            for (uint256 y = 9; y < 19; ++y) {
                _run(pixels, y, 7, 9, 1);
                _run(pixels, y, 8, 7, 2);
            }
            _run(pixels, 13, 6, 11, 1);
            _run(pixels, 13, 7, 9, 2);
            _run(pixels, 14, 6, 11, 1);
            _run(pixels, 14, 7, 9, 2);
            _run(pixels, 19, 7, 8, 1);
            _run(pixels, 19, 8, 6, 2);
            _run(pixels, 20, 7, 8, 1);
            _run(pixels, 20, 8, 2, 2);
            for (uint256 y = 21; y < 24; ++y) {
                _run(pixels, y, 7, 4, 1);
                _run(pixels, y, 8, 2, 2);
            }
            _run(pixels, 9, 9, 1, 3);
            _run(pixels, 12, 9, 1, 1);
            _run(pixels, 12, 13, 1, 1);
            _run(pixels, 13, 9, 1, 1);
            _run(pixels, 13, 10, 1, 4);
            _run(pixels, 13, 13, 1, 1);
            _run(pixels, 13, 14, 1, 4);
            _run(pixels, 16, 13, 2, 5);
            _run(pixels, 18, 12, 2, 6);
            return pixels;
        }
        bytes memory map = abi.encodePacked(
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
        );
        for (uint256 i; i < map.length; ++i) {
            bytes1 c = map[i];
            pixels[i + 120] = c == "."
                ? bytes1(0)
                : c == "s"
                    ? bytes1(uint8(2))
                    : c == "h"
                        ? bytes1(uint8(3))
                        : c == "k"
                            ? bytes1(uint8(4))
                            : c == "n" ? bytes1(uint8(5)) : c == "m" ? bytes1(uint8(6)) : bytes1(uint8(1));
        }
        if (kind == 0) {
            _run(pixels, 6, 8, 7, 5);
            _run(pixels, 12, 9, 2, 1);
            _run(pixels, 12, 14, 2, 1);
        } else if (kind == 1) {
            for (uint256 y = 15; y < 19; ++y) {
                _run(pixels, y, 10, 5, 7);
            }
            _run(pixels, 15, 13, 2, 5);
            _run(pixels, 17, 12, 3, 6);
        } else if (kind == 2) {
            _run(pixels, 12, 9, 2, 14);
            _run(pixels, 12, 14, 2, 14);
            _run(pixels, 18, 12, 3, 8);
        }
    }

    function pixelsOf(uint256 number) public view returns (bytes memory pixels) {
        pixels = basePixels(typeIndex(number));
        (uint8[7] memory ids,) = traitsOf(number);
        // Head first; face mark before glasses, facial hair before mouth items.
        uint8[7] memory order = [uint8(0), 6, 3, 1, 4, 5, 2];
        for (uint256 i; i < 7; ++i) {
            uint256 id = ids[order[i]];
            if (id == 0) continue;
            (,,, bytes memory runs) = sprites.accessory(id);
            for (uint256 j; j < runs.length; j += 4) {
                _run(pixels, uint8(runs[j]), uint8(runs[j + 1]), uint8(runs[j + 2]), uint8(runs[j + 3]));
            }
        }
    }

    function paletteOf(uint256 number) public pure returns (bytes memory) {
        uint8 kind = typeIndex(number);
        string memory skin;
        string memory highlight;
        string memory shade;
        string memory nose;
        string memory lips = "704339";
        if (kind == 0) {
            skin = "a6d9df";
            highlight = "dcf1ed";
            shade = "000000";
            nose = "5a95b3";
        } else if (kind == 1) {
            skin = "77533b";
            highlight = "ac8159";
            shade = "422e27";
            nose = "483629";
        } else if (kind == 2) {
            skin = "82977a";
            highlight = "bec9a1";
            shade = "b94c52";
            nose = "526b53";
        } else {
            uint256 tone = uint256(keccak256(abi.encode(number))) >> 248;
            skin = ["e6ba91", "c9956f", "a66d4d", "724b3b"][tone % 4];
            highlight = ["f7d7b5", "e6bc93", "c18e68", "a17858"][tone % 4];
            shade = ["927053", "80573f", "664632", "453126"][tone % 4];
            nose = shade;
            if (kind == 3) lips = "a74c5b";
        }
        // Six ASCII hex digits per index, matching the authored sprite palette.
        return abi.encodePacked(
            "718993",
            "000000",
            skin,
            highlight,
            shade,
            nose,
            lips,
            "b38a60",
            "455c46",
            "332b2b",
            "684433",
            "e6c36a",
            "c7c9c5",
            "eee8dd",
            "b94c52",
            "395f93",
            "4e805a",
            "795981",
            "d38099",
            "77cad2",
            "d7af4c",
            "26364a",
            "bc743f",
            "354e43",
            "822d45"
        );
    }

    function svgOf(uint256 number) external view returns (string memory) {
        bytes memory pixels = pixelsOf(number);
        bytes memory palette = paletteOf(number);
        // At most 576 runs of <70 bytes each plus the header. Capacity is not part of the returned string.
        bytes memory buffer = new bytes(42_000);
        uint256 end = _append(
            buffer,
            0,
            bytes(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" shape-rendering="crispEdges"><rect width="24" height="24" fill="#718993"/>'
            )
        );
        for (uint256 y; y < 24; ++y) {
            uint256 x;
            while (x < 24) {
                uint8 color = uint8(pixels[y * 24 + x]);
                uint256 right = x + 1;
                while (right < 24 && pixels[y * 24 + right] == bytes1(color)) ++right;
                if (color != 0) {
                    bytes memory hexColor = new bytes(6);
                    for (uint256 c; c < 6; ++c) {
                        hexColor[c] = palette[uint256(color) * 6 + c];
                    }
                    end = _append(
                        buffer,
                        end,
                        abi.encodePacked(
                            '<rect x="',
                            x.toString(),
                            '" y="',
                            y.toString(),
                            '" width="',
                            (right - x).toString(),
                            '" height="1" fill="#',
                            hexColor,
                            '"/>'
                        )
                    );
                }
                x = right;
            }
        }
        end = _append(buffer, end, bytes("</svg>"));
        assembly ("memory-safe") { mstore(buffer, end) }
        return string(buffer);
    }

    function attributesOf(uint256 number) external view returns (string memory) {
        (uint8[7] memory ids, uint8 count) = traitsOf(number);
        bytes memory attributes = abi.encodePacked('[{"trait_type":"Type","value":"', typeName(typeIndex(number)), '"}');
        string[7] memory slots = ["Head", "Eyes", "Mouth", "Facial hair", "Ear", "Neck", "Face mark"];
        for (uint256 slot; slot < 7; ++slot) {
            if (ids[slot] == 0) continue;
            (string memory label,,,) = sprites.accessory(ids[slot]);
            // All strings are fixed ASCII catalog data with no JSON control characters.
            attributes = abi.encodePacked(attributes, ',{"trait_type":"', slots[slot], '","value":"', label, '"}');
        }
        return string(
            abi.encodePacked(attributes, ',{"trait_type":"Accessory count","value":', uint256(count).toString(), "}]")
        );
    }

    function _run(bytes memory pixels, uint256 y, uint256 x, uint256 length, uint8 color) private pure {
        uint256 end = y * 24 + x + length;
        for (uint256 i = y * 24 + x; i < end; ++i) {
            pixels[i] = bytes1(color);
        }
    }

    function _append(bytes memory target, uint256 offset, bytes memory source) private pure returns (uint256) {
        // Caller guarantees capacity. The extra written bytes are inside target's allocated capacity.
        assembly ("memory-safe") {
            let dst := add(add(target, 32), offset)
            let src := add(source, 32)
            for { let i := 0 } lt(i, mload(source)) { i := add(i, 32) } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }
        return offset + source.length;
    }
}
