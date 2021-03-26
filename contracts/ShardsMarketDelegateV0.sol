pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./interface/MarketInterfaces.sol";
import "./interface/IWETH.sol";
import "./interface/IShardToken.sol";
import "./interface/IShardsFactory.sol";
import "./interface/IShardsFarm.sol";
import "./interface/IMarketRegulator.sol";
import "./interface/IBuyoutProposals.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/NFTLibrary.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Holder.sol";
import "openzeppelin-solidity/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-solidity/contracts/token/ERC1155/ERC1155Holder.sol";
import "./interface/IUniswapV2Router02.sol";

contract ShardsMarketDelegateV0 is IShardsMarket, ERC721Holder, ERC1155Holder {
    using SafeMath for uint256;

    constructor() public {}

    function initialize(
        address _WETH,
        address _factory,
        address _governance,
        address _router,
        address _dev,
        address _platformFund,
        address _shardsFactory,
        address _regulator,
        address _buyoutProposals
    ) public {
        require(admin == msg.sender, "UNAUTHORIZED");
        require(WETH == address(0), "ALREADY INITIALIZED");
        WETH = _WETH;
        factory = _factory;
        governance = _governance;
        router = _router;
        dev = _dev;
        platformFund = _platformFund;
        shardsFactory = _shardsFactory;
        regulator = _regulator;
        buyoutProposals = _buyoutProposals;
    }

    function createShard(
        Token721[] calldata token721s,
        Token1155[] calldata token1155s,
        string memory shardName,
        string memory shardSymbol,
        uint256 minWantTokenAmount,
        address wantToken
    ) external override returns (uint256 shardPoolId) {
        require(
            NFTLibrary.tokenVerify(shardName, 30) &&
                NFTLibrary.tokenVerify(shardSymbol, 30),
            "INVALID NAME/SYMBOL"
        );

        require(minWantTokenAmount > 0, "INVALID MINAMOUNT INPUT");
        require(
            IMarketRegulator(regulator).IsInWhiteList(wantToken),
            "WANTTOKEN IS NOT ON THE LIST"
        );
        shardPoolId = shardPoolIdCount.add(1);
        poolInfo[shardPoolId] = shardPool({
            creator: msg.sender,
            state: ShardsState.Live,
            createTime: block.timestamp,
            deadlineForStake: block.timestamp.add(deadlineForStake),
            deadlineForRedeem: block.timestamp.add(deadlineForRedeem),
            balanceOfWantToken: 0,
            minWantTokenAmount: minWantTokenAmount,
            isCreatorWithDraw: false,
            wantToken: wantToken,
            openingPrice: 0
        });

        _transferIn(shardPoolId, token721s, token1155s, msg.sender);

        uint256 creatorAmount =
            totalSupply.mul(shardsCreatorProportion).div(max);
        uint256 platformAmount = totalSupply.mul(platformProportion).div(max);
        uint256 stakersAmount =
            totalSupply.sub(creatorAmount).sub(platformAmount);
        shardInfo[shardPoolId] = shard({
            shardName: shardName,
            shardSymbol: shardSymbol,
            shardToken: address(0),
            totalShardSupply: totalSupply,
            shardForCreator: creatorAmount,
            shardForPlatform: platformAmount,
            shardForStakers: stakersAmount,
            burnAmount: 0
        });
        allPools.push(shardPoolId);
        shardPoolIdCount = shardPoolId;
        emit ShardCreated(
            shardPoolId,
            msg.sender,
            shardName,
            shardSymbol,
            minWantTokenAmount,
            block.timestamp,
            totalSupply,
            wantToken
        );
    }

    function stake(uint256 _shardPoolId, uint256 amount) external override {
        require(
            block.timestamp <= poolInfo[_shardPoolId].deadlineForStake,
            "EXPIRED"
        );
        address wantToken = poolInfo[_shardPoolId].wantToken;
        TransferHelper.safeTransferFrom(
            wantToken,
            msg.sender,
            address(this),
            amount
        );
        _stake(_shardPoolId, amount);
    }

    function stakeETH(uint256 _shardPoolId) external payable override {
        require(
            block.timestamp <= poolInfo[_shardPoolId].deadlineForStake,
            "EXPIRED"
        );
        require(poolInfo[_shardPoolId].wantToken == WETH, "UNWANTED");
        IWETH(WETH).deposit{value: msg.value}();
        _stake(_shardPoolId, msg.value);
    }

    function _stake(uint256 _shardPoolId, uint256 amount) private {
        require(amount > 0, "INSUFFIENT INPUT");
        userInfo[_shardPoolId][msg.sender].amount = userInfo[_shardPoolId][
            msg.sender
        ]
            .amount
            .add(amount);
        poolInfo[_shardPoolId].balanceOfWantToken = poolInfo[_shardPoolId]
            .balanceOfWantToken
            .add(amount);
        emit Stake(msg.sender, _shardPoolId, amount);
    }

    function redeem(uint256 _shardPoolId, uint256 amount) external override {
        _redeem(_shardPoolId, amount);
        TransferHelper.safeTransfer(
            poolInfo[_shardPoolId].wantToken,
            msg.sender,
            amount
        );
        emit Redeem(msg.sender, _shardPoolId, amount);
    }

    function redeemETH(uint256 _shardPoolId, uint256 amount) external override {
        require(poolInfo[_shardPoolId].wantToken == WETH, "UNWANTED");
        _redeem(_shardPoolId, amount);
        IWETH(WETH).withdraw(amount);
        TransferHelper.safeTransferETH(msg.sender, amount);
        emit Redeem(msg.sender, _shardPoolId, amount);
    }

    function _redeem(uint256 _shardPoolId, uint256 amount) private {
        require(
            block.timestamp <= poolInfo[_shardPoolId].deadlineForRedeem,
            "EXPIRED"
        );
        require(amount > 0, "INSUFFIENT INPUT");
        userInfo[_shardPoolId][msg.sender].amount = userInfo[_shardPoolId][
            msg.sender
        ]
            .amount
            .sub(amount);
        poolInfo[_shardPoolId].balanceOfWantToken = poolInfo[_shardPoolId]
            .balanceOfWantToken
            .sub(amount);
    }

    function settle(uint256 _shardPoolId) external override {
        require(
            block.timestamp > poolInfo[_shardPoolId].deadlineForRedeem,
            "NOT READY"
        );
        require(
            poolInfo[_shardPoolId].state == ShardsState.Live,
            "LIVE STATE IS REQUIRED"
        );
        if (
            poolInfo[_shardPoolId].balanceOfWantToken <
            poolInfo[_shardPoolId].minWantTokenAmount ||
            IMarketRegulator(regulator).IsInBlackList(_shardPoolId)
        ) {
            poolInfo[_shardPoolId].state = ShardsState.SubscriptionFailed;

            address shardCreator = poolInfo[_shardPoolId].creator;
            _transferOut(_shardPoolId, shardCreator);
            emit SettleFail(_shardPoolId);
        } else {
            _successToSetPrice(_shardPoolId);
        }
    }

    function redeemInSubscriptionFailed(uint256 _shardPoolId)
        external
        override
    {
        require(
            poolInfo[_shardPoolId].state == ShardsState.SubscriptionFailed,
            "WRONG STATE"
        );
        uint256 balance = userInfo[_shardPoolId][msg.sender].amount;
        require(balance > 0, "INSUFFIENT BALANCE");
        userInfo[_shardPoolId][msg.sender].amount = 0;
        poolInfo[_shardPoolId].balanceOfWantToken = poolInfo[_shardPoolId]
            .balanceOfWantToken
            .sub(balance);
        if (poolInfo[_shardPoolId].wantToken == WETH) {
            IWETH(WETH).withdraw(balance);
            TransferHelper.safeTransferETH(msg.sender, balance);
        } else {
            TransferHelper.safeTransfer(
                poolInfo[_shardPoolId].wantToken,
                msg.sender,
                balance
            );
        }

        emit Redeem(msg.sender, _shardPoolId, balance);
    }

    function usersWithdrawShardToken(uint256 _shardPoolId) external override {
        require(
            poolInfo[_shardPoolId].state == ShardsState.Listed ||
                poolInfo[_shardPoolId].state == ShardsState.Buyout ||
                poolInfo[_shardPoolId].state == ShardsState.ApplyForBuyout,
            "WRONG_STATE"
        );
        uint256 userBanlance = userInfo[_shardPoolId][msg.sender].amount;
        bool isWithdrawShard =
            userInfo[_shardPoolId][msg.sender].isWithdrawShard;
        require(userBanlance > 0 && !isWithdrawShard, "INSUFFIENT BALANCE");
        uint256 shardsForUsers = shardInfo[_shardPoolId].shardForStakers;
        uint256 totalBalance = poolInfo[_shardPoolId].balanceOfWantToken;
        // formula:
        // shardAmount/shardsForUsers= userBanlance/totalBalance
        //
        uint256 shardAmount =
            userBanlance.mul(shardsForUsers).div(totalBalance);
        userInfo[_shardPoolId][msg.sender].isWithdrawShard = true;
        IShardToken(shardInfo[_shardPoolId].shardToken).mint(
            msg.sender,
            shardAmount
        );
    }

    function creatorWithdrawWantToken(uint256 _shardPoolId) external override {
        require(msg.sender == poolInfo[_shardPoolId].creator, "UNAUTHORIZED");
        require(
            poolInfo[_shardPoolId].state == ShardsState.Listed ||
                poolInfo[_shardPoolId].state == ShardsState.Buyout ||
                poolInfo[_shardPoolId].state == ShardsState.ApplyForBuyout,
            "WRONG_STATE"
        );

        require(!poolInfo[_shardPoolId].isCreatorWithDraw, "ALREADY WITHDRAW");
        uint256 totalBalance = poolInfo[_shardPoolId].balanceOfWantToken;
        uint256 platformAmount = shardInfo[_shardPoolId].shardForPlatform;
        uint256 fee =
            poolInfo[_shardPoolId].balanceOfWantToken.mul(platformAmount).div(
                shardInfo[_shardPoolId].shardForStakers
            );
        uint256 amount = totalBalance.sub(fee);
        poolInfo[_shardPoolId].isCreatorWithDraw = true;
        if (poolInfo[_shardPoolId].wantToken == WETH) {
            IWETH(WETH).withdraw(amount);
            TransferHelper.safeTransferETH(msg.sender, amount);
        } else {
            TransferHelper.safeTransfer(
                poolInfo[_shardPoolId].wantToken,
                msg.sender,
                amount
            );
        }
        uint256 creatorAmount = shardInfo[_shardPoolId].shardForCreator;
        address shardToken = shardInfo[_shardPoolId].shardToken;
        IShardToken(shardToken).mint(
            poolInfo[_shardPoolId].creator,
            creatorAmount
        );
    }

    function applyForBuyout(uint256 _shardPoolId, uint256 wantTokenAmount)
        external
        override
        returns (uint256 proposalId)
    {
        proposalId = _applyForBuyout(_shardPoolId, wantTokenAmount);
    }

    function applyForBuyoutETH(uint256 _shardPoolId)
        external
        payable
        override
        returns (uint256 proposalId)
    {
        require(poolInfo[_shardPoolId].wantToken == WETH, "UNWANTED");
        proposalId = _applyForBuyout(_shardPoolId, msg.value);
    }

    function _applyForBuyout(uint256 _shardPoolId, uint256 wantTokenAmount)
        private
        returns (uint256 proposalId)
    {
        require(msg.sender == tx.origin, "INVALID SENDER");
        require(
            poolInfo[_shardPoolId].state == ShardsState.Listed,
            "LISTED STATE IS REQUIRED"
        );
        uint256 shardBalance =
            IShardToken(shardInfo[_shardPoolId].shardToken).balanceOf(
                msg.sender
            );
        uint256 totalShardSupply = shardInfo[_shardPoolId].totalShardSupply;

        uint256 currentPrice = getPrice(_shardPoolId);
        uint256 buyoutTimes;
        (proposalId, buyoutTimes) = IBuyoutProposals(buyoutProposals)
            .createProposal(
            _shardPoolId,
            shardBalance,
            wantTokenAmount,
            currentPrice,
            totalShardSupply,
            msg.sender
        );
        if (
            poolInfo[_shardPoolId].wantToken == WETH &&
            msg.value == wantTokenAmount
        ) {
            IWETH(WETH).deposit{value: wantTokenAmount}();
        } else {
            TransferHelper.safeTransferFrom(
                poolInfo[_shardPoolId].wantToken,
                msg.sender,
                address(this),
                wantTokenAmount
            );
        }
        TransferHelper.safeTransferFrom(
            shardInfo[_shardPoolId].shardToken,
            msg.sender,
            address(this),
            shardBalance
        );

        poolInfo[_shardPoolId].state = ShardsState.ApplyForBuyout;

        emit ApplyForBuyout(
            msg.sender,
            proposalId,
            _shardPoolId,
            shardBalance,
            wantTokenAmount,
            block.timestamp,
            buyoutTimes,
            currentPrice,
            block.number
        );
    }

    function vote(uint256 _shardPoolId, bool isAgree) external override {
        require(
            poolInfo[_shardPoolId].state == ShardsState.ApplyForBuyout,
            "WRONG STATE"
        );
        address shard = shardInfo[_shardPoolId].shardToken;

        (uint256 proposalId, uint256 balance) =
            IBuyoutProposals(buyoutProposals).vote(
                _shardPoolId,
                isAgree,
                shard,
                msg.sender
            );
        emit Vote(msg.sender, proposalId, _shardPoolId, isAgree, balance);
    }

    function voteResultConfirm(uint256 _shardPoolId)
        external
        override
        returns (bool)
    {
        require(
            poolInfo[_shardPoolId].state == ShardsState.ApplyForBuyout,
            "WRONG STATE"
        );
        (
            uint256 proposalId,
            bool result,
            address submitter,
            uint256 shardAmount,
            uint256 wantTokenAmount
        ) = IBuyoutProposals(buyoutProposals).voteResultConfirm(_shardPoolId);

        if (result) {
            poolInfo[_shardPoolId].state = ShardsState.Buyout;
            IShardToken(shardInfo[_shardPoolId].shardToken).burn(shardAmount);
            shardInfo[_shardPoolId].burnAmount = shardInfo[_shardPoolId]
                .burnAmount
                .add(shardAmount);

            _transferOut(_shardPoolId, submitter);

            _getProfit(_shardPoolId, wantTokenAmount, shardAmount);
        } else {
            poolInfo[_shardPoolId].state = ShardsState.Listed;
        }

        emit VoteResultConfirm(proposalId, _shardPoolId, result);

        return result;
    }

    function exchangeForWantToken(uint256 _shardPoolId, uint256 shardAmount)
        external
        override
        returns (uint256 wantTokenAmount)
    {
        require(
            poolInfo[_shardPoolId].state == ShardsState.Buyout,
            "WRONG STATE"
        );
        TransferHelper.safeTransferFrom(
            shardInfo[_shardPoolId].shardToken,
            msg.sender,
            address(this),
            shardAmount
        );
        IShardToken(shardInfo[_shardPoolId].shardToken).burn(shardAmount);
        shardInfo[_shardPoolId].burnAmount = shardInfo[_shardPoolId]
            .burnAmount
            .add(shardAmount);

        wantTokenAmount = IBuyoutProposals(buyoutProposals)
            .exchangeForWantToken(_shardPoolId, shardAmount);
        require(wantTokenAmount > 0, "LESS THAN 1 WEI");
        if (poolInfo[_shardPoolId].wantToken == WETH) {
            IWETH(WETH).withdraw(wantTokenAmount);
            TransferHelper.safeTransferETH(msg.sender, wantTokenAmount);
        } else {
            TransferHelper.safeTransfer(
                poolInfo[_shardPoolId].wantToken,
                msg.sender,
                wantTokenAmount
            );
        }
    }

    function redeemForBuyoutFailed(uint256 _proposalId)
        external
        override
        returns (uint256 shardTokenAmount, uint256 wantTokenAmount)
    {
        uint256 shardPoolId;
        (shardPoolId, shardTokenAmount, wantTokenAmount) = IBuyoutProposals(
            buyoutProposals
        )
            .redeemForBuyoutFailed(_proposalId, msg.sender);
        TransferHelper.safeTransfer(
            shardInfo[shardPoolId].shardToken,
            msg.sender,
            shardTokenAmount
        );
        if (poolInfo[shardPoolId].wantToken == WETH) {
            IWETH(WETH).withdraw(wantTokenAmount);
            TransferHelper.safeTransferETH(msg.sender, wantTokenAmount);
        } else {
            TransferHelper.safeTransfer(
                poolInfo[shardPoolId].wantToken,
                msg.sender,
                wantTokenAmount
            );
        }
    }

    function _successToSetPrice(uint256 _shardPoolId) private {
        address shardToken = _deployShardsToken(_shardPoolId);
        poolInfo[_shardPoolId].state = ShardsState.Listed;
        shardInfo[_shardPoolId].shardToken = shardToken;
        address wantToken = poolInfo[_shardPoolId].wantToken;
        uint256 platformAmount = shardInfo[_shardPoolId].shardForPlatform;
        IShardToken(shardToken).mint(address(this), platformAmount);
        uint256 shardPrice =
            poolInfo[_shardPoolId].balanceOfWantToken.mul(1e18).div(
                shardInfo[_shardPoolId].shardForStakers
            );
        //fee= shardPrice * platformAmount =balanceOfWantToken * platformAmount / shardForStakers
        uint256 fee =
            poolInfo[_shardPoolId].balanceOfWantToken.mul(platformAmount).div(
                shardInfo[_shardPoolId].shardForStakers
            );
        poolInfo[_shardPoolId].openingPrice = shardPrice;
        //addLiquidity
        TransferHelper.safeApprove(shardToken, router, platformAmount);
        TransferHelper.safeApprove(wantToken, router, fee);
        IUniswapV2Router02(router).addLiquidity(
            shardToken,
            wantToken,
            platformAmount,
            fee,
            0,
            0,
            address(this),
            now.add(60)
        );

        _addFarmPool(_shardPoolId);

        emit SettleSuccess(
            _shardPoolId,
            platformAmount,
            shardInfo[_shardPoolId].shardForStakers,
            poolInfo[_shardPoolId].balanceOfWantToken,
            fee,
            shardToken
        );
    }

    function _getProfit(
        uint256 _shardPoolId,
        uint256 wantTokenAmount,
        uint256 shardAmount
    ) private {
        address shardToken = shardInfo[_shardPoolId].shardToken;
        address wantToken = poolInfo[_shardPoolId].wantToken;

        address lPTokenAddress =
            NFTLibrary.getPair(shardToken, wantToken, factory);
        uint256 LPTokenBalance =
            NFTLibrary.balanceOf(address(this), lPTokenAddress);
        TransferHelper.safeApprove(lPTokenAddress, router, LPTokenBalance);
        (uint256 amountShardToken, uint256 amountWantToken) =
            IUniswapV2Router02(router).removeLiquidity(
                shardToken,
                wantToken,
                LPTokenBalance,
                0,
                0,
                address(this),
                now.add(60)
            );
        IShardToken(shardInfo[_shardPoolId].shardToken).burn(amountShardToken);
        shardInfo[_shardPoolId].burnAmount = shardInfo[_shardPoolId]
            .burnAmount
            .add(amountShardToken);
        uint256 supply = shardInfo[_shardPoolId].totalShardSupply;
        uint256 wantTokenAmountForExchange =
            amountShardToken.mul(wantTokenAmount).div(supply.sub(shardAmount));
        uint256 totalProfit = amountWantToken.add(wantTokenAmountForExchange);
        uint256 profitForDev = totalProfit.mul(profitProportionForDev).div(max);
        uint256 profitForPlatformFund = totalProfit.sub(profitForDev);
        TransferHelper.safeTransfer(wantToken, dev, profitForDev);
        TransferHelper.safeTransfer(
            wantToken,
            platformFund,
            profitForPlatformFund
        );
    }

    function _transferIn(
        uint256 shardPoolId,
        Token721[] calldata token721s,
        Token1155[] calldata token1155s,
        address from
    ) private {
        require(
            token721s.length.add(token1155s.length) > 0,
            "INSUFFIENT TOKEN"
        );
        for (uint256 i = 0; i < token721s.length; i++) {
            Token721 memory token = token721s[i];
            Token721s[shardPoolId].push(token);

            IERC721(token.contractAddress).safeTransferFrom(
                from,
                address(this),
                token.tokenId
            );
        }
        for (uint256 i = 0; i < token1155s.length; i++) {
            Token1155 memory token = token1155s[i];
            require(token.amount > 0, "INSUFFIENT TOKEN");
            Token1155s[shardPoolId].push(token);
            IERC1155(token.contractAddress).safeTransferFrom(
                from,
                address(this),
                token.tokenId,
                token.amount,
                ""
            );
        }
    }

    function _transferOut(uint256 shardPoolId, address to) private {
        Token721[] memory token721s = Token721s[shardPoolId];
        Token1155[] memory token1155s = Token1155s[shardPoolId];
        for (uint256 i = 0; i < token721s.length; i++) {
            Token721 memory token = token721s[i];
            IERC721(token.contractAddress).safeTransferFrom(
                address(this),
                to,
                token.tokenId
            );
        }
        for (uint256 i = 0; i < token1155s.length; i++) {
            Token1155 memory token = token1155s[i];
            IERC1155(token.contractAddress).safeTransferFrom(
                address(this),
                to,
                token.tokenId,
                token.amount,
                ""
            );
        }
    }

    function _deployShardsToken(uint256 _shardPoolId)
        private
        returns (address token)
    {
        string memory name = shardInfo[_shardPoolId].shardName;
        string memory symbol = shardInfo[_shardPoolId].shardSymbol;
        token = IShardsFactory(shardsFactory).createShardToken(
            _shardPoolId,
            name,
            symbol
        );
    }

    function _addFarmPool(uint256 _shardPoolId) private {
        address shardToken = shardInfo[_shardPoolId].shardToken;
        address wantToken = poolInfo[_shardPoolId].wantToken;
        address lPTokenSwap =
            NFTLibrary.getPair(shardToken, wantToken, factory);

        address TokenToEthSwap =
            wantToken == WETH
                ? address(0)
                : NFTLibrary.getPair(wantToken, WETH, factory);

        IShardsFarm(shardsFarm).add(_shardPoolId, lPTokenSwap, TokenToEthSwap);
    }

    //governance operation
    function setDeadlineForStake(uint256 _deadlineForStake) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        deadlineForStake = _deadlineForStake;
    }

    function setDeadlineForRedeem(uint256 _deadlineForRedeem)
        external
        override
    {
        require(msg.sender == governance, "UNAUTHORIZED");
        deadlineForRedeem = _deadlineForRedeem;
    }

    function setShardsCreatorProportion(uint256 _shardsCreatorProportion)
        external
        override
    {
        require(msg.sender == governance, "UNAUTHORIZED");
        require(_shardsCreatorProportion < max, "INVALID");
        shardsCreatorProportion = _shardsCreatorProportion;
    }

    function setPlatformProportion(uint256 _platformProportion)
        external
        override
    {
        require(msg.sender == governance, "UNAUTHORIZED");
        require(_platformProportion < max, "INVALID");
        platformProportion = _platformProportion;
    }

    function setTotalSupply(uint256 _totalSupply) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        totalSupply = _totalSupply;
    }

    function setProfitProportionForDev(uint256 _profitProportionForDev)
        external
        override
    {
        require(msg.sender == governance, "UNAUTHORIZED");
        profitProportionForDev = _profitProportionForDev;
    }

    function setShardsFarm(address _shardsFarm) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        shardsFarm = _shardsFarm;
    }

    function setRegulator(address _regulator) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        regulator = _regulator;
    }

    function setFactory(address _factory) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        factory = _factory;
    }

    function setShardsFactory(address _shardsFactory) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        shardsFactory = _shardsFactory;
    }

    function setRouter(address _router) external override {
        require(msg.sender == governance, "UNAUTHORIZED");
        router = _router;
    }

    //admin operation
    function setPlatformFund(address _platformFund) external override {
        require(msg.sender == admin, "UNAUTHORIZED");
        platformFund = _platformFund;
    }

    function setDev(address _dev) external override {
        require(msg.sender == admin, "UNAUTHORIZED");
        dev = _dev;
    }

    //pending function  not use right now

    // function shardAudit(uint256 _shardPoolId, bool isPassed) external override {
    //     require(msg.sender == admin, "UNAUTHORIZED");
    //     require(
    //         poolInfo[_shardPoolId].state == ShardsState.Pending,
    //         "WRONG STATE"
    //     );
    //     if (isPassed) {
    //         poolInfo[_shardPoolId].state = ShardsState.Live;
    //     } else {
    //         poolInfo[_shardPoolId].state = ShardsState.AuditFailed;
    //         address shardCreator = poolInfo[_shardPoolId].creator;
    //         _transferOut(_shardPoolId, shardCreator);
    //     }
    // }

    //view function
    function getPrice(uint256 _shardPoolId)
        public
        view
        override
        returns (uint256 currentPrice)
    {
        address tokenA = shardInfo[_shardPoolId].shardToken;
        address tokenB = poolInfo[_shardPoolId].wantToken;
        currentPrice = NFTLibrary.getPrice(tokenA, tokenB, factory);
    }

    function getAllPools()
        external
        view
        override
        returns (uint256[] memory _pools)
    {
        _pools = allPools;
    }

    function getTokens(uint256 shardPoolId)
        external
        view
        override
        returns (Token721[] memory _token721s, Token1155[] memory _token1155s)
    {
        _token721s = Token721s[shardPoolId];
        _token1155s = Token1155s[shardPoolId];
    }
}
