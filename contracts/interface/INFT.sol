pragma solidity 0.6.12;

interface INFT {
    function addliquidity(
        address token,
        uint256 tokenAmount,
        uint256 ETHAmount
    ) external payable;
}
