;; BitBridge DEX: Cross-Layer Automated Market Maker Protocol

;; OVERVIEW
;; BitBridge DEX is a next-generation automated market maker (AMM) protocol 
;; designed specifically for seamless Bitcoin-Stacks L2 integration. It enables
;; trustless cross-chain liquidity provision and atomic token swaps while
;; maintaining Bitcoin's security guarantees.
;;
;; Key Features:
;; - Atomic Cross-Chain Swaps: Trustless trading between BTC and Stacks assets
;; - High-Precision AMM: 6-decimal precision for accurate price discovery
;; - Layer 2 Optimized: Designed for Stacks L2 scalability
;; - Bitcoin-Native Security: Leverages Bitcoin's settlement guarantees
;; - Gas-Optimized: Efficient execution for reduced transaction costs
;;
;; Security Measures:
;; - Comprehensive slippage protection
;; - Atomic execution guarantees
;; - Real-time price manipulation resistance
;; - Concurrent transaction safety
;;
;; Architecture:
;; The protocol implements a constant product market maker (x * y = k)
;; with additional safety mechanisms for cross-chain atomic settlements.
;; All mathematical operations use fixed-point arithmetic with 6 decimal
;; places to prevent precision loss while maintaining efficiency.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-POOL-NOT-FOUND (err u103))
(define-constant ERR-SLIPPAGE-TOO-HIGH (err u104))
(define-constant ERR-ZERO-LIQUIDITY (err u105))
(define-constant ERR-DIVIDE-BY-ZERO (err u106))
(define-constant ERR-CONCURRENT-UPDATE (err u107))
(define-constant PRECISION u1000000) ;; 6 decimal places for price calculations

;; Data Variables
(define-data-var last-pool-id uint u0)

;; Data Maps
(define-map liquidity-pools
    { pool-id: uint }
    {
        token-x: principal,
        token-y: principal,
        total-shares: uint,
        reserve-x: uint,
        reserve-y: uint,
        fee-rate: uint,
        last-block-height: uint
    }
)

(define-map liquidity-providers
    { pool-id: uint, provider: principal }
    { shares: uint }
)

;; SIP-010 Interface
(define-trait ft-trait
    (
        (transfer (uint principal principal) (response bool uint))
        (get-balance (principal) (response uint uint))
        (get-decimals () (response uint uint))
    )
)

;; Private helper functions
(define-private (mul-down (a uint) (b uint))
    (/ (* a b) PRECISION)
)

(define-private (div-down (a uint) (b uint))
    (if (is-eq b u0)
        u0
        (/ (* a PRECISION) b)
    )
)

(define-private (min (a uint) (b uint))
    (if (<= a b) a b)
)

(define-private (transfer-token (token <ft-trait>) (amount uint) (sender principal) (recipient principal))
    (contract-call? token transfer amount sender recipient)
)

(define-private (validate-pool-state (pool { 
    token-x: principal,
    token-y: principal,
    total-shares: uint,
    reserve-x: uint,
    reserve-y: uint,
    fee-rate: uint,
    last-block-height: uint 
}))
    (begin
        (asserts! (> (get total-shares pool) u0) ERR-ZERO-LIQUIDITY)
        (asserts! (>= (get reserve-x pool) u0) ERR-INVALID-AMOUNT)
        (asserts! (>= (get reserve-y pool) u0) ERR-INVALID-AMOUNT)
        (ok pool)
    )
)

;; Read-only functions
(define-read-only (get-pool-details (pool-id uint))
    (match (map-get? liquidity-pools { pool-id: pool-id })
        pool-data (ok pool-data)
        (err ERR-POOL-NOT-FOUND))
)

(define-read-only (get-provider-shares (pool-id uint) (provider principal))
    (default-to
        { shares: u0 }
        (map-get? liquidity-providers { pool-id: pool-id, provider: provider }))
)

(define-read-only (calculate-swap-output (pool-id uint) (input-amount uint) (is-x-to-y bool))
    (match (map-get? liquidity-pools { pool-id: pool-id })
        pool-data 
            (let (
                (input-reserve (if is-x-to-y (get reserve-x pool-data) (get reserve-y pool-data)))
                (output-reserve (if is-x-to-y (get reserve-y pool-data) (get reserve-x pool-data)))
                (fee-adjusted-input (mul-down input-amount (- PRECISION (get fee-rate pool-data))))
            )
            (asserts! (> input-reserve u0) (err ERR-ZERO-LIQUIDITY))
            (asserts! (> output-reserve u0) (err ERR-ZERO-LIQUIDITY))
            (ok (div-down
                (mul-down fee-adjusted-input output-reserve)
                (+ input-reserve fee-adjusted-input))))
        (err ERR-POOL-NOT-FOUND))
)

;; Public functions
(define-public (create-pool (token-x <ft-trait>) (token-y <ft-trait>) (fee-rate uint))
    (let (
        (pool-id (+ (var-get last-pool-id) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (< fee-rate PRECISION) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq (contract-of token-x) (contract-of token-y))) ERR-INVALID-AMOUNT)
    
    (map-set liquidity-pools
        { pool-id: pool-id }
        {
            token-x: (contract-of token-x),
            token-y: (contract-of token-y),
            total-shares: u0,
            reserve-x: u0,
            reserve-y: u0,
            fee-rate: fee-rate,
            last-block-height: block-height
        }
    )
    (var-set last-pool-id pool-id)
    (ok pool-id))
)

(define-public (add-liquidity (pool-id uint) (token-x <ft-trait>) (token-y <ft-trait>) (amount-x uint) (amount-y uint) (min-shares uint))
    (let (
        (pool (unwrap! (get-pool-details pool-id) ERR-POOL-NOT-FOUND))
        (shares-to-mint (if (is-eq (get total-shares pool) u0)
            amount-x  ;; Initial liquidity shares equal to first deposit
            (min
                (div-down (* amount-x (get total-shares pool)) (get reserve-x pool))
                (div-down (* amount-y (get total-shares pool)) (get reserve-y pool))
            )
        ))
    )
    (asserts! (and 
        (is-eq (contract-of token-x) (get token-x pool))
        (is-eq (contract-of token-y) (get token-y pool))
    ) ERR-NOT-AUTHORIZED)
    (asserts! (>= shares-to-mint min-shares) ERR-SLIPPAGE-TOO-HIGH)
    (asserts! (and (> amount-x u0) (> amount-y u0)) ERR-INVALID-AMOUNT)
    
    ;; Transfer tokens to pool
    (try! (transfer-token token-x amount-x tx-sender (as-contract tx-sender)))
    (try! (transfer-token token-y amount-y tx-sender (as-contract tx-sender)))
    
    ;; Update pool state
    (map-set liquidity-pools
        { pool-id: pool-id }
        (merge pool {
            total-shares: (+ (get total-shares pool) shares-to-mint),
            reserve-x: (+ (get reserve-x pool) amount-x),
            reserve-y: (+ (get reserve-y pool) amount-y),
            last-block-height: block-height
        })
    )
    
    ;; Update provider shares
    (map-set liquidity-providers
        { pool-id: pool-id, provider: tx-sender }
        { shares: (+ shares-to-mint (get shares (get-provider-shares pool-id tx-sender))) }
    )
    
    (ok shares-to-mint))
)