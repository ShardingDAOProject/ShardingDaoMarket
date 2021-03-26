pragma solidity 0.6.12;

interface IMarketRegulator {
    function IsInWhiteList(address wantToken)
        external
        view
        returns (bool inTheList);

    function IsInBlackList(uint256 _shardPoolId)
        external
        view
        returns (bool inTheList);
}
