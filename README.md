# DeFi Micro-Lending Platform

A decentralized micro-lending platform built on Base Sepolia with AI-powered credit scoring.

## Features

- AI-powered credit scoring using DistilBERT
- DAO governance for loan approval
- Decentralized insurance pool
- Smart contract-based lending platform
- Modern React frontend with Web3 integration

## Project Structure

```
defi-credit-platform/
├── backend/              # Python FastAPI backend
│   ├── credit_scoring.py # AI credit scoring logic
│   ├── main.py          # FastAPI server
│   └── requirements.txt  # Python dependencies
├── contracts/           # Solidity smart contracts
│   └── MicroLendingPlatform.sol
├── frontend/           # React frontend
│   ├── package.json
│   └── src/
│       └── App.js
└── README.md
```

## Setup Instructions

### 1. Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: .\venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

### 2. Smart Contract Deployment

1. Install Hardhat and dependencies
2. Configure your Base Sepolia RPC URL and private key
3. Deploy the contract:
```bash
npx hardhat run scripts/deploy.js --network base-sepolia
```

### 3. Frontend Setup

```bash
cd frontend
npm install
# Update LENDING_PLATFORM_ADDRESS in src/App.js with your deployed contract address
npm start
```

## Usage

1. Connect your MetaMask wallet (make sure you're on Base Sepolia network)
2. Fill out the loan application form
3. The AI system will evaluate your credit score
4. DAO members can vote on your loan request
5. Once approved, the loan amount minus insurance fee will be transferred
6. Repay the loan before the due date to maintain good credit

## Smart Contract Features

- Loan request and approval system
- DAO voting mechanism
- Insurance pool with configurable parameters
- Automatic insurance payout for defaulted loans

## AI Credit Scoring

The platform uses DistilBERT to analyze:
- User responses to predefined questions
- Historical on-chain data
- DAO member scores

The final credit score determines:
- Maximum loan amount
- Interest rate
- Insurance fee percentage

## Security Considerations

- All smart contracts use OpenZeppelin's security standards
- Access control for DAO functions
- Reentrancy protection
- Rate limiting on API endpoints
- Secure wallet integration
