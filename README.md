# Voting Smart Contract

Smart contract voting system yang dibangun menggunakan Hardhat v3, TypeScript, dan Solidity.

## Features

- ✅ **Secure Voting**: Setiap address hanya bisa vote sekali
- ✅ **Candidate Management**: Owner bisa menambah kandidat
- ✅ **Voting Control**: Owner bisa start/stop voting
- ✅ **Real-time Results**: Tracking vote counts dan winner
- ✅ **Event Logging**: Semua aktivitas tercatat dalam events
- ✅ **Comprehensive Testing**: Test coverage lengkap

## Tech Stack

- **Hardhat v3** - Development framework
- **TypeScript** - Type-safe development
- **Solidity ^0.8.28** - Smart contract language
- **Ethers.js v6** - Ethereum interaction library
- **Mocha & Chai** - Testing framework

## Quick Start

### 1. Installation

```bash
npm install
```

### 2. Compile Contracts

```bash
npm run compile
```

### 3. Run Tests

```bash
npm test
```

### 4. Deploy Locally

Start local Hardhat node:
```bash
npm run node
```

Deploy to local network:
```bash
npm run deploy:localhost
```

## Contract Overview

### Main Functions

#### Voting Functions
- `vote(uint256 candidateIndex)` - Vote untuk kandidat
- `hasAddressVoted(address voter)` - Cek apakah address sudah vote
- `getVoteDetails(address voter)` - Detail voting address tertentu

#### View Functions
- `getCandidates()` - Semua kandidat dengan vote count
- `getCandidate(uint256 index)` - Kandidat spesifik
- `getWinner()` - Kandidat dengan vote terbanyak
- `getVotingStats()` - Statistik voting

#### Owner Functions
- `addCandidate(string memory name)` - Tambah kandidat baru
- `setVotingStatus(bool active)` - Start/stop voting

### Events

- `Voted(address indexed voter, uint256 candidateIndex, string candidateName)`
- `VotingStatusChanged(bool active)`
- `CandidateAdded(string name, uint256 index)`

## Project Structure

```
├── contracts/           # Smart contracts
│   └── Voting.sol      # Main voting contract
├── scripts/            # Deployment scripts
│   └── deploy.ts       # Deploy script
├── test/               # Test files
│   └── Voting.test.ts  # Comprehensive tests
├── hardhat.config.ts   # Hardhat configuration
├── package.json        # Dependencies
└── tsconfig.json       # TypeScript config
```

## Deployment Networks

### Local Development
```bash
npm run deploy          # Deploy to Hardhat network
npm run deploy:localhost # Deploy to local node
```

### Testnet (Sepolia)
1. Setup environment variables:
```bash
cp .env.example .env
# Edit .env dengan API keys dan private key Anda
```

2. Deploy:
```bash
npm run deploy:sepolia
```

## Usage Examples

### Deploy Contract
```typescript
const candidates = ["Alice", "Bob", "Charlie"];
const VotingFactory = await ethers.getContractFactory("Voting");
const voting = await VotingFactory.deploy(candidates);
```

### Vote for Candidate
```typescript
// Vote untuk kandidat index 0 (Alice)
await voting.connect(voter).vote(0);
```

### Check Results
```typescript
// Get winner
const [name, voteCount, index] = await voting.getWinner();
console.log(`Winner: ${name} with ${voteCount} votes`);

// Get all candidates
const candidates = await voting.getCandidates();
candidates.forEach((candidate, i) => {
  console.log(`${i}: ${candidate.name} - ${candidate.voteCount} votes`);
});
```

## Security Features

- **No Double Voting**: Mapping untuk track addresses yang sudah vote
- **Input Validation**: Validasi candidate index dan nama
- **Owner Access Control**: Hanya owner yang bisa manage contract
- **Voting State Management**: Voting bisa di-pause oleh owner

## Gas Optimization

- Menggunakan `uint256` untuk vote counts
- Efficient storage layout untuk struct
- Optimized loops dalam view functions

## Testing

Test coverage meliputi:
- ✅ Deployment scenarios
- ✅ Voting functionality
- ✅ Access control
- ✅ Edge cases
- ✅ Event emissions
- ✅ Admin functions

Run tests:
```bash
npm test                    # Run all tests
npm test -- --grep "Voting" # Run specific test
```

## Scripts Available

```bash
npm run compile        # Compile contracts
npm run test          # Run tests
npm run deploy        # Deploy to default network
npm run node          # Start local Hardhat node
```

## Troubleshooting

### Common Issues

1. **"Cannot find module" errors**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

2. **Compilation errors**
   ```bash
   npx hardhat clean
   npm run compile
   ```

3. **Test failures**
   ```bash
   npx hardhat node # In separate terminal
   npm test
   ```

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit pull request

## License

MIT License - see LICENSE file for details