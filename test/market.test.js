const NFTToken = artifacts.require('NFTToken');
const MockWETH = artifacts.require('MockWETH');
const MockFactory = artifacts.require('UniswapV2Factory');
const Router = artifacts.require('UniswapV2Router02');
const ShardToken = artifacts.require('ShardToken');
const Pair = artifacts.require('UniswapV2Pair');
const MockERC20Token = artifacts.require('mockERCToken');
const mockERC1155Token = artifacts.require('mockERC1155Token');

const MockFarm = artifacts.require('MockFarm');

const ShardsFactory = artifacts.require('ShardsFactory');
const ShardsMarketDelegateV0 = artifacts.require('ShardsMarketDelegateV0');
const ShardsMarketDelegator = artifacts.require('ShardsMarketDelegator');

const BuyoutProposalsDelegate = artifacts.require('BuyoutProposalsDelegate');
const BuyoutProposalsDelegator = artifacts.require('BuyoutProposalsDelegator');
const MarketRegulator = artifacts.require('MarketRegulator');
const utils = require("./utils");

const decimals = "1000000000000000000";
const mine = (timestamp) => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            id: Date.now(),
            params: [timestamp],
        }, (err, res) => {
            if (err) return reject(err)
            resolve(res)
        })
    })
}

contract('deploy contract', (accounts) => {
    let bob = accounts[0];
    let alex = accounts[1];
    let dev = accounts[2];
    let tokenBar = accounts[3];
    beforeEach(async () => {

        this.mockERC1155Token = await mockERC1155Token.new("NFT", { from: bob });
        this.NFTToken = await NFTToken.new("NFT", "NFT", { from: bob });
        this.MockERC20Token = await MockERC20Token.new("ELF", "ELF", { from: bob });
        this.MockWETH = await MockWETH.new({ from: bob });
        this.MockFarm = await MockFarm.new({ from: bob });
        this.MockFactory = await MockFactory.new(bob, { from: bob, gas: 6000000 });
        this.Router = await Router.new(this.MockFactory.address, this.MockWETH.address, { from: bob, gas: 6000000 });

        this.ShardsFactory = await ShardsFactory.new({ from: bob });

        this.MarketRegulator = await MarketRegulator.new({ from: bob });

        this.BuyoutProposalsDelegate = await BuyoutProposalsDelegate.new({ from: bob });
        this.BuyoutProposalsDelegator = await BuyoutProposalsDelegator.new(bob, this.MarketRegulator.address, this.BuyoutProposalsDelegate.address, { from: bob });

        this.ShardsMarketDelegateV0 = await ShardsMarketDelegateV0.new({ from: bob, gas: 6200000 });
        this.ShardsMarketDelegator = await ShardsMarketDelegator.new(this.MockWETH.address, this.MockFactory.address, bob, this.Router.address, dev, tokenBar, this.ShardsFactory.address, this.MarketRegulator.address, this.BuyoutProposalsDelegator.address, this.ShardsMarketDelegateV0.address, { from: bob, gas: 6200000 });


        await this.ShardsFactory.initialize(this.ShardsMarketDelegator.address, { from: bob });


        this.ShardsMarketDelegator = await ShardsMarketDelegateV0.at(this.ShardsMarketDelegator.address);
        await this.ShardsMarketDelegator.setShardsFarm(this.MockFarm.address, { from: bob });
        await this.MarketRegulator.setMarket(this.ShardsMarketDelegator.address, { from: bob });
        await this.BuyoutProposalsDelegator.setMarket(this.ShardsMarketDelegator.address, { from: bob });

        await this.MarketRegulator.setWhiteListForWantToken(this.MockERC20Token.address, true, { from: bob });
        await this.MarketRegulator.setWhiteListForWantToken(this.MockWETH.address, true, { from: bob });


    });
    it('NFTToken mint works', async () => {
        await this.NFTToken.mint(100);
        let owner = await this.NFTToken.ownerOf(100);
        assert.equal(owner, bob);

        await this.mockERC1155Token.mint(100, 10);
        let balance = await this.mockERC1155Token.balanceOf(bob, 100);
        assert.equal(balance, 10);
    });
    it('createShard works', async () => {
        await this.NFTToken.mint(100);
        await this.mockERC1155Token.mint(100, 10);

        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);
        await this.mockERC1155Token.setApprovalForAll(this.ShardsMarketDelegator.address, true);

        var token721 = [this.NFTToken.address, 100];
        var token1155 = [this.mockERC1155Token.address, 100, 10];
        token721s = [token721];
        token1155s = [token1155];

        //UNAUTHORIZED
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.createShard(
                token721s,
                token1155s,
                "myshard",
                "myshard",
                12,
                this.MockWETH.address, { from: alex })
        );

        //success
        await this.ShardsMarketDelegator.createShard(
            token721s,
            token1155s,
            "myshard",
            "myshard",
            12,
            this.MockWETH.address);
        var shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfo[0], bob);

        let owner = await this.NFTToken.ownerOf(100);
        assert.equal(owner, this.ShardsMarketDelegator.address);

        let amount = await this.mockERC1155Token.balanceOf(this.ShardsMarketDelegator.address, 100);
        assert.equal(amount, 10);
    });
    it('stake works', async () => {
        await this.NFTToken.mint(100);
        await this.mockERC1155Token.mint(100, 10);

        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);
        await this.mockERC1155Token.setApprovalForAll(this.ShardsMarketDelegator.address, true);

        var token721 = [this.NFTToken.address, 100];
        var token1155 = [this.mockERC1155Token.address, 100, 10];
        token721s = [token721];
        token1155s = [token1155];

        await this.ShardsMarketDelegator.createShard(
            token721s,
            token1155s,
            "myshard",
            "myshard",
            12,
            this.MockWETH.address);

        //success
        await this.ShardsMarketDelegator.stakeETH(1, { value: 10, from: bob });

        let balance = await this.MockWETH.balanceOf(this.ShardsMarketDelegator.address);
        assert.equal(balance, 10);

        var shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfo[5], 10);

        var userInfo = await this.ShardsMarketDelegator.userInfo.call(1, bob);
        assert.equal(userInfo[0], 10);


        await this.MockWETH.deposit({ value: 10 });
        await this.MockWETH.approve(this.ShardsMarketDelegator.address, 10);
        await this.ShardsMarketDelegator.stake(1, 10, { from: bob });

        balance = await this.MockWETH.balanceOf(this.ShardsMarketDelegator.address);
        assert.equal(balance, 20);

        shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfo[5], 20);

        userInfo = await this.ShardsMarketDelegator.userInfo.call(1, bob);
        assert.equal(userInfo[0], 20);

        //EXPIRED
        deadlineForStake = 432000 + 20;
        await mine(deadlineForStake); //skip to  deadlineForRedeem
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.stakeETH(1, { value: 10, from: bob })
        );
    });
    it('redeem works', async () => {
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            12,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: 10, from: bob });

        var balanceBefore = await this.MockWETH.balanceOf(this.ShardsMarketDelegator.address);
        assert.equal(balanceBefore, 10);
        var shardPoolInfoBefore = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfoBefore[5], 10);//balanceOfWantToken
        var userInfoBefore = await this.ShardsMarketDelegator.userInfo.call(1, bob);
        assert.equal(userInfoBefore[0], 10);

        await this.ShardsMarketDelegator.redeem(1, 5);

        var balanceAfter = await this.MockWETH.balanceOf(this.ShardsMarketDelegator.address);
        assert.equal(balanceAfter, 5);
        var shardPoolInfoAfter = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfoAfter[5], 5);
        var userInfoAfter = await this.ShardsMarketDelegator.userInfo.call(1, bob);
        assert.equal(userInfoAfter[0], 5);

        var userBalanceAfter = await this.MockWETH.balanceOf(bob);
        assert.equal(userBalanceAfter, 5);
        //INSUFFICIENT BALANCE
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.redeem(1, 10)
        );
        var ETHamount = 3;
        await this.ShardsMarketDelegator.redeemETH(1, ETHamount);
        balanceAfter = await this.MockWETH.balanceOf(this.ShardsMarketDelegator.address);
        assert.equal(balanceAfter, 5 - ETHamount);

        //EXPIRED
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.redeem(1, 5)
        );
    });
    it('settle fail works', async () => {
        await this.NFTToken.mint(100);
        await this.mockERC1155Token.mint(100, 10);

        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);
        await this.mockERC1155Token.setApprovalForAll(this.ShardsMarketDelegator.address, true);

        var token721 = [this.NFTToken.address, 100];
        var token1155 = [this.mockERC1155Token.address, 100, 10];
        token721s = [token721];
        token1155s = [token1155];

        await this.ShardsMarketDelegator.createShard(
            token721s,
            token1155s,
            "myshard",
            "myshard",
            12,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: 10, from: bob });


        // //NFT:NOT READY
        // utils.assertThrowsAsynchronously(
        //     () => this.ShardsMarketDelegator.settle(1)
        // );

        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        var shardPoolInfoBefor = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfoBefor[1], 0);//state
        await this.ShardsMarketDelegator.settle(1);

        var shardPoolInfoAfter = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfoAfter[1], 4);//state

        //NFT:LIVE STATE IS REQUIRED
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.settle(1)
        );
    });
    it('redeemInSubscriptionFailed works', async () => {
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            12,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: 10, from: bob });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1);
        var shardPoolInfoAfter = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfoAfter[1], 4);//state

        await this.ShardsMarketDelegator.redeemInSubscriptionFailed(1, { from: bob });

        var userInfoAfter = await this.ShardsMarketDelegator.userInfo.call(1, bob);
        assert.equal(userInfoAfter[0], 0);

    });


    it('settle success works', async () => {

        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: bob });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        var shardPoolInfoAfter = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfoAfter[1], 1);//state

        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        this.ShardToken = await ShardToken.at(shardInfo[2]);

        let owner = await this.NFTToken.ownerOf(100);
        assert.equal(owner, this.ShardsMarketDelegator.address);
    });

    it('creatorWithdrawWantToken  works', async () => {
        var code = await this.MockFactory.pairCodeHash.call();
        assert.equal(code, "0xa2466033d069ae3a304e2d54d98f0e74ec54c307102ee0d1794c437b35f7db63");
        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);

        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: bob });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem

        //WRONG_STATE
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.creatorWithdrawWantToken(1)
        );

        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        var shardPoolInfoAfter = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfoAfter[1], 1);//state


        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        this.ShardToken = await ShardToken.at(shardInfo[2]);
        shardBalance = await this.ShardToken.balanceOf(this.ShardsMarketDelegator.address);
        assert.equal(shardBalance, 0);

        //UNAUTHORIZED
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.creatorWithdrawWantToken(1, { from: alex })
        );

        await this.ShardsMarketDelegator.creatorWithdrawWantToken(1, { gas: 6000000 });

        //ALREADY WITHDRAW"
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.creatorWithdrawWantToken(1)
        );

        // var userBalanceAfter = await this.MockWETH.balanceOf(bob);

        // let shardBalanceForPlatform = 10000 * 0.05;
        // var fee = shardBalanceForPlatform * amount / (10000 * 0.9);

        // amountExpect = amount - parseInt(fee);

        // balance = "944444444444444445";
        // assert.equal(userBalanceAfter, amountExpect);
    });
    it('applyForBuyout  works', async () => {
        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: alex });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        await this.ShardsMarketDelegator.usersWithdrawShardToken(1, { from: alex });

        var shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        var pairAddress = await this.MockFactory.getPair.call(shardInfo[2], shardPoolInfo[8]);
        this.Pair = await Pair.at(pairAddress);
        var reverse = await this.Pair.getReserves.call();
        var reverse0 = reverse[0] / reverse[1] > 1 ? reverse[0] : reverse[1];
        var reverse1 = reverse[0] / reverse[1] > 1 ? reverse[1] : reverse[0];

        assert.equal(reverse0, 500000000000000000000n);
        assert.equal(reverse1, 55555555555555555n);
        this.ShardToken = await ShardToken.at(shardInfo[2]);
        shardBalance = await this.ShardToken.balanceOf(alex);
        // // let amountNeed = parseInt(price) * (10000 * decimals - shardBalance) / decimals;
        let openPrice = parseInt(reverse1 * 1e18 / reverse0);

        amountLimit = "3111111111111110000";
        amountNeed = "222222222222222000";
        assert.equal(shardBalance, 9000000000000000000000n);
        //approve
        await this.ShardToken.approve(this.ShardsMarketDelegator.address, shardBalance, { from: alex });
        await this.MockWETH.deposit({ value: amountLimit, from: alex });
        await this.MockWETH.approve(this.ShardsMarketDelegator.address, amountLimit, { from: alex });

        //INSUFFIENT BALANCE
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.applyForBuyout(1, amountLimit, { from: bob })
        );

        price = await this.ShardsMarketDelegator.getPrice.call(1);
        assert.equal(price, openPrice);
        await this.ShardsMarketDelegator.applyForBuyout(1, amountLimit, { from: alex });

        shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);

        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        assert.equal(shardPoolInfo[1], 2);//state : applyForBuyout
        assert.equal(shardPoolInfo[9], openPrice);
        shardBalance = "9000000000000000000000";
        var voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);

        amountNeed = (shardInfo[3] - voteInfo[5]) * price / 1e18;
        assert.equal(voteInfo[3], alex); //submmiter:alex
        assert.equal(voteInfo[5], shardBalance); //shardAmount:9000000000000000000000
        assert.equal(voteInfo[6], amountLimit); //wantTokenAmount:3111111111111110000

    });
    it('vote  works', async () => {
        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: alex });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        await this.ShardsMarketDelegator.creatorWithdrawWantToken(1, { from: bob });
        await this.ShardsMarketDelegator.usersWithdrawShardToken(1, { from: alex });
        //approve
        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        this.ShardToken = await ShardToken.at(shardInfo[2]);
        shardBalance = await this.ShardToken.balanceOf(alex);

        amountNeed = "3111111111111110000";
        await this.MockWETH.deposit({ value: amountNeed, from: alex });
        await this.ShardToken.approve(this.ShardsMarketDelegator.address, shardBalance, { from: alex });
        await this.MockWETH.approve(this.ShardsMarketDelegator.address, amountNeed, { from: alex });


        await this.ShardsMarketDelegator.applyForBuyout(1, amountNeed, { from: alex });

        var voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);
        assert.equal(voteInfo[0], 0); //votesReceived:0
        assert.equal(voteInfo[1], 0); //voteTotal:0

        //vote follow the block height 
        amoutTransfer = "100000000000000000000";
        await this.ShardToken.transfer(accounts[3], amoutTransfer, { from: bob });
        //INSUFFICIENT VOTERIGHT
        utils.assertThrowsAsynchronously(
            () => this.ShardsMarketDelegator.vote(1, true, { from: accounts[3] })
        );

        await this.ShardsMarketDelegator.vote(1, true, { from: bob });

        shardBalance = await this.ShardToken.balanceOf(bob);
        shardBalanceExpect = "400000000000000000000";
        assert.equal(shardBalance, shardBalanceExpect);

        voteBalanace = await this.ShardToken.getPriorVotes(bob, voteInfo[12]);//blockHeight
        voteBalanaceExpect = "500000000000000000000";
        assert.equal(voteBalanace, voteBalanaceExpect);

        voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);
        assert.equal(voteInfo[0], voteBalanaceExpect); //votesReceived:0
        assert.equal(voteInfo[1], voteBalanaceExpect); //voteTotal:0
    });

    it('voteResultConfirm success works', async () => {
        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: alex });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        await this.ShardsMarketDelegator.creatorWithdrawWantToken(1, { from: bob });
        await this.ShardsMarketDelegator.usersWithdrawShardToken(1, { from: alex });
        //approve
        var shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        this.ShardToken = await ShardToken.at(shardInfo[2]);
        shardBalance = await this.ShardToken.balanceOf(alex);
        amountNeed = "1111111111111110000";
        await this.MockWETH.deposit({ value: amountNeed, from: alex });
        await this.ShardToken.approve(this.ShardsMarketDelegator.address, shardBalance, { from: alex });
        await this.MockWETH.approve(this.ShardsMarketDelegator.address, amountNeed, { from: alex });

        await this.ShardsMarketDelegator.applyForBuyout(1, amountNeed, { from: alex });
        await this.ShardsMarketDelegator.vote(1, true, { from: bob });

        voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);

        voteLenth = 259200 + 20;
        await mine(voteLenth); //skip to  voteDeadline

        await this.ShardsMarketDelegator.voteResultConfirm(1, { from: alex });

        voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);
        assert.equal(voteInfo[2], true); //passed:true

        shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfo[1], 3); //state:buyout

        owner = await this.NFTToken.ownerOf(100);
        assert.equal(owner, alex);

        //profit test 
        devProfit = await this.MockWETH.balanceOf(dev, { from: dev });
        tokenBarProfit = await this.MockWETH.balanceOf(tokenBar, { from: tokenBar });
        devProfitExpect = 122222222222222080;
        tokenBarProfitExpect = 488888888888888300;
        assert.equal(devProfit, devProfitExpect);
        assert.equal(tokenBarProfit, tokenBarProfitExpect);
    });
    it('voteResultConfirm fail works', async () => {
        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: alex });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        await this.ShardsMarketDelegator.creatorWithdrawWantToken(1, { from: bob });
        await this.ShardsMarketDelegator.usersWithdrawShardToken(1, { from: alex });
        //approve
        var shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        this.ShardToken = await ShardToken.at(shardInfo[2]);
        shardBalance = await this.ShardToken.balanceOf(alex);
        amountNeed = "1111111111111110000";
        await this.MockWETH.deposit({ value: amountNeed, from: alex });
        await this.ShardToken.approve(this.ShardsMarketDelegator.address, shardBalance, { from: alex });
        await this.MockWETH.approve(this.ShardsMarketDelegator.address, amountNeed, { from: alex });

        await this.ShardsMarketDelegator.applyForBuyout(1, amountNeed, { from: alex });
        await this.ShardsMarketDelegator.vote(1, false, { from: bob });

        voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);

        voteLenth = 259200 + 20
        await mine(voteLenth); //skip to  voteDeadline

        await this.ShardsMarketDelegator.voteResultConfirm(1, { from: alex });

        voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);
        assert.equal(voteInfo[2], false); //passed:true

        shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfo[1], 1); //state:BuyoutFailed

        owner = await this.NFTToken.ownerOf(100);
        assert.equal(owner, this.ShardsMarketDelegator.address);
    });
    it('redeemForBuyoutFailed  works', async () => {
        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: alex });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        await this.ShardsMarketDelegator.creatorWithdrawWantToken(1, { from: bob });
        await this.ShardsMarketDelegator.usersWithdrawShardToken(1, { from: alex });
        //approve
        var shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        this.ShardToken = await ShardToken.at(shardInfo[2]);
        shardBalance = await this.ShardToken.balanceOf(alex);
        amountNeed = "1111111111111110000";
        await this.MockWETH.deposit({ value: amountNeed, from: alex });
        await this.ShardToken.approve(this.ShardsMarketDelegator.address, shardBalance, { from: alex });
        await this.MockWETH.approve(this.ShardsMarketDelegator.address, amountNeed, { from: alex });

        await this.ShardsMarketDelegator.applyForBuyout(1, amountNeed, { from: alex });
        await this.ShardsMarketDelegator.vote(1, false, { from: bob });

        voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);

        voteLenth = 259200 + 20
        await mine(voteLenth); //skip to  voteDeadline

        await this.ShardsMarketDelegator.voteResultConfirm(1, { from: alex });

        await this.ShardsMarketDelegator.redeemForBuyoutFailed(1, { from: alex });

        shardBalanceNew = await this.ShardToken.balanceOf(alex);
        assert.equal(shardBalanceNew, 9e+21);
        // ETHBalance = await this.MockWETH.balanceOf(alex);
        // assert.equal(ETHBalance, amountNeed);

        shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        assert.equal(shardPoolInfo[1], 1); //state:listed

        owner = await this.NFTToken.ownerOf(100);
        assert.equal(owner, this.ShardsMarketDelegator.address);
    });

    it('exchangeForWantToken  works', async () => {
        let amount = "1000000000000000000";
        await this.NFTToken.mint(100);
        await this.NFTToken.approve(this.ShardsMarketDelegator.address, 100);

        token721s_1 = [[this.NFTToken.address, 100]];
        await this.ShardsMarketDelegator.createShard(
            token721s_1,
            [],
            "myshard",
            "myshard",
            amount,
            this.MockWETH.address);
        await this.ShardsMarketDelegator.stakeETH(1, { value: amount, from: alex });
        deadlineForRedeem = 604800 + 20;
        await mine(deadlineForRedeem); //skip to  deadlineForRedeem
        await this.ShardsMarketDelegator.settle(1, { from: bob, gas: 6000000 });
        await this.ShardsMarketDelegator.creatorWithdrawWantToken(1, { from: bob });
        await this.ShardsMarketDelegator.usersWithdrawShardToken(1, { from: alex });
        //approve
        var shardPoolInfo = await this.ShardsMarketDelegator.poolInfo.call(1);
        shardInfo = await this.ShardsMarketDelegator.shardInfo.call(1);
        this.ShardToken = await ShardToken.at(shardInfo[2]);
        shardBalance = await this.ShardToken.balanceOf(alex);
        amountNeed = "1111111111111110000";
        await this.MockWETH.deposit({ value: amountNeed, from: alex });
        await this.ShardToken.approve(this.ShardsMarketDelegator.address, shardBalance, { from: alex });
        await this.MockWETH.approve(this.ShardsMarketDelegator.address, amountNeed, { from: alex });

        await this.ShardsMarketDelegator.applyForBuyout(1, amountNeed, { from: alex });
        await this.ShardsMarketDelegator.vote(1, true, { from: bob });

        voteInfo = await this.BuyoutProposalsDelegator.proposals.call(1);

        voteLenth = 259200 + 20
        await mine(voteLenth); //skip to  voteDeadline

        await this.ShardsMarketDelegator.voteResultConfirm(1, { from: alex });
        //approve
        shardBalanceBob = await this.ShardToken.balanceOf(bob);
        await this.ShardToken.approve(this.ShardsMarketDelegator.address, shardBalanceBob, { from: bob });
        await this.ShardsMarketDelegator.exchangeForWantToken(1, shardBalanceBob, { from: bob });
        shardBalanceBob = await this.ShardToken.balanceOf(bob);
        assert.equal(shardBalanceBob, 0);


    });
})