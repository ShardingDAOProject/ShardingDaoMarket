pragma solidity 0.6.12;

import "../interface/IShardsFarm.sol";

contract MockFarm is IShardsFarm {
    function add(
        uint256 poolId,
        address lpToken,
        address ethLpToken
    ) external override {}
}
