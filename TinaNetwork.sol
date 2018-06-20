pragma solidity ^0.4.21;

contract Owner {
    address public owner;
    
    function Owner(address _owner) public {
        owner = _owner;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

// interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract Ring is Owner {
    string  public name;
    string  public symbol;
    uint8   public decimals = 18;
    uint256 public totalSupply;
    uint256 public price;           // Tokens per 1ETH
    address public walletAddress;   // wallet to receive ETH
    
    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function Ring(uint256 _totalSupply, string _tokenName, string _tokenSymbol, uint256 _price, address _walletAddr) public {
        require(_walletAddr != address(0));
        require(_totalSupply > 0);
        require(_price > 0);
        
        totalSupply             = _totalSupply * 10 ** uint256(decimals);    // Update total supply with the decimal amount
        name                    = _tokenName;                                // Set the name for display purposes
        symbol                  = _tokenSymbol;                              // Set the symbol for display purposes
        price                   = _price;                                    // Set the ICO price
        walletAddress           = _walletAddr;                               // Set the wallet address to receive ETH
    }
  
    mapping(address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowance;
    mapping (address => bool) public frozenAccount;

    event Approval(address indexed owner, address indexed spender, uint256 value);      // ERC20 standard event
    event Transfer(address indexed from, address indexed to, uint256 value);            // ERC20 standard event
    event IssueTokens(address investorAddress, uint256 amount, uint256 tokenAmount);    // Issue tokens to investor
    event FrozenFunds(address target, bool frozen);     // Frozen Funds from investor
    event Burn(address indexed from, uint256 value);    // This notifies clients about the amount burnt
    
    // Fallback function for token purchasing  
    function () public payable {
        issueTokens();
    }
    
    // ERC20 standard function
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balances[msg.sender] >= _value);            // Check if the sender has enough
        require(balances[_to] + _value >= balances[_to]);   // Check for overflows
        
        balances[msg.sender]    -= _value;                  // Subtract from the sender
        balances[_to]           += _value;                  // Add the same to the recipient
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // ERC20 standard function
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0));
        require(_from != address(0));
        require(_value > 0);
        require(_value <= allowance[_from][msg.sender]);        // Check allowance
        require (_to != 0x0);                                   // Prevent transfer to 0x0 address. Use burn() instead
        require (balances[_from] >= _value);                    // Check if the sender has enough
        require (balances[_to] + _value >= balances[_to]);      // Check for overflows
        require(!frozenAccount[_from]);                         // Check if sender is frozen
        require(!frozenAccount[_to]);                           // Check if recipient is frozen

        allowance[_from][msg.sender]    -= _value;
        
        balances[_from]                 -= _value;
        balances[_to]                   += _value;
        
        emit Transfer(_from, _to, _value);
        return true;
    }

    // ERC20 standard function
    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0));
        require(_value > 0);
		
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // ERC20 standard function
    function allowance(address _owner, address _spender) public constant returns (uint256) {
        return allowance[_owner][_spender];
    }

    // ERC20 standard function
    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];
    }
    
    function freezeAccount(address target, bool freeze) onlyOwner public {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }
    
    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);   // Check if the sender has enough
        
        balances[msg.sender] -= _value;            // Subtract from the sender
        totalSupply -= _value;                      // Updates totalSupply
        
        emit Burn(msg.sender, _value);
        return true;
    }
    
    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balances[_from] >= _value);                 // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        
        balances[_from]                 -= _value;           // Subtract from the targeted balance
        allowance[_from][msg.sender]    -= _value;          // Subtract from the sender's allowance
        totalSupply                     -= _value;          // Update totalSupply
        
        emit Burn(_from, _value);
        return true;
    }

    // Issue tokens to investors and transfer ether to wallet
    function issueTokens() private {
        require(walletAddress != address(0));
        walletAddress.transfer(msg.value);
        
        uint256 tokenAmount         = msg.value * price * 10 ** uint256(decimals);
        balances[msg.sender]        += tokenAmount;
        emit IssueTokens(msg.sender, msg.value, tokenAmount);
    }
}
