var ConvertLib = artifacts.require("./DeciEther.sol");

module.exports = function(deployer) {
  deployer.deploy(DeciEther);
};
