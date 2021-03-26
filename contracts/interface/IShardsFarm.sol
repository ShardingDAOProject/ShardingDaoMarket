pragma solidity 0.6.12;

interface IShardsFarm {
    function add(
        uint256 poolId,
        address lpToken,
        address ethLpToken
    ) external;
}
