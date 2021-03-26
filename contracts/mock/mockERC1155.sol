pragma solidity 0.6.12;

import "openzeppelin-solidity/contracts/token/ERC1155/ERC1155.sol";

contract mockERC1155Token is ERC1155 {
    constructor(string memory uri_) public ERC1155(uri_) {}

    mapping(uint256 => string) private _tokenURIs;

    function mint(uint256 id, uint256 amount) public {
        _mint(msg.sender, id, amount, "");
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function uri(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        return _tokenURIs[tokenId];
    }
}
