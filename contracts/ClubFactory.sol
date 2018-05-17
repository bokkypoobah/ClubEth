pragma solidity ^0.4.23;

// ----------------------------------------------------------------------------
// Babysitters Club DApp Project
//
// https://github.com/bokkypoobah/DecentralisedFutureFundDAO
//
// Enjoy.
//
// (c) BokkyPooBah / Bok Consulting Pty Ltd and
// the Babysitters Club DApp Project and 2018. The MIT Licence.
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


// ----------------------------------------------------------------------------
// ClubToken Interface = ERC20 + symbol + name + decimals + mint + approveAndCall
// ----------------------------------------------------------------------------
contract ClubTokenInterface is ERC20Interface {
    function symbol() public view returns (string);
    function name() public view returns (string);
    function decimals() public view returns (uint8);
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success);
    function mint(address addr, uint tokens) public returns (bool success);
}


// ----------------------------------------------------------------------------
// Contract function to receive approval and execute function in one call
//
// Borrowed from MiniMeToken
// ----------------------------------------------------------------------------
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}


// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }
    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
    function transferOwnershipImmediately(address _newOwner) public onlyOwner {
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}


// ----------------------------------------------------------------------------
// ClubToken
// ----------------------------------------------------------------------------
contract ClubToken is ClubTokenInterface, Owned {
    using SafeMath for uint;

    string _symbol;
    string _name;
    uint8 _decimals;
    uint _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;


    constructor(string symbol, string name, uint8 decimals) public {
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
    }
    function symbol() public view returns (string) {
        return _symbol;
    }
    function name() public view returns (string) {
        return _name;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    function totalSupply() public constant returns (uint) {
        return _totalSupply  - balances[address(0)];
    }
    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return balances[tokenOwner];
    }
    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }
    function mint(address addr, uint tokens) public onlyOwner returns (bool success) {
        balances[addr] = balances[addr].add(tokens);
        emit Transfer(address(0), addr, tokens);
        return true;
    }
    function () public payable {
        revert();
    }
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}


// ----------------------------------------------------------------------------
// Membership Data Structure
// ----------------------------------------------------------------------------
library Members {
    struct Member {
        bool exists;
        uint index;
        string name;
    }
    struct Data {
        bool initialised;
        mapping(address => Member) entries;
        address[] index;
    }

    event MemberAdded(address indexed memberAddress, string name, uint totalAfter);
    event MemberRemoved(address indexed memberAddress, string name, uint totalAfter);
    event MemberNameUpdated(address indexed memberAddress, string oldName, string newName);

    function init(Data storage self) public {
        require(!self.initialised);
        self.initialised = true;
    }
    function isMember(Data storage self, address _address) public view returns (bool) {
        return self.entries[_address].exists;
    }
    function add(Data storage self, address _address, string _name) public {
        require(!self.entries[_address].exists);
        self.index.push(_address);
        self.entries[_address] = Member(true, self.index.length - 1, _name);
        emit MemberAdded(_address, _name, self.index.length);
    }
    function remove(Data storage self, address _address) public {
        require(self.entries[_address].exists);
        uint removeIndex = self.entries[_address].index;
        emit MemberRemoved(_address, self.entries[_address].name, self.index.length - 1);
        uint lastIndex = self.index.length - 1;
        address lastIndexAddress = self.index[lastIndex];
        self.index[removeIndex] = lastIndexAddress;
        self.entries[lastIndexAddress].index = removeIndex;
        delete self.entries[_address];
        if (self.index.length > 0) {
            self.index.length--;
        }
    }
    function setName(Data storage self, address memberAddress, string _name) public {
        Member storage member = self.entries[memberAddress];
        require(member.exists);
        emit MemberNameUpdated(memberAddress, member.name, _name);
        member.name = _name;
    }
    function length(Data storage self) public view returns (uint) {
        return self.index.length;
    }
}


// ----------------------------------------------------------------------------
// Club
// ----------------------------------------------------------------------------
contract Club {
    using SafeMath for uint;
    using Members for Members.Data;

    enum ProposalType {
        EtherPayment,                      //  0 Ether payment
        TokenPayment,                      //  1 DFF Token payment
        OtherTokenPayment,                 //  2 Token payment
        MintTokens,                        //  3 Mint DFF tokens
        AddRule,                           //  4 Add governance rule
        DeleteRule,                        //  5 Delete governance rule
        UpdateBTTSToken,                   //  6 Update BTTS Token
        UpdateDAO,                         //  7 Update DAO
        AddMember,                         //  8 Add member
        RemoveMember                       // 9 Remove member
    }

    struct Proposal {
        ProposalType proposalType;
        address proposer;
        string description;
        address address1;
        address address2;
        address recipient;
        address tokenContract;
        uint amount;
        mapping(address => bool) voted;
        uint memberVotedNo;
        uint memberVotedYes;
        address executor;
        bool open;
        // TODO opentime, closedtime
    }

    string public name;

    uint8 public constant TOKEN_DECIMALS = 18;
    uint public constant TOKEN_DECIMALSFACTOR = 10 ** uint(TOKEN_DECIMALS); 

    ClubTokenInterface public token;
    Members.Data members;
    bool public initialised;
    Proposal[] proposals;

    uint public tokensForNewMembers;

    uint public quorum = 80;
    uint public quorumDecayPerWeek = 10;
    uint public requiredMajority = 70;

    // Must be copied here to be added to the ABI
    event MemberAdded(address indexed memberAddress, string name, uint totalAfter);
    event MemberRemoved(address indexed memberAddress, string name, uint totalAfter);
    event MemberNameUpdated(address indexed memberAddress, string oldName, string newName);

    event TokenUpdated(address indexed oldToken, address indexed newToken);
    event TokensForNewMembersUpdated(uint oldTokens, uint newTokens);
    event EtherDeposited(address indexed sender, uint amount);
    event NewProposal(uint indexed proposalId, ProposalType indexed proposalType, address indexed proposer, address recipient, address tokenContract, uint amount); 
    event Voted(uint indexed proposalId, address indexed voter, bool vote, uint memberVotedYes, uint memberVotedNo);
    event EtherPaid(uint indexed proposalId, address indexed sender, address indexed recipient, uint amount);

    constructor(string _name, address _token, uint _tokensForNewMembers) public {
        members.init();
        name = _name;
        token = ClubTokenInterface(_token);
        tokensForNewMembers = _tokensForNewMembers;
    }
    function init(address _memberAddr, string _memberName) public {
        require(!initialised);
        initialised = true;
        members.add(_memberAddr, _memberName);
        token.mint(_memberAddr, tokensForNewMembers);
    }
    function setMemberName(string memberName) public {
        members.setName(msg.sender, memberName);
    }
    function proposeEtherPayment(string description, address _recipient, uint _amount) public {
        require(address(this).balance >= _amount);
        require(members.isMember(msg.sender));
        Proposal memory proposal = Proposal({
            proposalType: ProposalType.EtherPayment,
            proposer: msg.sender,
            description: description,
            address1: address(0),
            address2: address(0),
            recipient: _recipient,
            tokenContract: address(0),
            amount: _amount,
            memberVotedNo: 0,
            memberVotedYes: 0,
            executor: address(0),
            open: true
        });
        proposals.push(proposal);
        emit NewProposal(proposals.length - 1, ProposalType.EtherPayment, msg.sender, _recipient, address(0), _amount); 
    }
    function voteNo(uint proposalId) public {
        vote(proposalId, false);
    }
    function voteYes(uint proposalId) public {
        vote(proposalId, true);
    }
    function vote(uint proposalId, bool yesNo) public {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.open);
        if (!proposal.voted[msg.sender]) {
            if (yesNo) {
                proposal.memberVotedYes++;
            } else {
                proposal.memberVotedNo++;
            }
            emit Voted(proposalId, msg.sender, yesNo, proposal.memberVotedYes, proposal.memberVotedNo);
            proposal.voted[msg.sender];
        }
        if (proposal.memberVotedYes > 0 && proposal.open) {
            if (proposal.proposalType == ProposalType.EtherPayment) {
                proposal.recipient.transfer(proposal.amount);
                emit EtherPaid(proposalId, msg.sender, proposal.recipient, proposal.amount);
                proposal.executor = msg.sender;
                proposal.open = false;
            }
        }
    }

    function setToken(address _token) internal {
        emit TokenUpdated(address(token), _token);
        token = ClubTokenInterface(_token);
    }
    function setTokensForNewMembers(uint _newToken) internal {
        emit TokensForNewMembersUpdated(tokensForNewMembers, _newToken);
        tokensForNewMembers = _newToken;
    }
    function addMember(address _address, string _name) internal {
        members.add(_address, _name);
        token.mint(_address, tokensForNewMembers);
    }
    function removeMember(address _address) internal {
        members.remove(_address);
    }

    function numberOfMembers() public view returns (uint) {
        return members.length();
    }
    function getMembers() public view returns (address[]) {
        return members.index;
    }
    function getMemberData(address _address) public view returns (bool _exists, uint _index, string _name) {
        Members.Member memory member = members.entries[_address];
        return (member.exists, member.index, member.name);
    }
    function getMemberByIndex(uint _index) public view returns (address _member) {
        return members.index[_index];
    }

    function getQuorum(uint proposalTime, uint currentTime) public view returns (uint) {
        if (quorum > currentTime.sub(proposalTime).mul(quorumDecayPerWeek).div(1 weeks)) {
            return quorum.sub(currentTime.sub(proposalTime).mul(quorumDecayPerWeek).div(1 weeks));
        } else {
            return 0;
        }
    }
    function numberOfProposals() public view returns (uint) {
        return proposals.length;
    }
    function getProposalData1(uint proposalId) public view returns (uint _proposalType, address _proposer, string _description) {
        Proposal memory proposal = proposals[proposalId];
        _proposalType = uint(proposal.proposalType);
        _proposer = proposal.proposer;
        _description = proposal.description;
    }
    function getProposalData2(uint proposalId) public view returns (address _address1, address _address2, address _recipient, address _tokenContract, uint _amount) {
        Proposal memory proposal = proposals[proposalId];
        _address1 = proposal.address1;
        _address2 = proposal.address2;
        _recipient = proposal.recipient;
        _tokenContract = proposal.tokenContract;
        _amount = proposal.amount;
    }
    function getProposalData3(uint proposalId) public view returns (uint _memberVotedNo, uint _memberVotedYes, address _executor, bool _open) {
        Proposal memory proposal = proposals[proposalId];
        _memberVotedNo = proposal.memberVotedNo;
        _memberVotedYes = proposal.memberVotedYes;
        _executor = proposal.executor;
        _open = proposal.open;
    }

    function () public payable {
        emit EtherDeposited(msg.sender, msg.value);
    }
}


// ----------------------------------------------------------------------------
// Club Factory
// ----------------------------------------------------------------------------
contract ClubFactory is Owned {

    mapping(address => bool) _verify;
    Club[] public deployedClubs;
    ClubToken[] public deployedTokens;

    event ClubListing(address indexed club, string clubName,
        address indexed token, string tokenSymbol, string tokenName, uint8 tokenDecimals,
        address indexed memberName, uint tokensForNewMembers);

    function verify(address addr) public view returns (bool valid) {
        valid = _verify[addr];
    }
    function deployClubContract(
        string clubName,
        string tokenSymbol,
        string tokenName,
        uint8 tokenDecimals,
        string memberName,
        uint tokensForNewMembers
    ) public returns (Club club, ClubToken token) {
        token = new ClubToken(tokenSymbol, tokenName, tokenDecimals);
        _verify[address(token)] = true;
        deployedTokens.push(token);
        club = new Club(clubName, address(token), tokensForNewMembers);
        token.transferOwnershipImmediately(address(club));
        club.init(msg.sender, memberName);
        _verify[address(club)] = true;
        deployedClubs.push(club);
        emit ClubListing(address(club), clubName, address(token), tokenSymbol, tokenName, tokenDecimals, msg.sender, tokensForNewMembers);
    }
    function numberOfDeployedClubs() public view returns (uint) {
        return deployedClubs.length;
    }
    function numberOfDeployedTokens() public view returns (uint) {
        return deployedTokens.length;
    }
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
    function () public payable {
        revert();
    }
}