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
// ClubToken Interface = ERC20 + symbol + name + decimals + mint + burn
// + approveAndCall
// ----------------------------------------------------------------------------
contract ClubTokenInterface is ERC20Interface {
    function symbol() public view returns (string);
    function name() public view returns (string);
    function decimals() public view returns (uint8);
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success);
    function mint(address addr, uint tokens) public returns (bool success);
    function burn(address addr, uint tokens) public returns (bool success);
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
        _totalSupply = _totalSupply.add(tokens);
        emit Transfer(address(0), addr, tokens);
        return true;
    }
    function burn(address addr, uint tokens) public onlyOwner returns (bool success) {
        if (tokens > balances[addr]) {
            tokens = balances[addr];
        }
        _totalSupply = _totalSupply.sub(tokens);
        balances[addr] = 0;
        emit Transfer(addr, address(0), tokens);
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
    function isMember(Data storage self, address memberAddress) public view returns (bool) {
        return self.entries[memberAddress].exists;
    }
    function add(Data storage self, address memberAddress, string memberName) public {
        require(!self.entries[memberAddress].exists);
        self.index.push(memberAddress);
        self.entries[memberAddress] = Member(true, self.index.length - 1, memberName);
        emit MemberAdded(memberAddress, memberName, self.index.length);
    }
    function remove(Data storage self, address memberAddress) public {
        require(self.entries[memberAddress].exists);
        uint removeIndex = self.entries[memberAddress].index;
        emit MemberRemoved(memberAddress, self.entries[memberAddress].name, self.index.length - 1);
        uint lastIndex = self.index.length - 1;
        address lastIndexAddress = self.index[lastIndex];
        self.index[removeIndex] = lastIndexAddress;
        self.entries[lastIndexAddress].index = removeIndex;
        delete self.entries[memberAddress];
        if (self.index.length > 0) {
            self.index.length--;
        }
    }
    function setName(Data storage self, address memberAddress, string memberName) public {
        Member storage member = self.entries[memberAddress];
        require(member.exists);
        emit MemberNameUpdated(memberAddress, member.name, memberName);
        member.name = memberName;
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
        AddMember,                         //  0 Add member
        RemoveMember,                      //  1 Remove member
        MintTokens,                        //  2 Mint tokens
        BurnTokens,                        //  3 Burn tokens
        EtherTransfer,                     //  4 Ether transfer from club
        ClubTokenTransfer,                 //  5 Club token transfer from club
        ERC20TokenTransfer,                //  6 ERC20 token transfer from club
        AddRule,                           //  7 Add governance rule
        DeleteRule,                        //  8 Delete governance rule
        UpdateClubName,                    //  9 Update Club name
        UpdateInitialTokensForNewMembers,  // 10 Update initialTokensForNewMembers
        UpdateClubToken,                   // 11 Update Club token
        UpdateClub                         // 12 Update Club
    }

    struct Proposal {
        ProposalType proposalType;
        address proposer;
        string description;
        address address1;
        address address2;
        uint amount;
        mapping(address => uint) voted;
        uint votedNo;
        uint votedYes;
        uint initiated;
        uint closed;
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

    event NewProposal(uint indexed proposalId, ProposalType indexed proposalType, address indexed proposer); 
    event Voted(uint indexed proposalId, address indexed voter, bool vote, uint votedYes, uint votedNo);
    event VoteResult(uint indexed proposalId, uint votes, uint quorumPercent, uint membersLength, uint yesPercent, uint requiredMajority);
    event TokenUpdated(address indexed oldToken, address indexed newToken);
    event TokensForNewMembersUpdated(uint oldTokens, uint newTokens);
    event EtherDeposited(address indexed sender, uint amount);
    event EtherTransferred(uint indexed proposalId, address indexed sender, address indexed recipient, uint amount);

    modifier onlyMember {
        require(members.isMember(msg.sender));
        _;
    }

    constructor(string clubName, address clubToken, uint _tokensForNewMembers) public {
        members.init();
        name = clubName;
        token = ClubTokenInterface(clubToken);
        tokensForNewMembers = _tokensForNewMembers;
    }
    function init(address memberAddress, string memberName) public {
        require(!initialised);
        initialised = true;
        members.add(memberAddress, memberName);
        token.mint(memberAddress, tokensForNewMembers);
    }
    function setMemberName(string memberName) public {
        members.setName(msg.sender, memberName);
    }
    function proposeAddMember(string memberName, address memberAddress) public onlyMember {
        Proposal memory proposal = Proposal({
            proposalType: ProposalType.AddMember,
            proposer: msg.sender,
            description: memberName,
            address1: memberAddress,
            address2: address(0),
            amount: 0,
            votedNo: 0,
            votedYes: 0,
            initiated: now,
            closed: 0
        });
        proposals.push(proposal);
        emit NewProposal(proposals.length - 1, proposal.proposalType, msg.sender);
        vote(proposals.length - 1, true);
    }
    function proposeRemoveMember(string description, address memberAddress) public onlyMember {
        Proposal memory proposal = Proposal({
            proposalType: ProposalType.RemoveMember,
            proposer: msg.sender,
            description: description,
            address1: memberAddress,
            address2: address(0),
            amount: 0,
            votedNo: 0,
            votedYes: 0,
            initiated: now,
            closed: 0
        });
        proposals.push(proposal);
        emit NewProposal(proposals.length - 1, proposal.proposalType, msg.sender);
        vote(proposals.length - 1, true);
    }
    function proposeEtherPayment(string description, address recipient, uint amount) public onlyMember {
        require(address(this).balance >= amount);
        Proposal memory proposal = Proposal({
            proposalType: ProposalType.EtherTransfer,
            proposer: msg.sender,
            description: description,
            address1: recipient,
            address2: address(0),
            amount: amount,
            votedNo: 0,
            votedYes: 0,
            initiated: now,
            closed: 0
        });
        proposals.push(proposal);
        emit NewProposal(proposals.length - 1, proposal.proposalType, msg.sender);
        vote(proposals.length - 1, true);
    }
    function voteNo(uint proposalId) public onlyMember {
        vote(proposalId, false);
    }
    function voteYes(uint proposalId) public onlyMember {
        vote(proposalId, true);
    }
    function vote(uint proposalId, bool yesNo) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.closed == 0);
        if (proposal.voted[msg.sender] == 0) {
            if (yesNo) {
                proposal.votedYes++;
                proposal.voted[msg.sender] = 1;
            } else {
                proposal.votedNo++;
                proposal.voted[msg.sender] = 2;
            }
            emit Voted(proposalId, msg.sender, yesNo, proposal.votedYes, proposal.votedNo);
            proposal.voted[msg.sender];
        }
        uint membersLength = members.length();
        // TODO: Is this required
        if (proposal.proposalType == ProposalType.RemoveMember && membersLength > 0) {
            membersLength--;
        }
        uint voteCount = proposal.votedYes + proposal.votedNo;
        if (voteCount * 100 >= getQuorum(proposal.initiated, now) * membersLength) {
            uint yesPercent = proposal.votedYes * 100 / voteCount;
            emit VoteResult(proposalId, voteCount, getQuorum(proposal.initiated, now), membersLength, yesPercent, requiredMajority);
            if (yesPercent >= requiredMajority) {
                executeProposal(proposalId);
            }
            proposal.closed = now;
        }
    }
    function executeProposal(uint proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.closed == 0);
        if (proposal.proposalType == ProposalType.AddMember) {
            members.add(proposal.address1, proposal.description);
            token.mint(proposal.address1, tokensForNewMembers);
            // TODO: Log event
        } else if (proposal.proposalType == ProposalType.RemoveMember) {
            members.remove(proposal.address1);
            token.burn(proposal.address1, uint(-1));
            // TODO: Log event
        } else if (proposal.proposalType == ProposalType.EtherTransfer) {
            proposal.address1.transfer(proposal.amount);
            emit EtherTransferred(proposalId, msg.sender, proposal.address1, proposal.amount);
        }
    }

    function setToken(address clubToken) internal {
        emit TokenUpdated(address(token), clubToken);
        token = ClubTokenInterface(clubToken);
    }
    function setTokensForNewMembers(uint _tokensForNewMembers) internal {
        emit TokensForNewMembersUpdated(tokensForNewMembers, _tokensForNewMembers);
        tokensForNewMembers = _tokensForNewMembers;
    }
    function addMember(address memberAddress, string memberName) internal {
        members.add(memberAddress, memberName);
        token.mint(memberAddress, tokensForNewMembers);
    }
    function removeMember(address memberAddress) internal {
        members.remove(memberAddress);
    }

    function numberOfMembers() public view returns (uint) {
        return members.length();
    }
    function getMembers() public view returns (address[]) {
        return members.index;
    }
    function getMemberData(address memberAddress) public view returns (bool _exists, uint _index, string _name) {
        Members.Member memory member = members.entries[memberAddress];
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
    function getProposalData2(uint proposalId) public view returns (address _address1, address _address2, uint _amount) {
        Proposal memory proposal = proposals[proposalId];
        _address1 = proposal.address1;
        _address2 = proposal.address2;
        _amount = proposal.amount;
    }
    function getProposalData3(uint proposalId) public view returns (uint _votedNo, uint _votedYes, uint _initiated, uint _closed) {
        Proposal memory proposal = proposals[proposalId];
        _votedNo = proposal.votedNo;
        _votedYes = proposal.votedYes;
        _initiated = proposal.initiated;
        _closed = proposal.closed;
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