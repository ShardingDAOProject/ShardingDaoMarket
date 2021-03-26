pragma solidity 0.6.12;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract mockERCToken is ERC20 {
    constructor(string memory name, string memory symbol)
        public
        ERC20(name, symbol)
    {}
}
