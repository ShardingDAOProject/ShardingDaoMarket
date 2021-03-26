pragma solidity 0.6.12;
import "./interface/IMarketRegulator.sol";
import "./interface/IBuyoutProposals.sol";
import "./interface/IShardToken.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract BuyoutProposals is IBuyoutProposals {
    using SafeMath for uint256;

    constructor() public {}

    function initialize(address _governance, address _regulator) external {
        require(governance == msg.sender, "UNAUTHORIZED");
        require(regulator == address(0), "ALREADY INITIALIZED");
        governance = _governance;
        regulator = _regulator;
    }

    function createProposal(
        uint256 _shardPoolId,
        uint256 shardBalance,
        uint256 wantTokenAmount,
        uint256 currentPrice,
        uint256 totalShardSupply,
        address submitter
    ) external override returns (uint256, uint256) {
        require(msg.sender == market, "UNAUTHORIZED");
        require(
            shardBalance >= totalShardSupply.mul(buyoutProportion).div(max),
            "INSUFFIENT BALANCE"
        );
        uint256 otherShards = totalShardSupply.sub(shardBalance);
        uint256 needAmount =
            otherShards.mul(currentPrice).mul(buyoutTimes).div(max).div(1e18);
        require(wantTokenAmount >= needAmount, "INSUFFICIENT WANTTOKENAMOUNT");
        require(
            !IMarketRegulator(regulator).IsInBlackList(_shardPoolId),
            "ON THE BLACKLIST"
        );
        uint256 proposalId = proposolIdCount.add(1);
        proposalIds[_shardPoolId] = proposalId;
        uint256 timestamp = block.timestamp.add(voteLenth);
        proposals[proposalId] = Proposal({
            votesReceived: 0,
            voteTotal: 0,
            passed: false,
            submitter: submitter,
            voteDeadline: timestamp,
            shardAmount: shardBalance,
            wantTokenAmount: wantTokenAmount,
            buyoutTimes: buyoutTimes,
            price: currentPrice,
            isSubmitterWithDraw: false,
            shardPoolId: _shardPoolId,
            isFailedConfirmed: false,
            blockHeight: block.number,
            createTime: block.timestamp
        });
        allVotes[proposalId] = otherShards;
        proposalsHistory[_shardPoolId].push(proposalId);
        voted[proposalId][submitter] = true;
        proposolIdCount = proposalId;
        return (proposalId, buyoutTimes);
    }

    function vote(
        uint256 _shardPoolId,
        bool isAgree,
        address shard,
        address voter
    ) external override returns (uint256 proposalId, uint256 balance) {
        require(msg.sender == market, "UNAUTHORIZED");
        proposalId = proposalIds[_shardPoolId];
        require(
            block.timestamp <= proposals[proposalId].voteDeadline,
            "EXPIRED"
        );
        uint256 blockHeight = proposals[proposalId].blockHeight;
        balance = IShardToken(shard).getPriorVotes(voter, blockHeight);
        require(balance > 0, "INSUFFICIENT VOTERIGHT");
        require(!voted[proposalId][voter], "AlREADY VOTED");
        voted[proposalId][voter] = true;
        if (isAgree) {
            proposals[proposalId].votesReceived = proposals[proposalId]
                .votesReceived
                .add(balance);
            proposals[proposalId].voteTotal = proposals[proposalId]
                .voteTotal
                .add(balance);
        } else {
            proposals[proposalId].voteTotal = proposals[proposalId]
                .voteTotal
                .add(balance);
        }
    }

    function voteResultConfirm(uint256 _shardPoolId)
        external
        override
        returns (
            uint256 proposalId,
            bool result,
            address submitter,
            uint256 shardAmount,
            uint256 wantTokenAmount
        )
    {
        require(msg.sender == market, "UNAUTHORIZED");
        proposalId = proposalIds[_shardPoolId];
        require(
            block.timestamp > proposals[proposalId].voteDeadline,
            "NOT READY"
        );
        uint256 votesRejected =
            proposals[proposalId].voteTotal.sub(
                proposals[proposalId].votesReceived
            );
        uint256 rejectNeed = max.sub(passNeeded);
        if (
            votesRejected <= allVotes[proposalId].mul(rejectNeed).div(max) &&
            !IMarketRegulator(regulator).IsInBlackList(_shardPoolId)
        ) {
            proposals[proposalId].passed = true;
            result = true;
            submitter = proposals[proposalId].submitter;
            shardAmount = proposals[proposalId].shardAmount;
            wantTokenAmount = proposals[proposalId].wantTokenAmount;
        } else {
            proposals[proposalId].passed = false;
            proposals[proposalId].isFailedConfirmed = true;
            result = false;
        }
    }

    function exchangeForWantToken(uint256 _shardPoolId, uint256 shardAmount)
        external
        view
        override
        returns (uint256 wantTokenAmount)
    {
        uint256 proposalId = proposalIds[_shardPoolId];
        Proposal memory p = proposals[proposalId];
        uint256 otherShards = allVotes[proposalId];
        wantTokenAmount = shardAmount.mul(p.wantTokenAmount).div(otherShards);
    }

    function redeemForBuyoutFailed(uint256 _proposalId, address submitter)
        external
        override
        returns (
            uint256 shardPoolId,
            uint256 shardTokenAmount,
            uint256 wantTokenAmount
        )
    {
        require(msg.sender == market, "UNAUTHORIZED");
        Proposal memory p = proposals[_proposalId];
        require(submitter == p.submitter, "UNAUTHORIZED");
        require(
            p.isFailedConfirmed && !p.isSubmitterWithDraw && !p.passed,
            "WRONG STATE"
        );
        shardPoolId = p.shardPoolId;
        shardTokenAmount = p.shardAmount;
        wantTokenAmount = p.wantTokenAmount;
        proposals[_proposalId].isSubmitterWithDraw = true;
    }

    function setVoteLenth(uint256 _voteLenth) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        voteLenth = _voteLenth;
    }

    function setPassNeeded(uint256 _passNeeded) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        require(_passNeeded < max, "INVALID");
        passNeeded = _passNeeded;
    }

    function setBuyoutProportion(uint256 _buyoutProportion) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        require(_buyoutProportion < max, "INVALID");
        buyoutProportion = _buyoutProportion;
    }

    function setBuyoutTimes(uint256 _buyoutTimes) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        buyoutTimes = _buyoutTimes;
    }

    function setMarket(address _market) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        market = _market;
    }

    function setRegulator(address _regulator) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        regulator = _regulator;
    }

    function getProposalsForExactPool(uint256 _shardPoolId)
        external
        view
        override
        returns (uint256[] memory _proposalsHistory)
    {
        _proposalsHistory = proposalsHistory[_shardPoolId];
    }
}
