pragma solidity ^0.4.26;

import "./Owned.sol";
import "./MoveToken.sol";
import "./ERC20Token.sol";

contract SynthAssets is ERC20Token {
    using SafeMath for uint256;

    //mint & burn event
    event Mint(address indexed to, uint256 indexed amount, uint256 indexed locked);
    event Burn(address indexed from, uint256 indexed amount, uint256 indexed unlocked);
    event ChangeRate(uint256 indexed oldRate, uint256 indexed newRate);

    uint256 public mintingRate;
    uint256 public rateDecimals;

    Move private _erc20Token;

    //locked amount
    mapping(address => uint256) public lockedToken;

    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(address _issuer, address moveToken, string _name, string _symbol, uint8 _decimals, uint256 _rateDecimals) public Owned(_issuer){
        _erc20Token = Move(moveToken);

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        totalSupply = uint256(0);
        balances[_issuer] = uint256(0);

        mintingRate = 0;
        rateDecimals = 10 ** _rateDecimals;
    }

    /**
     * @dev synthetic assets minting rate setting up
     * @param newRate The minting rate.
     */
    function setMintingRate(uint256 newRate) onlyOwner public {
        require(newRate != 0);
        require(mintingRate != newRate);

        emit ChangeRate(mintingRate, newRate);

        mintingRate = newRate;
    }

    /**
     * @dev This method will lock token to mint synthetic assets
     * @param _amount The amount of synthetic assets you want to mint.
     */
    function mint(uint256 _amount) public {
        address user = msg.sender;

        //check rate
        require(mintingRate != 0);

        //check user balance
        uint256 userBalance = _erc20Token.balanceOf(user);
        uint256 tokenCost = _amount.mul(mintingRate);
        tokenCost = tokenCost.div(rateDecimals);

        require(tokenCost <= userBalance);

        //transfer from user balance to this contract
        _erc20Token.transferFrom(user, address(this), tokenCost);

        //record user cost to balance map
        lockedToken[user] = lockedToken[user].add(tokenCost);

        //mint synthetic assets to user
        _mintAssets(user, _amount, tokenCost);
    }


    /**
     * @dev This method will burn synthetic assets to redeem token
     * @param _erc20Amount The amount of tokens you want to redeem.
     */
    function redeem(uint256 _erc20Amount) public {
        address user = msg.sender;

        //check rate
        require(mintingRate != 0);

        //check internal balance
        uint256 tokenBalance = lockedToken[user];
        require(tokenBalance >= _erc20Amount, "too greed");

        //check synthetic assets balance
        uint256 synBalance = balanceOf(user);
        uint256 synBurnAmount = _erc20Amount.mul(rateDecimals);
        synBurnAmount = synBurnAmount.div(mintingRate);

        require(synBalance >= synBurnAmount, "insufficient synthetic assets balance");

        //burn and unlock the balance
        _burnAssets(user, synBurnAmount, _erc20Amount);

        _erc20Token.transfer(user, _erc20Amount);
        lockedToken[user] = lockedToken[user].sub(_erc20Amount);
    }


    /**
     * @dev mint synthetic token.
     * @param _to The address which assets mint to.
     * @param _amount The synthetic token mint amount.
     */
    function _mintAssets(address _to, uint256 _amount, uint256 _locked) private returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);

        emit Mint(_to, _amount, _locked);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
     * @dev Burn synthetic token when address redeem token.
     * @param _from The address which assets mint to.
     * @param _amount The synthetic token mint amount.
     */
    function _burnAssets(address _from, uint256 _amount, uint256 _unlocked) private returns (bool) {
        balances[_from] = balances[_from].sub(_amount);
        totalSupply = totalSupply.sub(_amount);

        emit Burn(_from, _amount, _unlocked);
        emit Transfer(_from, address(0), _amount);

        return true;
    }
}
