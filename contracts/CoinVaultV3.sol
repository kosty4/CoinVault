// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {DataTypes} from "./DataTypes.sol";

import { IPoolAddressesProvider } from "./IPoolAddressesProvider.sol";
import { IPool } from "./IPool.sol";

contract CoinVault {

    /// @title A smart contract for time-locking tokens, with possibility of lending. 
    /// @custom:experimental This is an experimental contract. needs to be peer reviewed. 

    using SafeERC20 for IERC20;

    address private creator;

    mapping(address => uint8) public tokenAddressToID; 
    uint8 public noOfSupportedTokens;


    IPoolAddressesProvider public poolAddressProvider;

    //TODO Events
    // event LogVaultTokenToBallance(uint8 tokenID, uint ballance);
    // event NewVaultCreated();
    // event Deposited(uint vaultIX, uint y, uint result);
    // event Withdrawn()

    struct TokenStorage {
        uint ballance;
        bool active;
        bool lent;
    }

    struct Vault {
        uint uid;
        uint maturity;
        uint256 nativeBallance;
        bool active;
        string name;
    }
    
    mapping(address => Vault[]) private vaults;

    //vaultID => tokenID => Token
    mapping(uint => mapping(uint8 => TokenStorage)) private vaultIDtoTokenBallance;
    
    //helper for rewards withdrawal
    mapping(address => uint) private totalLentBallances; 
    
    uint private noOfUniqueVaults;

    constructor() {
        creator = msg.sender;
        // Polygon Mumbai Aave V3
        // https://docs.aave.com/developers/deployed-contracts/v3-testnet-addresses
        poolAddressProvider = IPoolAddressesProvider(0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6);
        noOfSupportedTokens = 0;
        tokenAddressToID[0x0000000000000000000000000000000000000000] = 0; //unexisting address
    }
    
    //@notice checks if vault exists for a user (with index) and is ready to accept funds
    modifier depositable(uint _userVaultIX) {
        require(vaults[msg.sender][_userVaultIX].maturity > block.timestamp, 'cant deposit to unexistant or matured vault');
        _ ; //calls the rest of the function...
    }


    //@notice A function to make the contract creator add compatibility with new tokens, max 256 tokens (overflow)
    function addNewTokenCompatibility(address tokenAddress) public returns (uint){
        require(msg.sender == creator, 'Only creator can add new token support');
        require(tokenAddressToID[tokenAddress] == 0, 'Token with such address is already compatible');
        
        noOfSupportedTokens+=1;
        tokenAddressToID[tokenAddress] = noOfSupportedTokens;

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

    //@notice a function to add a native token to vault
    function depositNative(uint _userVaultIX) external payable depositable(_userVaultIX)  {

        Vault storage owner = vaults[msg.sender][_userVaultIX];
        owner.nativeBallance += msg.value;
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

    //@notice a function to deposit a token to the vault
    //the spender needs to approve that he allows the token smart contract to withdraw his tokens to the vault
    function depositToken(uint _userVaultIX, address tokenAddress, uint256 amount) external depositable(_userVaultIX) {

        uint8 currentTokenId = tokenAddressToID[tokenAddress]; // in memory as declared localy
        require(currentTokenId > 0, 'cant deposit a token not suported by vault'); //should give 0 if the token is not supported
        
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), amount); 

        Vault storage owner = vaults[msg.sender][_userVaultIX];

        if (vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].active && !vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].lent){
            vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].ballance += amount;
        }
        else {

            TokenStorage memory tokenstorage = TokenStorage({
                ballance: amount,
                active: true,
                lent: false
            });

            vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ] = tokenstorage;
        }
    }

    //@notice a function to withdraw a token in an unlocked vault
    function withdrawToken(uint _userVaultIX, address tokenAddress) external {
        Vault storage owner = vaults[msg.sender][_userVaultIX];

        require(owner.maturity <= block.timestamp, 'withdrawal too early');

        uint8 contractTokenID = tokenAddressToID[tokenAddress]; //get the ix of token id encoded in the contrat
        require(contractTokenID > 0, 'Cant withdraw uncompatible token');

        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active == true, 'There is no ballance for this token');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance > 0, 'There is no ballance for this token');
        
        IERC20 token = IERC20(tokenAddress);

        token.safeTransfer(msg.sender, vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance );
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance = 0; //empty the token ballance
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active = false; //for block time manipulation attacks
    }


    //@notice a function to deposit a token to the vault and directly lend it to aave
    //the spender needs to approve that he allows the token smart contract to withdraw his tokens to the vault
    function depositTokenWithLending(uint _userVaultIX, address tokenAddress, uint256 amount) external depositable(_userVaultIX) {

        uint8 currentTokenId = tokenAddressToID[tokenAddress]; // in memory as declared localy
        require(currentTokenId > 0, 'cant deposit a token not suported by vault'); //should give 0 if the token is not supported
        
        IERC20 token = IERC20(tokenAddress);
        
        token.safeTransferFrom(msg.sender, address(this), amount); 

        //supply
        address lendingPoolAddress = poolAddressProvider.getPool();
        token.safeApprove(lendingPoolAddress, amount);

        IPool aaveLendingPool = IPool(lendingPoolAddress);


        //track the ammount of supplied tokens 
        aaveLendingPool.supply(tokenAddress, amount, address(this), 0);

        Vault storage owner = vaults[msg.sender][_userVaultIX];

        //update the mapping
        if (vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].active && vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].lent){
            vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ].ballance += amount;
        }
        else {

            TokenStorage memory tokenstorage = TokenStorage({
                ballance: amount,
                active: true,
                lent: true
            });

            vaultIDtoTokenBallance[ owner.uid ][ currentTokenId ] = tokenstorage;
        }

        totalLentBallances[tokenAddress] += amount;
    }
    
    //@notice a function to withdraw the lent tokens from aave directly to users wallet, if vault is matured
    function withdrawTokenFromLending(uint _userVaultIX, address tokenAddress) external {
        Vault storage owner = vaults[msg.sender][_userVaultIX];

        require(owner.maturity <= block.timestamp, 'withdrawal too early');

        uint8 contractTokenID = tokenAddressToID[tokenAddress]; //get the ix of token id encoded in the contrat
        require(contractTokenID > 0, 'Cant withdraw uncompatible token');

        
        uint256 amount = vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance;

        require(amount > 0, 'There is no ballance for this token');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active == true, 'token deposit disabled due to expiration');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].lent == true, 'This asset is not lent');
        
        address lendingPoolAddress = poolAddressProvider.getPool();

        IPool aaveLendingPool = IPool(lendingPoolAddress);
        address aTokenAddress = aaveLendingPool.getReserveData(tokenAddress).aTokenAddress;

        IERC20 aTokenContract = IERC20(aTokenAddress);

        uint aTokenBallance = aTokenContract.balanceOf(address(this));
        uint lentTotalballance = totalLentBallances[tokenAddress];

        //calculate the value of amount+rewards to proportion of the ballance.
        uint scaledAmount = (aTokenBallance * amount) / lentTotalballance;
        
        // Withdraw from the LendingPool
        aaveLendingPool.withdraw(tokenAddress, scaledAmount, msg.sender);

        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance = 0; //empty the token ballance
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active = false; //for block time manipulation attacks
        
        totalLentBallances[tokenAddress] -= amount;
    }

    //lends a token that is locked inside a vault
    function lendLockedToken(uint _userVaultIX, address tokenAddress) external {

        Vault storage owner = vaults[msg.sender][_userVaultIX];

        uint8 contractTokenID = tokenAddressToID[tokenAddress]; //get the ix of token id encoded in the contrat
        require(contractTokenID > 0, 'Cant withdraw uncompatible token');
        
        uint256 amount = vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance;

        require(amount > 0, 'There is no ballance for this token');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active == true, 'not active');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].lent == false, 'this token in this vault is already lent');
        
        IERC20 token = IERC20(tokenAddress);

        //supply
        address lendingPoolAddress = poolAddressProvider.getPool();
        token.safeApprove(lendingPoolAddress, amount);
        IPool aaveLendingPool = IPool(lendingPoolAddress);
        aaveLendingPool.supply(tokenAddress, amount, address(this), 0);

        //update the mapping
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].lent = true;

        totalLentBallances[tokenAddress] += amount;
    }   

    //un-lend a token locked in a vault back to this original token with rewards
    function redeemLockedToken(uint _userVaultIX, address tokenAddress) external {

        Vault storage owner = vaults[msg.sender][_userVaultIX];

        uint8 contractTokenID = tokenAddressToID[tokenAddress]; //get the ix of token id encoded in the contrat
        require(contractTokenID > 0, 'Cant convert uncompatible token');
        
        uint256 amount = vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance;

        require(amount > 0, 'There is no ballance for this token');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].active == true, 'token deposit disabled due to expiration');
        require(vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].lent == true, 'This asset is not lent');
        
        address lendingPoolAddress = poolAddressProvider.getPool();
        IPool aaveLendingPool = IPool(lendingPoolAddress);
        address aTokenAddress = aaveLendingPool.getReserveData(tokenAddress).aTokenAddress;

        IERC20 aTokenContract = IERC20(aTokenAddress);

        uint aTokenBallance = aTokenContract.balanceOf(address(this));
        uint lentTotalballance = totalLentBallances[tokenAddress];

        //calculate the value of amount+rewards to proportion of the ballance.
        uint scaledAmount = (aTokenBallance * amount) / lentTotalballance;
        
        // Withdraw from pool to this contract
        aaveLendingPool.withdraw(tokenAddress, scaledAmount, address(this));

        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].ballance = scaledAmount;
        vaultIDtoTokenBallance[ owner.uid ][ contractTokenID ].lent = false;
        
        totalLentBallances[tokenAddress] -= amount;
    }   

    //returns all vaults belonging to a user
    function getUserVaults() public view returns(Vault[] memory){
        require(vaults[msg.sender].length > 0, 'user does not have vaults');
        return vaults[msg.sender];
    }

    //a getter for token ballances and lending status, given a vault
    function getBallanceInVault(uint vaultID, uint8 TokenID) public view returns (uint , bool){
        return (vaultIDtoTokenBallance[vaultID][TokenID].ballance, vaultIDtoTokenBallance[vaultID][TokenID].lent);
    }

}
