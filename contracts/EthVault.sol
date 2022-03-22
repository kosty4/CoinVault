// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EthVault {
    
    struct Vault {
        uint256 amount;
        uint maturity;
        bool active;
        bool withdrawed;
        string name;
    }

    mapping(address => Vault[]) private vaults;
    mapping(address => uint) private noOfVaults;

    // mapping(address => mapping(uint => Vault)) addressToVaultID;

    function createNewVault(uint timeToMaturity, string memory name) external {
        require(vaults[msg.sender].length < 5, 'you already have 5 vaults');
        require(timeToMaturity > 0, 'please set time to maturity');
        require(bytes(name).length != 0 , 'name cant be empty');

        vaults[msg.sender].push(  Vault(0, block.timestamp + timeToMaturity, true, false, name) );
        noOfVaults[msg.sender]+=1;
    }

    function addToVault(uint id) external payable {
        //msg.value > 0?
        require(vaults[msg.sender][id].maturity > 0, 'cant deposit to unexistant vault');
        require(vaults[msg.sender][id].active == true, 'cant deposit to withdrawn vault');
        Vault storage owner = vaults[msg.sender][id];
        owner.amount += msg.value;
    }
    
    function withdrawFromVault(uint id) external {
        Vault storage owner = vaults[msg.sender][id];

        require(owner.amount > 0, 'Owner does not have ballance');
        require(owner.maturity <= block.timestamp, 'withdrawal too early');
        require(owner.withdrawed == false, 'Paid out already');

        payable(msg.sender).transfer(owner.amount);

        owner.amount = 0;
        owner.withdrawed = true;
        owner.active = false;
    }

    function get() public view returns(Vault[] memory){
        require(noOfVaults[msg.sender] > 0);
        return vaults[msg.sender];
    }

}
