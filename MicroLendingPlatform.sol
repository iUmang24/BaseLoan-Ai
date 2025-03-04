// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.0/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/IERC20.sol";

/**
 * @title MicroLendingPlatform
 * @dev 去中心化小额信贷平台，结合DAO治理进行贷款审批
 */
contract MicroLendingPlatform is Ownable, ReentrancyGuard {
    // 状态变量
    struct Loan {
        address borrower;          // 借款人地址
        uint256 amount;           // 贷款金额
        uint256 creditScore;      // 信用评分
        uint256 votingEndTime;    // 投票结束时间
        uint256 yesVotes;         // 赞成票数
        uint256 noVotes;          // 反对票数
        bool isApproved;          // 是否已批准
        bool isFunded;            // 是否已放款
        bool isRepaid;            // 是否已还款
        mapping(address => bool) hasVoted;  // 记录投票情况
    }

    struct DAOMember {
        bool isMember;           // 是否是DAO成员
        uint256 votingPower;     // 投票权重
    }

    // 合约状态变量
    mapping(uint256 => Loan) public loans;
    mapping(address => DAOMember) public daoMembers;
    mapping(address => uint256[]) public userLoans;  // 用户的贷款记录
    
    uint256 public loanCount;
    uint256 public minVotingPeriod = 2 days;
    uint256 public requiredVotes = 3;
    uint256 public constant MAX_CREDIT_SCORE = 100;
    
    IERC20 public lendingToken;  // 用于贷款的ERC20代币
    
    // 事件声明
    event LoanRequested(uint256 indexed loanId, address borrower, uint256 amount, uint256 creditScore);
    event Voted(uint256 indexed loanId, address voter, bool support);
    event LoanApproved(uint256 indexed loanId);
    event LoanRejected(uint256 indexed loanId);
    event LoanFunded(uint256 indexed loanId);
    event LoanRepaid(uint256 indexed loanId);
    event DAOMemberAdded(address member, uint256 votingPower);
    event DAOMemberRemoved(address member);
    event VotingPeriodUpdated(uint256 newPeriod);
    event RequiredVotesUpdated(uint256 newRequiredVotes);

    // 修饰器
    modifier onlyDAOMember() {
        require(daoMembers[msg.sender].isMember, "Not a DAO member");
        _;
    }

    modifier validLoanId(uint256 loanId) {
        require(loanId > 0 && loanId <= loanCount, "Invalid loan ID");
        _;
    }

    // 构造函数
    constructor(address _lendingToken) {
        require(_lendingToken != address(0), "Invalid token address");
        lendingToken = IERC20(_lendingToken);
    }

    // DAO管理功能
    function addDAOMember(address member, uint256 votingPower) external onlyOwner {
        require(member != address(0), "Invalid member address");
        require(!daoMembers[member].isMember, "Already a member");
        require(votingPower > 0, "Voting power must be positive");
        
        daoMembers[member] = DAOMember({
            isMember: true,
            votingPower: votingPower
        });
        
        emit DAOMemberAdded(member, votingPower);
    }

    function removeDAOMember(address member) external onlyOwner {
        require(daoMembers[member].isMember, "Not a member");
        delete daoMembers[member];
        emit DAOMemberRemoved(member);
    }

    // 贷款申请
    function requestLoan(uint256 amount, uint256 creditScore) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(creditScore > 0 && creditScore <= MAX_CREDIT_SCORE, "Invalid credit score");
        require(lendingToken.balanceOf(address(this)) >= amount, "Insufficient platform funds");
        
        loanCount++;
        Loan storage loan = loans[loanCount];
        loan.borrower = msg.sender;
        loan.amount = amount;
        loan.creditScore = creditScore;
        loan.votingEndTime = block.timestamp + minVotingPeriod;
        
        userLoans[msg.sender].push(loanCount);
        
        emit LoanRequested(loanCount, msg.sender, amount, creditScore);
    }

    // 投票功能
    function vote(uint256 loanId, bool support) external onlyDAOMember validLoanId(loanId) {
        Loan storage loan = loans[loanId];
        
        require(block.timestamp < loan.votingEndTime, "Voting period ended");
        require(!loan.hasVoted[msg.sender], "Already voted");
        require(!loan.isApproved && !loan.isFunded, "Loan already processed");

        loan.hasVoted[msg.sender] = true;
        uint256 votingPower = daoMembers[msg.sender].votingPower;

        if (support) {
            loan.yesVotes += votingPower;
            if (loan.yesVotes >= requiredVotes) {
                loan.isApproved = true;
                emit LoanApproved(loanId);
            }
        } else {
            loan.noVotes += votingPower;
            if (loan.noVotes >= requiredVotes) {
                emit LoanRejected(loanId);
            }
        }

        emit Voted(loanId, msg.sender, support);
    }

    // 资金发放
    function fundLoan(uint256 loanId) external nonReentrant validLoanId(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.isApproved && !loan.isFunded, "Loan not approved or already funded");
        require(block.timestamp >= loan.votingEndTime, "Voting period not ended");

        loan.isFunded = true;
        require(
            lendingToken.transfer(loan.borrower, loan.amount),
            "Transfer failed"
        );
        
        emit LoanFunded(loanId);
    }

    // 还款功能
    function repayLoan(uint256 loanId) external nonReentrant validLoanId(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.isFunded && !loan.isRepaid, "Invalid loan state");
        require(msg.sender == loan.borrower, "Only borrower can repay");

        uint256 repayAmount = loan.amount;
        loan.isRepaid = true;

        require(
            lendingToken.transferFrom(msg.sender, address(this), repayAmount),
            "Transfer failed"
        );
        
        emit LoanRepaid(loanId);
    }

    // 查询功能
    function getLoanDetails(uint256 loanId) external view validLoanId(loanId) returns (
        address borrower,
        uint256 amount,
        uint256 creditScore,
        uint256 votingEndTime,
        uint256 yesVotes,
        uint256 noVotes,
        bool isApproved,
        bool isFunded,
        bool isRepaid
    ) {
        Loan storage loan = loans[loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.creditScore,
            loan.votingEndTime,
            loan.yesVotes,
            loan.noVotes,
            loan.isApproved,
            loan.isFunded,
            loan.isRepaid
        );
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function hasVoted(uint256 loanId, address voter) external view validLoanId(loanId) returns (bool) {
        return loans[loanId].hasVoted[voter];
    }

    // 管理功能
    function updateVotingPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod >= 1 days, "Voting period too short");
        minVotingPeriod = newPeriod;
        emit VotingPeriodUpdated(newPeriod);
    }

    function updateRequiredVotes(uint256 newRequiredVotes) external onlyOwner {
        require(newRequiredVotes > 0, "Required votes must be positive");
        requiredVotes = newRequiredVotes;
        emit RequiredVotesUpdated(newRequiredVotes);
    }

    // 紧急功能
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(
            IERC20(token).transfer(owner(), amount),
            "Transfer failed"
        );
    }
}