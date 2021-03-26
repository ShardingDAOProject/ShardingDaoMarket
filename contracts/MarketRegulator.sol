pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./interface/IERC20.sol";
import "./interface/MarketInterfaces.sol";

contract MarketRegulator {
    constructor() public {
        admin = msg.sender;
    }

    event BlacklistAdd(uint256 indexed _shardPoolId);
    event BlacklistRemove(uint256 indexed _shardPoolId);

    address public admin;
    address public market;

    mapping(address => uint256) internal whiteListIndexForWantToken; // savedIndex = realIndex + 1
    struct whiteListToken {
        address token;
        string symbol;
    }
    whiteListToken[] internal wantTokenWhiteList;

    mapping(uint256 => uint256) internal blacklistIndexForShardPool;
    uint256[] internal shardPoolBlacklist;

    function setWhiteListForWantToken(address wantToken, bool isListed)
        external
    {
        require(msg.sender == admin, "UNAUTHORIZED");
        require(wantToken != address(0), "INVALID INPUT");
        uint256 index = whiteListIndexForWantToken[wantToken];
        require(
            (index > 0 && !isListed) || (index == 0 && isListed),
            "AlREADY SET"
        );

        if (index > 0 && !isListed) {
            if (index < wantTokenWhiteList.length) {
                whiteListIndexForWantToken[
                    wantTokenWhiteList[wantTokenWhiteList.length - 1].token
                ] = index;
                wantTokenWhiteList[index - 1] = wantTokenWhiteList[
                    wantTokenWhiteList.length - 1
                ];
            }
            whiteListIndexForWantToken[wantToken] = 0;
            wantTokenWhiteList.pop();
        }
        if (index == 0 && isListed) {
            string memory tokenSymbol = IERC20(wantToken).symbol();
            wantTokenWhiteList.push(
                whiteListToken({token: wantToken, symbol: tokenSymbol})
            );
            whiteListIndexForWantToken[wantToken] = wantTokenWhiteList.length;
        }
    }

    function setBlacklistForShardPool(uint256 _shardPoolId, bool isListed)
        external
    {
        require(msg.sender == admin, "UNAUTHORIZED");
        require(
            _shardPoolId <= IShardsMarket(market).shardPoolIdCount(),
            "NOT EXIST"
        );

        uint256 index = blacklistIndexForShardPool[_shardPoolId];
        require(
            (index > 0 && !isListed) || (index == 0 && isListed),
            "AlREADY SET"
        );

        if (index > 0 && !isListed) {
            if (index < shardPoolBlacklist.length) {
                blacklistIndexForShardPool[
                    shardPoolBlacklist[shardPoolBlacklist.length - 1]
                ] = index;
                shardPoolBlacklist[index - 1] = shardPoolBlacklist[
                    shardPoolBlacklist.length - 1
                ];
            }
            blacklistIndexForShardPool[_shardPoolId] = 0;
            shardPoolBlacklist.pop();
            emit BlacklistRemove(_shardPoolId);
        }
        if (index == 0 && isListed) {
            shardPoolBlacklist.push(_shardPoolId);
            blacklistIndexForShardPool[_shardPoolId] = shardPoolBlacklist
                .length;
            emit BlacklistAdd(_shardPoolId);
        }
    }

    function setAdmin(address _admin) external {
        require(msg.sender == admin, "UNAUTHORIZED");
        admin = _admin;
    }

    function getWantTokenWhiteList()
        external
        view
        returns (whiteListToken[] memory _wantTokenWhiteList)
    {
        _wantTokenWhiteList = wantTokenWhiteList;
    }

    function getBlacklistPools()
        external
        view
        returns (uint256[] memory _blacklistPools)
    {
        _blacklistPools = shardPoolBlacklist;
    }

    function IsInWhiteList(address wantToken)
        external
        view
        returns (bool inTheList)
    {
        uint256 index = whiteListIndexForWantToken[wantToken];
        if (index == 0) inTheList = false;
        else inTheList = true;
    }

    function IsInBlackList(uint256 _shardPoolId)
        external
        view
        returns (bool inTheList)
    {
        uint256 index = blacklistIndexForShardPool[_shardPoolId];
        if (index == 0) inTheList = false;
        else inTheList = true;
    }

    function setMarket(address _market) external {
        require(msg.sender == admin, "UNAUTHORIZED");
        market = _market;
    }
}
