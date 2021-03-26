
const NFTToken = artifacts.require('NFTToken');
const MockWETH = artifacts.require('MockWETH');
const MockFactory = artifacts.require('UniswapV2Factory');
const Router = artifacts.require('UniswapV2Router02');
const ShardToken = artifacts.require('ShardToken');
const Pair = artifacts.require('UniswapV2Pair');
const MockERC20Token = artifacts.require('mockERCToken');

const MarketDelegator = artifacts.require('MarketDelegator');
// account address
var account1 = "0x2E7c4EfdFA6680e34988dcBD70F6a31b4CC28219";
var account2 = "0x3734C8fA3A75F21C025E874B9193602bd1414D3a";
var account3 = "0x914B8Cf1eB707c477e9d9Bf5F9E38D85D00Ac329";
var account4 = "0x63079128D91804978921703F67421e62D7246848";
var accountAdmin = "0x2E7c4EfdFA6680e34988dcBD70F6a31b4CC28219";

// contract address
var NFTTokenAddress = "0x8549996Db3EC43558fE051fF63E8382f77EAb37c";
var wantTokenAddress = "0xB5685232b185cAdF7C5F58217722Ac40BC4ec45e";

MarketDelegatorAddress = "0xC3BEdEb79e0e47d171533544dF65739121fb90c6";

// parameter
var tokenId = 31110006;
var poolId = 1;
var proposalId = 1;
var name = "Shard0";
var minPrice = "1000000000000000000";
var stakeAmount1 = "1000000000000000000";
var stakeAmount2 = "2000000000000000000";
var stakeAmount3 = "100000000000000000";
var stakeAmount4 = "200000000000000000";
var stakeAmount5 = "7000000000000000000";
var applyForBuyoutAmount = "200000000000000000000";
function sleep(milliSeconds) {
    var startTime = new Date().getTime();
    console.log("waiting...")
    while (new Date().getTime() < startTime + milliSeconds) {
        //console.log(new Date().getTime());
    }//  10000=1S。
    console.log("time ready!")
}


//0xfEBCE3845Cb04d2C3d3C7724b02a0ddcFe35bc7B
module.exports = async function (callback) {

    this.NFTToken = await NFTToken.at(NFTTokenAddress);
    this.MarketDelegator = await MarketDelegator.at(MarketDelegatorAddress);
    this.MockERC20Token = await MockERC20Token.at(wantTokenAddress);
    this.MarketDelegator.setWhiteListForWantToken(this.MockERC20Token.address, true, { from: bob });
    //  this.MarketDelegator.setWhiteListForWantToken(this.MockWETH.address, true, { from: bob });
    //Staking：
    console.log("Staking：:");
    await this.NFTToken.mint(tokenId, { from: account1 });
    await this.NFTToken.approve(MarketDelegatorAddress, tokenId, { from: account1 });
    var result = await this.MarketDelegator.createShard(NFTTokenAddress, tokenId, name + "0", name + "0", minPrice, wantTokenAddress, { from: account1 });
    console.log("address", result);

    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount1, { from: account2 });
    console.log("approved:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount2, { from: account3 });
    console.log("approved", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount1, { from: account2 });
    console.log("approved", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount2, { from: account3 });
    console.log("approved", result);


    //Staked
    console.log("Staked:");
    tokenId++;
    console.log("tokenId:", tokenId);
    poolId++;
    console.log("poolId:", poolId);
    result = await this.NFTToken.mint(tokenId, { from: account1 });
    console.log("minted:", result);
    result = await this.NFTToken.approve(MarketDelegatorAddress, tokenId, { from: account1 });
    console.log("minted:", result);

    result = await this.MarketDelegator.setDeadlineForRedeem(10, { from: accountAdmin });
    console.log("setDeadlineForRedeem:", result);
    result = await this.MarketDelegator.createShard(NFTTokenAddress, tokenId, name + "1", name + "1", minPrice, wantTokenAddress, { from: account1 });
    console.log("createShard:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount1, { from: account2 });
    console.log("approved:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount2, { from: account3 });
    console.log("approved", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount1, { from: account2 });
    console.log("stake:", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount2, { from: account3 });
    console.log("stake:", result);
    sleep(10000);
    result = await this.MarketDelegator.settle(poolId, { from: account1, gas: 6000000 });
    console.log("settle:", result);

    // Staked failed：
    console.log("Staked failed:");
    tokenId++;
    console.log("tokenId:", tokenId);
    poolId++;
    console.log("poolId:", poolId);

    result = await this.NFTToken.mint(tokenId, { from: account1 });
    console.log("minted:", result);
    result = await this.NFTToken.approve(MarketDelegatorAddress, tokenId, { from: account1 });
    console.log("minted:", result);

    await this.MarketDelegator.setDeadlineForRedeem(10, { from: accountAdmin });
    console.log("setDeadlineForRedeem:", result);
    result = await this.MarketDelegator.createShard(NFTTokenAddress, tokenId, name + "2", name + "2", minPrice, wantTokenAddress, { from: account1 });
    console.log("createShard:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount3, { from: account2 });
    console.log("approved:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount4, { from: account3 });
    console.log("approved", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount3, { from: account2 });
    console.log("stake:", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount4, { from: account3 });
    console.log("stake:", result);
    sleep(10000);
    result = await this.MarketDelegator.settle(poolId, { from: account1, gas: 6000000 });
    console.log("settle:", result);

    result = await this.MarketDelegator.setDeadlineForRedeem(604800, { from: accountAdmin });
    console.log("setDeadlineForRedeem:", result);

    //buyout 
    console.log("buyout state create:");
    tokenId++;
    console.log("tokenId:", tokenId);
    poolId++;
    console.log("poolId:", poolId);
    proposalId++;
    result = await this.NFTToken.mint(tokenId, { from: account1 });
    console.log("minted:", result);
    result = await this.NFTToken.approve(MarketDelegatorAddress, tokenId, { from: account1 });
    console.log("minted:", result);

    await this.MarketDelegator.setDeadlineForRedeem(10, { from: accountAdmin });
    console.log("setDeadlineForRedeem:", result);
    result = await this.MarketDelegator.createShard(NFTTokenAddress, tokenId, name + "3", name + "3", minPrice, wantTokenAddress, { from: account1 });
    console.log("createShard:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount5, { from: account2 });
    console.log("approved:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount1, { from: account3 });
    console.log("approved", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount5, { from: account2 });
    console.log("stake:", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount1, { from: account3 });
    console.log("stake:", result);
    sleep(10000);
    result = await this.MarketDelegator.settle(poolId, { from: account1, gas: 6000000 });
    console.log("settle:", result);
    result = await this.MarketDelegator.creatorWithdrawWantToken(poolId, { from: account1 });
    console.log("creatorWithdrawWantToken:", result);
    result = await this.MarketDelegator.usersWithdrawShardToken(poolId, { from: account2 });
    console.log("usersWithdrawShardToken:", result);


    shardInfo = await this.MarketDelegator.shardInfo.call(poolId);
    console.log("ShardToken:", shardInfo[2]);
    this.ShardToken = await ShardToken.at(shardInfo[2]);
    shardBalance = await this.ShardToken.balanceOf.call(account2);
    console.log("shardBalance:", shardBalance);
    result = await this.ShardToken.approve(this.MarketDelegator.address, shardBalance, { from: account2 });
    console.log("shardBalance:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, applyForBuyoutAmount, { from: account2 });
    console.log("approved", result);
    result = await this.MarketDelegator.applyForBuyout(poolId, applyForBuyoutAmount, { from: account2 });
    console.log("applyForBuyout", result);
    result = await this.MarketDelegator.setDeadlineForRedeem(604800, { from: accountAdmin });
    console.log("setDeadlineForRedeem:", result);
    // buyout failed
    console.log("buyout failed：");
    tokenId++;
    console.log("tokenId:", tokenId);
    poolId++;
    console.log("poolId:", poolId);
    proposalId++;
    result = await this.NFTToken.mint(tokenId, { from: account1 });
    console.log("minted:", result);
    result = await this.NFTToken.approve(MarketDelegatorAddress, tokenId, { from: account1 });
    console.log("minted:", result);

    await this.MarketDelegator.setDeadlineForRedeem(10, { from: accountAdmin });
    console.log("setDeadlineForRedeem:", result);
    result = await this.MarketDelegator.createShard(NFTTokenAddress, tokenId, name + "4", name + "4", minPrice, wantTokenAddress, { from: account1 });
    console.log("createShard:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount5, { from: account2 });
    console.log("approved:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount1, { from: account3 });
    console.log("approved", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount5, { from: account2 });
    console.log("stake:", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount1, { from: account3 });
    console.log("stake:", result);
    sleep(10000);
    result = await this.MarketDelegator.settle(poolId, { from: account1, gas: 6000000 });
    console.log("settle:", result);
    result = await this.MarketDelegator.creatorWithdrawWantToken(poolId, { from: account1 });
    console.log("creatorWithdrawWantToken:", result);
    result = await this.MarketDelegator.usersWithdrawShardToken(poolId, { from: account2 });
    console.log("usersWithdrawShardToken:", result);
    result = await this.MarketDelegator.usersWithdrawShardToken(poolId, { from: account3 });
    console.log("usersWithdrawShardToken:", result);

    shardInfo = await this.MarketDelegator.shardInfo.call(poolId);
    console.log("ShardToken:", shardInfo[2]);
    this.ShardToken = await ShardToken.at(shardInfo[2]);
    shardBalance = await this.ShardToken.balanceOf.call(account2);
    console.log("shardBalance:", shardBalance);
    result = await this.ShardToken.approve(this.MarketDelegator.address, shardBalance, { from: account2 });
    console.log("shardBalance:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, applyForBuyoutAmount, { from: account2 });
    console.log("approved", result);

    result = await this.MarketDelegator.setVoteLenth(15, { from: accountAdmin });
    console.log("setVoteLenth:", result);
    result = await this.MarketDelegator.applyForBuyout(poolId, applyForBuyoutAmount, { from: account2 });
    console.log("applyForBuyout:", result);
    result = await this.MarketDelegator.vote(poolId, false, { from: account3 });
    console.log("vote:", result);
    sleep(11000);
    result = await this.MarketDelegator.voteResultConfirm(poolId);
    console.log("voteResultConfirm:", result);

    //buyout success
    console.log("buyout success:");
    tokenId++;
    console.log("tokenId:", tokenId);
    poolId++;
    console.log("poolId:", poolId);
    proposalId++;
    result = await this.NFTToken.mint(tokenId, { from: account1 });
    console.log("minted:", result);
    result = await this.NFTToken.approve(MarketDelegatorAddress, tokenId, { from: account1 });
    console.log("minted:", result);

    await this.MarketDelegator.setDeadlineForRedeem(10, { from: accountAdmin });
    console.log("setDeadlineForRedeem:", result);
    result = await this.MarketDelegator.createShard(NFTTokenAddress, tokenId, name + "5", name + "5", minPrice, wantTokenAddress, { from: account1 });
    console.log("createShard:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount5, { from: account2 });
    console.log("approved:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, stakeAmount1, { from: account3 });
    console.log("approved", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount5, { from: account2 });
    console.log("stake:", result);
    result = await this.MarketDelegator.stake(poolId, stakeAmount1, { from: account3 });
    console.log("stake:", result);
    sleep(10000);
    result = await this.MarketDelegator.settle(poolId, { from: account1, gas: 6000000 });
    console.log("settle:", result);
    result = await this.MarketDelegator.creatorWithdrawWantToken(poolId, { from: account1 });
    console.log("creatorWithdrawWantToken:", result);
    result = await this.MarketDelegator.usersWithdrawShardToken(poolId, { from: account2 });
    console.log("usersWithdrawShardToken:", result);
    result = await this.MarketDelegator.usersWithdrawShardToken(poolId, { from: account3 });
    console.log("usersWithdrawShardToken:", result);

    shardInfo = await this.MarketDelegator.shardInfo.call(poolId);
    console.log("ShardToken:", shardInfo[2]);
    this.ShardToken = await ShardToken.at(shardInfo[2]);
    shardBalance = await this.ShardToken.balanceOf.call(account2);
    console.log("shardBalance:", shardBalance);
    result = await this.ShardToken.approve(this.MarketDelegator.address, shardBalance, { from: account2 });
    console.log("shardBalance:", result);
    result = await this.MockERC20Token.approve(MarketDelegatorAddress, applyForBuyoutAmount, { from: account2 });
    console.log("approved", result);

    result = await this.MarketDelegator.setVoteLenth(15, { from: accountAdmin });
    console.log("setVoteLenth:", result);
    result = await this.MarketDelegator.applyForBuyout(poolId, applyForBuyoutAmount, { from: account2 });
    console.log("applyForBuyout:", result);
    result = await this.MarketDelegator.vote(poolId, true, { from: account3 });
    console.log("vote:", result);
    sleep(11000);
    result = await this.MarketDelegator.voteResultConfirm(poolId);
    console.log("voteResultConfirm:", result);


    console.log("State create completed！");
}