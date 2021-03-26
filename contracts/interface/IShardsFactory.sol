pragma solidity 0.6.12;

interface IShardsFactory {
    event ShardTokenCreated(address shardToken);

    function createShardToken(
        uint256 poolId,
        string memory name,
        string memory symbol
    ) external returns (address shardToken);
}
