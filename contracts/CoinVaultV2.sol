// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract CoinVault {

    /// @title A smart contract for locking tokens
    /// @custom:experimental This is an experimental contract.

    using SafeERC20 for IERC20;

    address private creator;

    mapping(address => uint8) public tokenIDtoAddress; 
    uint8 public noOfSupportedTokens;

    event LogVaultTokenToBallance(uint8 tokenID, uint ballance);


    struct TokenStorage {
        uint ballance;
        bool active;
    }

    struct Vault {
        uint uid;
        uint maturity;
        uint256 nativeBallance;
        bool active;
        string name;
    }
    
    mapping(address => Vault[]) private vaults;
    uint private noOfUniqueVaults;

    //vaultID => tokenID => Token
    mapping(uint => mapping(uint8 => TokenStorage)) private vaultIDtoTokenBallance;

    constructor() {
        creator = msg.sender;
        noOfSupportedTokens = 0;
        tokenIDtoAddress[0x0000000000000000000000000000000000000000] = 0; //unexisting address
    }

    //@notice A function to make the contract creator add compatibility with new tokens, max 256 tokens (overflow)
    function addNewTokenCompatibility(address tokenAddress) public returns (uint){
        require(msg.sender == creator, 'Only creator can add new token support');
        require(tokenIDtoAddress[tokenAddress] == 0, 'Token with such address is already compatible');
        
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
            active: true,
            name: name
        });

        vaults[msg.sender].push(  newVault );

        noOfUniqueVaults+=1;
    }

    //@notice checks if users vault exists with specified id and is ready to accept funds
    modifier depositable(uint _userVaultIX) {
        require(vaults[msg.sender][_userVaultIX].maturity > block.timestamp, 'cant deposit to unexistant or matured vault');
        _ ; //calls the rest of the function...
    }

    //@notice a function to add a native token to vault
    function depositNative(uint _userVaultIX) external payable depositable(_userVaultIX)  {

        Vault storage owner = vaults[msg.sender][_userVaultIX];
        owner.nativeBallance += msg.value;
    }

    //@notice a function to a supported token to the vault
    //the spender needs to approve that he allows the token smart contract to withdraw his tokens to the vault
    function depositToken(uint _userVaultIX, address tokenAddress, uint256 amount) external depositable(_userVaultIX) {

        uint8 currentTokenId = tokenIDtoAddress[tokenAddress]; // in memory as declared localy
        require(currentTokenId > 0, 'cant deposit a token not suported by vault'); //should give 0 if the token is not supported
        
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), amount); 

        Vault storage owner = vaults[msg.sender][_userVaultIX];

        if (vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].active){
            // uint cballance = vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].ballance;
            vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].ballance += amount;
        }
        else {

            TokenStorage memory tokenstorage = TokenStorage({
                ballance: amount,
                active: true
            });

            vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ] = tokenstorage;
        }
    }


    function withdrawNative(uint _userVaultIX) external {
        Vault storage owner = vaults[msg.sender][_userVaultIX];

        require(owner.nativeBallance > 0, 'Owner does not have ballance');
        require(owner.maturity <= block.timestamp, 'withdrawal too early');
        require(owner.active == true, 'Paid out already');

        payable(msg.sender).transfer(owner.nativeBallance);

        owner.nativeBallance = 0;
        owner.active = false;
    }
    
    function withdrawToken(uint _userVaultIX, address tokenAddress) external {
        Vault storage owner = vaults[msg.sender][_userVaultIX];

        require(owner.maturity <= block.timestamp, 'withdrawal too early');

        uint8 contractTokenID = tokenIDtoAddress[tokenAddress]; //get the ix of token id encoded in the contrat
        require(contractTokenID > 0, 'Cant withdraw uncompatible token');

        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active == true, 'There is no ballance for this token');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance > 0, 'There is no ballance for this token');
        
        IERC20 token = IERC20(tokenAddress);

        token.safeTransfer(msg.sender, vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance );
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance = 0; //empty the token ballance
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active = false; //for block time manipulation attacks
    }


    //returns all vaults belonging to a user
    function getUserVaults() public view returns(Vault[] memory){
        require(vaults[msg.sender].length > 0, 'user does not have vaults');
        return vaults[msg.sender];
    }

    //a getter for token ballances, given a vault
    function getTokenBallanceInVault(uint vaultID, uint8 TokenID) public view returns (uint){
        return vaultIDtoTokenBallance[vaultID][TokenID].ballance;
    }
}
