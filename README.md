# Stakvlt

**Trustless Peer-to-Peer sBTC Lending on Stacks**

Stakvlt is a decentralized lending marketplace built on the Stacks blockchain where lenders offer sBTC loans and borrowers lock overcollateralized sBTC as security. The smart contract automatically enforces all loan terms — returning collateral on repayment or transferring it to the lender on default — with no intermediaries, no custodians, and no trust required between parties.

---

## The Problem

Bitcoin holders sitting on significant sBTC have no native way to earn yield or access liquidity without leaving the Bitcoin ecosystem or trusting a centralized custodian. The Stacks ecosystem currently lacks a trustless peer-to-peer lending primitive that puts sBTC to work as productive capital.

---

## The Solution

Stakvlt creates an open, permissionless lending marketplace where sBTC can be borrowed and lent directly between peers, enforced entirely by Clarity smart contracts — bringing the first truly Bitcoin-native credit market to Stacks.

---

## How It Works

### The Two Users

- **Lender** — has sBTC sitting idle, wants to earn yield by lending it out
- **Borrower** — needs liquidity, willing to lock collateral to access a loan

### The Loan Lifecycle

**Step 1 — Lender Creates a Loan Offer**
The lender sets their loan amount, interest rate, and duration. The smart contract locks their sBTC in escrow and publishes the offer on the marketplace.

**Step 2 — Borrower Accepts the Offer**
The borrower deposits 150% of the loan amount as collateral. The contract immediately releases the loan to the borrower's wallet.

**Step 3 — Loan is Active**
The smart contract holds both the lender's terms and borrower's collateral. The clock starts ticking.

**Step 4a — Repayment ✅**
Borrower repays principal + interest before the deadline. Contract returns collateral to borrower and forwards repayment to lender. Both parties win.

**Step 4b — Default ❌**
Deadline passes with no repayment. Anyone can trigger liquidation. Contract automatically sends the borrower's collateral to the lender as compensation.

**Step 5 — Cancel Offer**
Lender can cancel any untaken offer and retrieve their sBTC at any time.

---

## Key Mechanics

| Parameter        | Value                              |
| ---------------- | ---------------------------------- |
| Collateral Ratio | 150% of loan amount                |
| Interest Rate    | Set by lender (in basis points)    |
| Loan Duration    | ~30 days (~4320 Stacks blocks)     |
| Token            | sBTC (1:1 Bitcoin peg)             |
| Units            | Satoshis (no decimals in contract) |

**Why 150% collateral?**
Borrowers must deposit more than they borrow. If a borrower defaults, the lender receives the full collateral — more than the loan value — making default financially irrational for borrowers and safe for lenders.

**Why Satoshis?**
Clarity smart contracts only work with integers, never decimals. 1 sBTC = 100,000,000 satoshis. The UI handles conversion so users see friendly amounts like "0.05 sBTC" while the contract works in whole numbers underneath.

---

## Smart Contract Functions

### Public Functions

| Function            | Who Calls It | What It Does                           |
| ------------------- | ------------ | -------------------------------------- |
| `create-loan-offer` | Lender       | Deposits sBTC and creates a loan offer |
| `accept-loan`       | Borrower     | Locks collateral and receives loan     |
| `repay-loan`        | Borrower     | Repays loan, gets collateral back      |
| `liquidate-loan`    | Anyone       | Triggers default after deadline passes |
| `cancel-offer`      | Lender       | Cancels untaken offer, retrieves sBTC  |

### Read-Only Functions

| Function             | What It Returns                               |
| -------------------- | --------------------------------------------- |
| `get-loan-offer`     | Details of a specific loan offer              |
| `get-active-loan`    | Details of an active loan                     |
| `get-loan-count`     | Total number of loans created                 |
| `is-loan-overdue`    | Whether a loan has passed its deadline        |
| `preview-repayment`  | Calculate repayment amount before accepting   |
| `preview-collateral` | Calculate collateral needed for a loan amount |

---

## Tech Stack

- **Smart Contract:** Clarity (Stacks blockchain)
- **Token:** sBTC (`SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token`)
- **Testing:** Clarinet
- **Network:** Stacks (Bitcoin L2)

---

## Deployment:

- Although actively working on the contract

**Testnet Contract Address:**

```
ST3N8PR8ARF68BC45EDK4MWZ3WWDM74CFJAGZBY3K.stakvlt
```

**Testnet Explorer:**

```
https://explorer.hiro.so/txid/ST3N8PR8ARF68BC45EDK4MWZ3WWDM74CFJAGZBY3K.stakvlt?chain=testnet
```

**Mainnet:**
`SP3N8PR8ARF68BC45EDK4MWZ3WWDM74CFJB3SS99R.stakvlt`

---

## Project Roadmap

### Phase 1 — Smart Contract (Month 1)

- [x] Core lending contract written
- [x] Deployed to Stacks testnet
- [ ] Full Clarinet test suite covering all loan states
- [ ] 100% test coverage on happy path, default, and edge cases

### Phase 2 — Frontend & Integration (Month 2)

- [ ] Web frontend connected to smart contract on testnet
- [ ] Lender dashboard — create offers, track active loans
- [ ] Borrower dashboard — browse offers, repay loans, track collateral
- [ ] Wallet integration (Hiro Wallet)
- [ ] Live testnet demo

### Phase 3 — Mainnet Launch (Month 3)

- [ ] Mainnet deployment
- [ ] Protocol fee mechanism (0.5% on completed loans)
- [ ] User documentation
- [ ] Launch announcement and community onboarding

---

## Why Stacks?

Stacks is the only platform where this is possible. sBTC brings real Bitcoin into a smart contract environment secured by Bitcoin's proof of work — something no other chain can offer. Stakvlt's entire value proposition depends on sBTC's 1:1 Bitcoin peg and Clarity's fully transparent, automatically enforceable contract logic. Building this on any other chain would simply be another wrapped token protocol. On Stacks, it is native Bitcoin DeFi.

---

## Grant Application

Stakvlt is applying for a **Getting Started Grant** from the Stacks Endowment to fund Phase 1–3 development. Grant amount requested: **$4,000 USD**.

Budget breakdown:

- Smart Contract Development & Testing — 50% ($2,000)
- Frontend UI Development — 30% ($1,200)
- Infrastructure & Deployment — 10% ($400)
- Documentation & Community — 10% ($400)

---

## Error Codes

| Code   | Meaning                 |
| ------ | ----------------------- |
| `u100` | Loan not found          |
| `u101` | Loan already exists     |
| `u102` | Insufficient collateral |
| `u103` | Loan not active         |
| `u104` | Not authorized          |
| `u105` | Deadline not yet passed |
| `u106` | Deadline already passed |
| `u107` | Loan already taken      |
| `u108` | Token transfer failed   |

---

## License

MIT — open source from day one.

---

_Built on Bitcoin. Secured by Stacks._
