pragma solidity ^0.4.18;


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
      // assert(b > 0); // Solidity automatically throws when dividing by 0
      uint256 c = a / b;
      // assert(a == b * c + a % b); // There is no case in which this doesn't hold
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

contract BETR_TOKEN {
    using SafeMath for uint256;

    string public constant name = "Better Betting";
    string public symbol = "BETR";
    uint256 public constant decimals = 18;

    uint256 public hardCap; // total supply => hard cap
    uint256 public totalSupply; // adpative supply => current cap
    uint256 public fee; // collected fee counter

    address public service; // reference to service contract for transaction and authorization
    address public owner; // reference to the contract creator
    address public mobs; // reference to the third party ico backoffice provider

    bool public icoActive;
    uint256 public icoDuration = 30 days;
    uint256 public icoStartTime;

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed; // third party authorisations for token transfering

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function BETR_TOKEN(uint256 _hardCap, address _mobs) public {
        hardCap = _hardCap * (10 ** decimals);
        owner = msg.sender;
        mobs = _mobs;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyMobs {
        require(msg.sender == mobs);
        _;
    }

    modifier onlyService {
        require(msg.sender == service);
        _;
    }

    modifier icoRunning {
        require(icoActive && block.timestamp < icoStartTime + icoDuration);
        _;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(
            _to != address(0) &&
            balances[msg.sender] >= _value &&
            balances[_to] + _value > balances[_to]
        );
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function reward(address _to, uint256 _value, uint256 _fee) external onlyService returns(bool) {
        require(
            _to != address(0) &&
            _value > 0
        );
        if(_fee > 0) {
            totalSupply = totalSupply.sub(_fee);
            fee = fee.add(_fee);
        }
        require(transfer(_to, _value));
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require (
          _from != address(0) &&
          _to != address(0) &&
          balances[_from] >= _value &&
          allowed[_from][msg.sender] >= _value &&
          balances[_to] + _value > balances[_to]
        );
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0));
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function takeBet(uint256 _id, uint256 _value) external returns (bool success) {
        require(
          _value > 0 &&
          transfer(service, _value) &&
          service.call(bytes4(bytes32(keccak256("betHandler(uint256,address,uint256)"))), _id, msg.sender, _value)
        );
        return true;
    }

    function mint(address _investor, uint256 _tokensAmount) public onlyMobs icoRunning returns(bool) {
        uint256 newSupply = totalSupply.add(_tokensAmount);
        require(
            _investor != address(0) &&
            _tokensAmount > 0 &&
             newSupply < hardCap
        );
        balances[_investor] = balances[_investor].add(_tokensAmount);
        totalSupply = newSupply;
        Transfer(0x0, _investor, newSupply);
        return true;
    }

    function reserveTokensGroup(address[] _investors, uint256[] _tokensAmounts) external onlyOwner {
        require(_investors.length == _tokensAmounts.length);
        uint256 newSupply;
        for(uint8 i = 0; i < _investors.length; i++){
            newSupply = totalSupply.add(_tokensAmounts[i].mul(10 ** decimals));
            require(
                _investors[i] != address(0) &&
                _tokensAmounts[i] > 0 &&
                newSupply < hardCap
            );
            balances[_investors[i]] = balances[_investors[i]].add(_tokensAmounts[i].mul(10 ** decimals));
            totalSupply = newSupply;
            Transfer(0x0, _investors[i], newSupply);
        }
    }

    function reserveTokens(address _investor, uint256 _tokensAmount) external onlyOwner {
        uint256 newSupply = totalSupply.add(_tokensAmount.mul(10 ** decimals));
        require(
            _investor != address(0) &&
            _tokensAmount > 0 &&
            newSupply < hardCap
        );
        balances[_investor] = balances[_investor].add(_tokensAmount.mul(10 ** decimals));
        totalSupply = newSupply;
        Transfer(0x0, _investor, newSupply);
    }

    function collectFee() external onlyOwner {
      require(fee > 0);
      balances[owner] = balances[owner].add(fee);
      totalSupply = totalSupply.add(fee);
      fee = 0;
      Transfer(0x0, owner, hardCap);
    }

    function startIco() external onlyOwner {
        icoActive = true;
        if(icoStartTime == 0) icoStartTime = block.timestamp;
    }

    function stopIco() external onlyOwner {
        icoActive = false;
    }

    function inflate(uint256 _value) external onlyOwner {
        hardCap = hardCap.add(_value);
    }

    function deflate(uint256 _value) external onlyOwner {
        hardCap = hardCap.sub(_value);
    }

    function setService(address _service) external onlyOwner {
        service = _service;
    }

    function setMobs(address _mobs) external onlyOwner {
        mobs = _mobs;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowed[_owner][_spender];
    }
}
