# BitBridge DEX Protocol

A next-generation automated market maker (AMM) protocol enabling trustless cross-chain liquidity between Bitcoin and Stacks assets. Built for Stacks Layer 2 with Bitcoin-native security guarantees.

## Overview

BitBridge DEX implements a constant product market maker (x * y = k) with advanced security mechanisms for cross-chain atomic settlements. The protocol enables seamless trading between BTC and Stacks assets while maintaining the security guarantees of the Bitcoin network.

## Key Features

- **Atomic Cross-Chain Swaps**: Trustless trading between BTC and Stacks assets
- **High-Precision AMM**: 6-decimal precision for accurate price discovery
- **Layer 2 Optimized**: Designed for Stacks L2 scalability
- **Bitcoin-Native Security**: Leverages Bitcoin's settlement guarantees
- **Gas-Optimized**: Efficient execution for reduced transaction costs

## Technical Architecture

### Core Components

1. **Liquidity Pools**
   - Dual-asset pools supporting BTC and Stacks tokens
   - Constant product market maker formula (x * y = k)
   - Dynamic fee adjustment mechanism
   - Atomic execution guarantees

2. **Price Calculation**
   - 6-decimal precision for all calculations
   - Slippage protection mechanisms
   - Real-time price manipulation resistance

3. **Security Features**
   - Comprehensive slippage checks
   - Concurrent transaction protection
   - Atomic execution guarantees
   - Real-time price manipulation resistance

## Smart Contract Functions

### Pool Management

#### `create-pool`
Creates a new liquidity pool for a pair of tokens.
```clarity
(define-public (create-pool (token-x <ft-trait>) (token-y <ft-trait>) (fee-rate uint)))
```
- Parameters:
  - `token-x`: First token contract
  - `token-y`: Second token contract
  - `fee-rate`: Trading fee percentage (6 decimal precision)
- Returns: Pool ID

#### `add-liquidity`
Adds liquidity to an existing pool.
```clarity
(define-public (add-liquidity (pool-id uint) (token-x <ft-trait>) (token-y <ft-trait>) (amount-x uint) (amount-y uint) (min-shares uint)))
```
- Parameters:
  - `pool-id`: Target pool identifier
  - `token-x`, `token-y`: Token contracts
  - `amount-x`, `amount-y`: Token amounts to add
  - `min-shares`: Minimum LP tokens to receive
- Returns: Amount of LP tokens minted

#### `remove-liquidity`
Removes liquidity from a pool.
```clarity
(define-public (remove-liquidity (pool-id uint) (token-x <ft-trait>) (token-y <ft-trait>) (shares uint) (min-amount-x uint) (min-amount-y uint)))
```
- Parameters:
  - `pool-id`: Target pool identifier
  - `token-x`, `token-y`: Token contracts
  - `shares`: LP tokens to burn
  - `min-amount-x`, `min-amount-y`: Minimum tokens to receive
- Returns: Amounts of tokens received

### Trading Functions

#### `swap-exact-x-for-y`
Swaps an exact amount of token X for token Y.
```clarity
(define-public (swap-exact-x-for-y (pool-id uint) (token-x <ft-trait>) (token-y <ft-trait>) (amount-in uint) (min-amount-out uint)))
```
- Parameters:
  - `pool-id`: Target pool identifier
  - `token-x`, `token-y`: Token contracts
  - `amount-in`: Exact amount of token X to swap
  - `min-amount-out`: Minimum amount of token Y to receive
- Returns: Amount of token Y received

### Read-Only Functions

#### `get-pool-details`
Retrieves pool information.
```clarity
(define-read-only (get-pool-details (pool-id uint)))
```
- Returns: Pool details including reserves and fee rate

#### `get-provider-shares`
Gets LP token balance for a provider.
```clarity
(define-read-only (get-provider-shares (pool-id uint) (provider principal)))
```
- Returns: Provider's LP token balance

#### `calculate-swap-output`
Calculates expected output amount for a swap.
```clarity
(define-read-only (calculate-swap-output (pool-id uint) (input-amount uint) (is-x-to-y bool)))
```
- Returns: Expected output amount

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Unauthorized operation
- `ERR-INVALID-AMOUNT (u101)`: Invalid amount specified
- `ERR-INSUFFICIENT-BALANCE (u102)`: Insufficient balance
- `ERR-POOL-NOT-FOUND (u103)`: Pool does not exist
- `ERR-SLIPPAGE-TOO-HIGH (u104)`: Slippage exceeds limit
- `ERR-ZERO-LIQUIDITY (u105)`: Pool has no liquidity
- `ERR-DIVIDE-BY-ZERO (u106)`: Division by zero error
- `ERR-CONCURRENT-UPDATE (u107)`: Concurrent update detected

## Security Considerations

1. **Slippage Protection**
   - All swap functions include minimum output parameters
   - Transactions revert if slippage exceeds specified limits

2. **Atomic Execution**
   - All operations are atomic
   - Failed transactions fully revert

3. **Access Control**
   - Pool creation restricted to contract owner
   - Fee updates require owner authorization

4. **Price Manipulation Protection**
   - Real-time price checks
   - Minimum liquidity requirements
   - Concurrent transaction protection
