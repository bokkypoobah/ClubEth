pragma solidity ^0.4.23;

// ----------------------------------------------------------------------------
// ClubEth.App Project
//
// https://github.com/bokkypoobah/ClubEth
//
// Enjoy.
//
// (c) BokkyPooBah / Bok Consulting Pty Ltd and
// the ClubEth.App Project - 2018. The MIT Licence.
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
contract ClubEthTokenInterface is ERC20Interface {
    function symbol() public view returns (string);
    function name() public view returns (string);
    function decimals() public view returns (uint8);
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success);
    function mint(address tokenOwner, uint tokens) public returns (bool success);
    function burn(address tokenOwner, uint tokens) public returns (bool success);
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
    function mint(address tokenOwner, uint tokens) public onlyOwner returns (bool success) {
        balances[tokenOwner] = balances[tokenOwner].add(tokens);
        _totalSupply = _totalSupply.add(tokens);
        emit Transfer(address(0), tokenOwner, tokens);
        return true;
    }
    function burn(address tokenOwner, uint tokens) public onlyOwner returns (bool success) {
        if (tokens > balances[tokenOwner]) {
            tokens = balances[tokenOwner];
        }
        _totalSupply = _totalSupply.sub(tokens);
        balances[tokenOwner] = 0;
        emit Transfer(tokenOwner, address(0), tokens);
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
// Proposals Data Structure
// ----------------------------------------------------------------------------
library Proposals {
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
        bool pass;
    }

    struct Data {
        bool initialised;
        Proposal[] proposals;
    }

    event NewProposal(uint indexed proposalId, Proposals.ProposalType indexed proposalType, address indexed proposer); 
    event Voted(uint indexed proposalId, address indexed voter, bool vote, uint votedYes, uint votedNo);
    event VoteResult(uint indexed proposalId, bool pass, uint votes, uint quorumPercent, uint membersLength, uint yesPercent, uint requiredMajority);

    function proposeAddMember(Data storage self, string memberName, address memberAddress) public returns (uint proposalId) {
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
            closed: 0,
            pass: false
        });
        self.proposals.push(proposal);
        proposalId = self.proposals.length - 1;
        emit NewProposal(proposalId, proposal.proposalType, msg.sender);
    }
    function proposeRemoveMember(Data storage self, string description, address memberAddress) public returns (uint proposalId) {
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
            closed: 0,
            pass: false
        });
        self.proposals.push(proposal);
        proposalId = self.proposals.length - 1;
        emit NewProposal(proposalId, proposal.proposalType, msg.sender);
    }
    function proposeMintTokens(Data storage self, string description, address tokenOwner, uint amount) public returns (uint proposalId) {
        Proposal memory proposal = Proposal({
            proposalType: ProposalType.MintTokens,
            proposer: msg.sender,
            description: description,
            address1: tokenOwner,
            address2: address(0),
            amount: amount,
            votedNo: 0,
            votedYes: 0,
            initiated: now,
            closed: 0,
            pass: false
        });
        self.proposals.push(proposal);
        proposalId = self.proposals.length - 1;
        emit NewProposal(proposalId, proposal.proposalType, msg.sender);
    }
    function proposeBurnTokens(Data storage self, string description, address tokenOwner, uint amount) public returns (uint proposalId) {
        Proposal memory proposal = Proposal({
            proposalType: ProposalType.BurnTokens,
            proposer: msg.sender,
            description: description,
            address1: tokenOwner,
            address2: address(0),
            amount: amount,
            votedNo: 0,
            votedYes: 0,
            initiated: now,
            closed: 0,
            pass: false
        });
        self.proposals.push(proposal);
        proposalId = self.proposals.length - 1;
        emit NewProposal(proposalId, proposal.proposalType, msg.sender);
    }
    function proposeEtherTransfer(Data storage self, string description, address recipient, uint amount) public returns (uint proposalId) {
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
            closed: 0,
            pass: false
        });
        self.proposals.push(proposal);
        proposalId = self.proposals.length - 1;
        emit NewProposal(proposalId, proposal.proposalType, msg.sender);
    }
    function vote(Data storage self, uint proposalId, bool yesNo, uint membersLength, uint quorum, uint requiredMajority) public {
        Proposal storage proposal = self.proposals[proposalId];
        require(proposal.closed == 0);
        // First vote
        if (proposal.voted[msg.sender] == 0) {
            if (yesNo) {
                proposal.votedYes++;
                proposal.voted[msg.sender] = 1;
            } else {
                proposal.votedNo++;
                proposal.voted[msg.sender] = 2;
            }
            emit Voted(proposalId, msg.sender, yesNo, proposal.votedYes, proposal.votedNo);
        // Changing Yes to No
        } else if (proposal.voted[msg.sender] == 1 && !yesNo && proposal.votedYes > 0) {
            proposal.votedYes--;
            proposal.votedNo++;
            proposal.voted[msg.sender] = 2;
            emit Voted(proposalId, msg.sender, yesNo, proposal.votedYes, proposal.votedNo);
        // Changing No to Yes
        } else if (proposal.voted[msg.sender] == 2 && yesNo && proposal.votedNo > 0) {
            proposal.votedYes++;
            proposal.votedNo--;
            proposal.voted[msg.sender] = 1;
            emit Voted(proposalId, msg.sender, yesNo, proposal.votedYes, proposal.votedNo);
        }
        if (proposal.proposalType == ProposalType.RemoveMember && membersLength > 0) {
            membersLength--;
        }
        uint voteCount = proposal.votedYes + proposal.votedNo;
        if (voteCount * 100 >= quorum * membersLength) {
            uint yesPercent = proposal.votedYes * 100 / voteCount;
            proposal.pass = yesPercent >= requiredMajority;
            emit VoteResult(proposalId, proposal.pass, voteCount, quorum, membersLength, yesPercent, requiredMajority);
        }
    }
    // function get(Data storage self, uint proposalId) public view returns (Proposal proposal) {
    //    return self.proposals[proposalId];
    // }
    function getProposalType(Data storage self, uint proposalId) public view returns (ProposalType) {
        return self.proposals[proposalId].proposalType;
    }
    function getDescription(Data storage self, uint proposalId) public view returns (string) {
        return self.proposals[proposalId].description;
    }
    function getAddress1(Data storage self, uint proposalId) public view returns (address) {
        return self.proposals[proposalId].address1;
    }
    function getAmount(Data storage self, uint proposalId) public view returns (uint) {
        return self.proposals[proposalId].amount;
    }
    function getInitiated(Data storage self, uint proposalId) public view returns (uint) {
        return self.proposals[proposalId].initiated;
    }
    function isClosed(Data storage self, uint proposalId) public view returns (bool) {
        self.proposals[proposalId].closed;
    }
    function pass(Data storage self, uint proposalId) public view returns (bool) {
        return self.proposals[proposalId].pass;
    }
    function toExecute(Data storage self, uint proposalId) public view returns (bool) {
        return self.proposals[proposalId].pass && self.proposals[proposalId].closed == 0;
    }
    function close(Data storage self, uint proposalId) public {
        self.proposals[proposalId].closed = now;
    }
    function length(Data storage self) public view returns (uint) {
        return self.proposals.length;
    }
}


// ----------------------------------------------------------------------------
// Club
// ----------------------------------------------------------------------------
contract Club {
    using SafeMath for uint;
    using Members for Members.Data;
    using Proposals for Proposals.Data;

    string public name;

    uint8 public constant TOKEN_DECIMALS = 18;
    uint public constant TOKEN_DECIMALSFACTOR = 10 ** uint(TOKEN_DECIMALS); 

    ClubTokenInterface public token;
    Members.Data members;
    Proposals.Data public proposals;
    bool public initialised;

    uint public tokensForNewMembers;

    uint public quorum = 80;
    uint public quorumDecayPerWeek = 10;
    uint public requiredMajority = 70;


    // Must be copied here to be added to the ABI
    event MemberAdded(address indexed memberAddress, string name, uint totalAfter);
    event MemberRemoved(address indexed memberAddress, string name, uint totalAfter);
    event MemberNameUpdated(address indexed memberAddress, string oldName, string newName);

    event NewProposal(uint indexed proposalId, Proposals.ProposalType indexed proposalType, address indexed proposer); 
    event Voted(uint indexed proposalId, address indexed voter, bool vote, uint votedYes, uint votedNo);
    event VoteResult(uint indexed proposalId, bool pass, uint votes, uint quorumPercent, uint membersLength, uint yesPercent, uint requiredMajority);
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
    function proposeAddMember(string memberName, address memberAddress) public onlyMember returns (uint proposalId) {
        proposalId = proposals.proposeAddMember(memberName, memberAddress);
        vote(proposalId, true);
    }
    function proposeRemoveMember(string description, address memberAddress) public onlyMember returns (uint proposalId) {
        proposalId = proposals.proposeRemoveMember(description, memberAddress);
        vote(proposalId, true);
    }
    function proposeMintTokens(string description, address tokenOwner, uint amount) public onlyMember returns (uint proposalId) {
        proposalId = proposals.proposeMintTokens(description, tokenOwner, amount);
        vote(proposalId, true);
    }
    function proposeBurnTokens(string description, address tokenOwner, uint amount) public onlyMember returns (uint proposalId) {
        proposalId = proposals.proposeBurnTokens(description, tokenOwner, amount);
        vote(proposalId, true);
    }
    function proposeEtherTransfer(string description, address recipient, uint amount) public onlyMember returns (uint proposalId) {
        proposalId = proposals.proposeEtherTransfer(description, recipient, amount);
        vote(proposalId, true);
    }
    function voteNo(uint proposalId) public onlyMember {
        vote(proposalId, false);
    }
    function voteYes(uint proposalId) public onlyMember {
        vote(proposalId, true);
    }
    function vote(uint proposalId, bool yesNo) internal {
        proposals.vote(proposalId, yesNo, members.length(), getQuorum(proposals.getInitiated(proposalId), now), requiredMajority);
        Proposals.ProposalType proposalType = proposals.getProposalType(proposalId);
        if (proposals.toExecute(proposalId)) {
            string memory description = proposals.getDescription(proposalId);
            address address1  = proposals.getAddress1(proposalId);
            uint amount = proposals.getAmount(proposalId);
            if (proposalType == Proposals.ProposalType.AddMember) {
                members.add(address1, description);
                token.mint(address1, tokensForNewMembers);
            } else if (proposalType == Proposals.ProposalType.RemoveMember) {
                members.remove(address1);
                token.burn(address1, uint(-1));
            } else if (proposalType == Proposals.ProposalType.MintTokens) {
                token.mint(address1, amount);
            } else if (proposalType == Proposals.ProposalType.BurnTokens) {
                token.burn(address1, amount);
            } else if (proposalType == Proposals.ProposalType.EtherTransfer) {
                address1.transfer(amount);
                emit EtherTransferred(proposalId, msg.sender, address1, amount);
            }
            proposals.close(proposalId);
        }
    }

    /*
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
    */

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
        return proposals.length();
    }
    function getProposal(uint proposalId) public view returns (uint _proposalType, address _proposer, string _description, address _address1, address _address2, uint _amount, uint _votedNo, uint _votedYes, uint _initiated, uint _closed) {
        Proposals.Proposal memory proposal = proposals.proposals[proposalId];
        _proposalType = uint(proposal.proposalType);
        _proposer = proposal.proposer;
        _description = proposal.description;
        _address1 = proposal.address1;
        _address2 = proposal.address2;
        _amount = proposal.amount;
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

    event ClubListing(address indexed clubAddress, string clubName,
        address indexed tokenAddress, string tokenSymbol, string tokenName, uint8 tokenDecimals,
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