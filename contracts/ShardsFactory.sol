pragma solidity 0.6.12;

import "./ShardToken.sol";
import "./interface/IShardsFactory.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract ShardsFactory is IShardsFactory, Ownable {
    address public shardMarket;

    function createShardToken(
        uint256 poolId,
        string memory name,
        string memory symbol
    ) external override returns (address token) {
        require(msg.sender == shardMarket, "UNAUTHORIZED");
        bytes memory bytecode = type(ShardToken).creationCode;
        bytes32 salt =
            keccak256(abi.encodePacked(poolId, name, symbol, shardMarket));
        assembly {
            token := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IShardToken(token).initialize(name, symbol, shardMarket);
    }

    function initialize(address _shardMarket) external onlyOwner {
        shardMarket = _shardMarket;
    }
}
