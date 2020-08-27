pragma solidity ^0.4.26;

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface  IERC20 {
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b > 0);
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


contract Owned {
    address public owner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor(address _owner) public {
        owner = _owner;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _owner) onlyOwner public {
        require(_owner != address(0));
        owner = _owner;

        emit OwnershipTransferred(owner, _owner);
    }
}


contract ERC20Token is IERC20, Owned {
    using SafeMath for uint256;
    uint256 public totalSupply;

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;


    // True if transfers are allowed
    bool public transferable = true;

    modifier canTransfer() {
        require(transferable == true);
        _;
    }

    function setTransferable(bool _transferable) onlyOwner public {
        transferable = _transferable;
    }

    /**
     * @dev transfer token for a specified address
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(address _to, uint256 _value) canTransfer public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address _from, address _to, uint256 _value) canTransfer public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    // Allow `_spender` to withdraw from your account, multiple times.
    function approve(address _spender, uint _value) public returns (bool success) {
        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) {
            revert();
        }
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function () external payable {
        revert();
    }
}


contract Move is ERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 private constant DECIMALS = 18;
    uint256 private constant TOTAL_SUPPLY = 10 * 10**8 * 10**DECIMALS;

    /**
     * @param _issuer The address of the owner.
     */
    constructor(address _issuer) public Owned(_issuer){
        name = "Move Defi Test";
        symbol = "MOVE-T";
        decimals = uint8(DECIMALS);
        totalSupply = TOTAL_SUPPLY;
        balances[_issuer] = TOTAL_SUPPLY;
        emit Transfer(address(0), _issuer, TOTAL_SUPPLY);
    }
}


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
