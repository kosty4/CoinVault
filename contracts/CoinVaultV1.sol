// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract CoinVault {

    /// @title A smart contract for locking tokens in time
    /// @custom:experimental This is an experimental contract.

    using SafeERC20 for IERC20;

    address private creator;

    mapping(address => uint8) public tokenIDtoAddress; 
    uint8 public noOfSupportedTokens;


    // struct TokenStorage {
    //     uint ballance;
    //     // uint released;
    //     bool withdrawed;
    // }

    struct Vault {
        uint uid;
        uint maturity;
        uint256 nativeBallance;
        // uint released;
        bool withdrawed;
        string name;
    }
    
    mapping(address => Vault[]) private vaults;
    uint private noOfUniqueVaults;

    //vaultID => tokenID => ballances
    mapping(uint => mapping(uint8 => uint)) private vaultIDtoTokenBallance;

    constructor() {
        creator = msg.sender;
        noOfSupportedTokens = 0;
        tokenIDtoAddress[0x0000000000000000000000000000000000000000] = 0; //unexisting address
    }

    //@notice A function to make the contract creator add compatibility with new tokens, max 256 tokens (overflow)
    function addNewTokenCompatibility(address tokenAddress) public returns (uint){
        require(msg.sender == creator, 'Only creator can add new token support');
        
        noOfSupportedTokens+=1;
        tokenIDtoAddress[tokenAddress] = noOfSupportedTokens;

        return noOfSupportedTokens;
    }
    //@notice A function to create a new vault for the user
    function createNewVault(uint timeToMaturity, string memory name) external {
        require(timeToMaturity > 0, 'please set time to maturity');
        require(bytes(name).length != 0 , 'name cant be empty');

        Vault memory newVault = Vault({
            uid: noOfUniqueVaults,
            nativeBallance: 0,
            maturity: block.timestamp + timeToMaturity,
            withdrawed: false,
            name: name
        });

        vaults[msg.sender].push(  newVault );

        noOfUniqueVaults+=1;
    }

    //@notice checks if users vault exists with specified id and is ready to accept funds
    modifier depositable(uint _userVaultID) {
        require(vaults[msg.sender][_userVaultID].maturity > block.timestamp, 'cant deposit to unexistant or matured vault');
        // require(vaults[msg.sender][_userVaultID].withdrawed == false, 'cant deposit to withdrawn vault');
        _ ; //calls the rest of the function...
    }


    //@notice a function to add a native token to vault
    function depositNative(uint _userVaultID) external payable depositable(_userVaultID)  {

        Vault storage owner = vaults[msg.sender][_userVaultID];
        owner.nativeBallance += msg.value;
    }

    //@notice a function to a supported token to the vault
    //the spender needs to approve that he allows the token smart contract to withdraw his tokens to the vault
    function depositToken(uint _userVaultID, address tokenAddress, uint256 amount) external depositable(_userVaultID) {

        uint8 currentTokenId = tokenIDtoAddress[tokenAddress]; // in memory as declared localy
        require(currentTokenId > 0, 'cant deposit a token not suported by vault'); //should give 0 if the token is not supported
        
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), amount); 

        Vault storage owner = vaults[msg.sender][_userVaultID];

        uint cballance = vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ];

        vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ] = cballance + amount;
    }


    function withdrawNative(uint vaultID) external {
        Vault storage owner = vaults[msg.sender][vaultID];

        require(owner.nativeBallance > 0, 'Owner does not have ballance');
        require(owner.maturity <= block.timestamp, 'withdrawal too early');
        // require(owner.withdrawed == false, 'Paid out already');

        payable(msg.sender).transfer(owner.nativeBallance);

        owner.nativeBallance = 0;
        owner.withdrawed = true;

    }
    
    function withdrawToken(uint vaultID, address tokenAddress) external {
        Vault storage owner = vaults[msg.sender][vaultID];

        require(owner.maturity <= block.timestamp, 'withdrawal too early');

        uint8 contractTokenID = tokenIDtoAddress[tokenAddress]; //get the ix of token id encoded in the contrat

        require(contractTokenID > 0, 'Cant withdraw uncompatible token');

        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ] > 0, 'There is no ballance for this token');
        
        IERC20 token = IERC20(tokenAddress);

        token.safeTransfer(msg.sender, vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ] );
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ] = 0; //empty the token ballance
    }


    //returns all vaults belonging to a user
    function getUserVaults() public view returns(Vault[] memory){
        require(vaults[msg.sender].length > 0, 'user does not have vaults');
        return vaults[msg.sender];
    }

    //a getter for token ballances, given a vault
    function getTokenBallanceInVault(uint vaultID, uint8 TokenID) public view returns (uint){
        return vaultIDtoTokenBallance[vaultID][TokenID];
    }


}
