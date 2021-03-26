const ShardsMarket = artifacts.require('ShardsMarket');
const ShardsFactory = artifacts.require('ShardsFactory');
const WETH = "0xA050886815CFc52a24B9C4aD044ca199990B6690";
const factory = "0xC8DdE00dc855c7126181e25f093822dD5676fee1";
const governance = "0x2E7c4EfdFA6680e34988dcBD70F6a31b4CC28219";
const router = "0x31DB862DF7be09718a860c46ab17CA57966e69ed";
const dev = "0x2E7c4EfdFA6680e34988dcBD70F6a31b4CC28219";
const tokenBar = "0x2E7c4EfdFA6680e34988dcBD70F6a31b4CC28219";
module.exports = function (deployer) {
    // deployer.deploy(ShardsFactory).then(function () {
    //     return deployer.deploy(ShardsMarket, WETH, factory, governance, router, dev, tokenBar, ShardsFactory.address, { gas: 6000000 });
    // });

};

