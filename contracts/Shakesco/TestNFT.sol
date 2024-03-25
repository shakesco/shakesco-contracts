// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TestNFT is ERC721URIStorage {
    string public constant TOKEN_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";
    uint256 private s_tokenCounter;

    constructor() ERC721("Doggie", "DOGE") {
        s_tokenCounter = 0;
    }

    function mintNFT() public returns (uint256) {
        uint tokenId = s_tokenCounter;
        s_tokenCounter += 1;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, TOKEN_URI);
        return s_tokenCounter;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_exists(tokenId), "tokenId does not exist");

        return TOKEN_URI;
    }
}
