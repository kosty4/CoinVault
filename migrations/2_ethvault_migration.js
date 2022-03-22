var EthVault = artifacts.require("./EthVault.sol");

module.exports = function(deployer) {
    deployer.deploy(EthVault);
};