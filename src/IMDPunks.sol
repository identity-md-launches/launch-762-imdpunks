// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IMDPunkArt} from "./IMDPunkArt.sol";

/// @notice Immutable, free-to-claim portraits. The constructor recipient has no administrative powers.
contract IMDPunks is ERC721 {
    using Strings for uint256;

    string public constant NAME = "IMDPunks";
    string public constant SYMBOL = "IMDPUNK";
    uint256 public constant MAX_SUPPLY = 10_000;
    address public immutable reserve;
    IMDPunkArt public immutable art;
    uint256 public totalSupply = 200;
    mapping(address => uint256) public claimedBy;

    error InvalidNumber();
    error AlreadyMinted();
    error ClaimLimit();
    error InvalidReserve();

    constructor(address reserve_) ERC721("", "") {
        if (reserve_ == address(0)) revert InvalidReserve();
        reserve = reserve_;
        art = new IMDPunkArt();
        // OZ's supported implicit-ownership extension: balances must match _ownerOf from block one.
        _increaseBalance(reserve_, 200);
        for (uint256 i; i < 198; ++i) {
            emit Transfer(address(0), reserve_, i);
        }
        emit Transfer(address(0), reserve_, 777);
        emit Transfer(address(0), reserve_, 888);
    }

    function name() public pure override returns (string memory) {
        return NAME;
    }

    function symbol() public pure override returns (string memory) {
        return SYMBOL;
    }

    function claim(uint256 number) external {
        if (number >= MAX_SUPPLY) revert InvalidNumber();
        if (isMinted(number)) revert AlreadyMinted();
        if (claimedBy[msg.sender] == 5) revert ClaimLimit();
        ++claimedBy[msg.sender];
        ++totalSupply;
        // Deliberately _mint, as specified: no receiver callback during a claim.
        _mint(msg.sender, number);
    }

    function isMinted(uint256 number) public view returns (bool) {
        return _ownerOf(number) != address(0);
    }

    function typeOf(uint256 number) public pure returns (string memory) {
        if (number >= MAX_SUPPLY) revert InvalidNumber();
        uint256 rank = (number * 7919 + 4321) % MAX_SUPPLY;
        if (rank < 9) return "Alien";
        if (rank < 33) return "Ape";
        if (rank < 121) return "Zombie";
        if (rank < 3961) return "Female";
        return "Male";
    }

    /// @notice A base64 SVG data URI, available before minting as well as afterwards.
    function imageOf(uint256 number) public view returns (string memory) {
        if (number >= MAX_SUPPLY) revert InvalidNumber();
        return string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(art.svgOf(number))));
    }

    function tokenURI(uint256 number) public view override returns (string memory) {
        _requireOwned(number);
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                abi.encodePacked(
                    '{"name":"IMDPunk #',
                    number.toString(),
                    '","description":"10,000 immutable pixel portraits. Every pixel and trait lives on chain.","image":"',
                    imageOf(number),
                    '","attributes":',
                    art.attributesOf(number),
                    "}"
                )
            )
        );
    }

    function _ownerOf(uint256 number) internal view override returns (address) {
        address explicitOwner = super._ownerOf(number);
        if (explicitOwner != address(0)) return explicitOwner;
        if (number < 198 || number == 777 || number == 888) return reserve;
        return address(0);
    }
}
