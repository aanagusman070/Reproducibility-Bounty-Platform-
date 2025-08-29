# 🔬 Reproducibility Bounty Platform

A Clarity smart contract enabling researchers to post bounties for study replication, promoting scientific integrity and reproducibility.

## 📖 Overview

The Reproducibility Bounty Platform addresses the critical issue of irreproducible scientific research by incentivizing independent verification. Authors post studies with token-funded bounties, researchers submit replication attempts, and validators assess results on-chain.

## ✨ Features

- 📝 **Study Publishing**: Create studies with STX bounties and deadlines
- 🔄 **Replication Submission**: Submit replication attempts with result hashes  
- ✅ **Validation System**: Authorized validators review and approve replications
- 💰 **Reward Distribution**: Automatic STX rewards for validated replications
- 📊 **Researcher Statistics**: Track replication success rates and earnings
- ⏰ **Expiration Handling**: Study authors can withdraw expired bounties

## 🚀 Usage

### Deploy Contract
```bash
clarinet deploy
```

### Initialize Platform
```clarity
(contract-call? .Reproducibility-Bounty-Platform- initialize-platform)
```

### Create Study
```clarity
(contract-call? .Reproducibility-Bounty-Platform- create-study 
    "Study Title" 
    "Detailed study description" 
    u1000000 
    u1000)
```

### Submit Replication
```clarity
(contract-call? .Reproducibility-Bounty-Platform- submit-replication 
    u1 
    "sha256-hash-of-replication-results")
```

### Validate Replication (Validators Only)
```clarity
(contract-call? .Reproducibility-Bounty-Platform- validate-replication 
    u1 
    true)
```

### Claim Reward
```clarity
(contract-call? .Reproducibility-Bounty-Platform- claim-reward u1)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `initialize-platform` | Initialize platform with owner as validator | - |
| `add-validator` | Add new validator (owner only) | `validator: principal` |
| `remove-validator` | Remove validator (owner only) | `validator: principal` |
| `create-study` | Post new study with bounty | `title`, `description`, `bounty-amount`, `duration-blocks` |
| `submit-replication` | Submit replication attempt | `study-id`, `result-hash` |
| `validate-replication` | Validate replication (validators only) | `replication-id`, `is-valid` |
| `claim-reward` | Claim STX reward for validated replication | `replication-id` |
| `withdraw-expired-bounty` | Withdraw bounty after deadline | `study-id` |
| `set-platform-fee` | Update platform fee (owner only) | `new-fee` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-study` | Get study details | Study data or none |
| `get-replication` | Get replication details | Replication data or none |
| `get-researcher-replication` | Get specific researcher's replication | Replication data or none |
| `get-researcher-stats` | Get researcher statistics | Stats tuple |
| `is-validator` | Check if address is validator | Boolean |
| `get-platform-fee` | Get current platform fee | Fee in basis points |

## 📊 Data Structures

### Study
```clarity
{
  author: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  bounty-amount: uint,
  deadline: uint,
  status: uint,
  created-at: uint,
  validator: (optional principal)
}
```

### Replication
```clarity
{
  study-id: uint,
  researcher: principal,
  result-hash: (string-ascii 64),
  status: uint,
  submitted-at: uint,
  validated-at: (optional uint),
  validator: (optional principal)
}
```

## 🔒 Security Features

- ✅ Authorization checks for all sensitive operations
- ✅ STX escrow system prevents double-spending
- ✅ Time-based expiration prevents locked funds
- ✅ One replication per researcher per study
- ✅ Platform fee mechanism for sustainability

## 🌟 Status Codes

- `0`: Pending
- `1`: Validated  
- `2`: Rejected
- `3`: Claimed

## 💎 Platform Economics

- Default platform fee: 2.5% (250 basis points)
- Fees fund platform maintenance and validator rewards
- Study authors retain full control over expired bounties

---

Built with ❤️ for reproducible science on Stacks blockchain 🌐
