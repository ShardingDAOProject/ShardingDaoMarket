pragma solidity 0.6.12;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

contract NFTToken is ERC721 {
    function mint(uint256 tokenId) public {
        _safeMint(msg.sender, tokenId);
    }

    constructor(string memory name, string memory symbol)
        public
        ERC721(name, symbol)
    {}
}
