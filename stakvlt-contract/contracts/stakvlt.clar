;; ============================================================
;; P2P sBTC Lending Marketplace
;; Project: Stakvlt (Pivot)
;; Language: Clarity (Stacks Blockchain)
;; Description: A trustless peer-to-peer lending contract where
;;   lenders offer sBTC loans, borrowers lock collateral, and
;;   repayment/default is enforced automatically by the contract.
;; ============================================================

;; ============================================================
;; CONSTANTS
;; ============================================================

;; Contract owner (deployer)
(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u102))
(define-constant ERR-LOAN-NOT-ACTIVE (err u103))
(define-constant ERR-NOT-AUTHORIZED (err u104))
(define-constant ERR-DEADLINE-NOT-PASSED (err u105))
(define-constant ERR-DEADLINE-PASSED (err u106))
(define-constant ERR-LOAN-ALREADY-TAKEN (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))

;; Collateral ratio: borrower must lock 150% of loan value
;; e.g. borrow 100 sats  lock 150 sats as collateral
(define-constant COLLATERAL-RATIO u150)

;; Loan duration in blocks (~30 days on Stacks = ~4320 blocks)
(define-constant LOAN-DURATION-BLOCKS u4320)

;; sBTC Token Contract (Stacks mainnet address)
(define-constant SBTC-TOKEN 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)

;; ============================================================
;; DATA STRUCTURES
;; ============================================================

;; Loan offer created by a lender
(define-map loan-offers
  { loan-id: uint }
  {
    lender: principal, ;; wallet address of lender
    amount: uint, ;; loan amount in satoshis
    interest-rate: uint, ;; interest in basis points (e.g. 500 = 5%)
    collateral-required: uint, ;; collateral amount in satoshis (150% of loan)
    is-taken: bool, ;; has a borrower accepted this offer?
    is-active: bool, ;; is this offer still open?
  }
)

;; Active loan between lender and borrower
(define-map active-loans
  { loan-id: uint }
  {
    borrower: principal, ;; wallet address of borrower
    lender: principal, ;; wallet address of lender
    loan-amount: uint, ;; amount borrowed in satoshis
    collateral-amount: uint, ;; collateral locked in satoshis
    repayment-amount: uint, ;; total due (principal + interest) in satoshis
    start-block: uint, ;; block when loan started
    deadline-block: uint, ;; block when loan expires
    is-repaid: bool, ;; has borrower repaid?
    is-defaulted: bool, ;; has loan been defaulted/liquidated?
  }
)

;; Counter to generate unique loan IDs
(define-data-var loan-counter uint u0)

;; ============================================================
;; PRIVATE HELPER FUNCTIONS
;; ============================================================

;; Calculate collateral required for a given loan amount
;; collateral = (loan-amount * 150) / 100
(define-private (calculate-collateral (loan-amount uint))
  (/ (* loan-amount COLLATERAL-RATIO) u100)
)

;; Calculate total repayment amount (principal + interest)
;; interest-rate is in basis points: 500 = 5%
;; repayment = loan-amount + (loan-amount * interest-rate / 10000)
(define-private (calculate-repayment
    (loan-amount uint)
    (interest-rate uint)
  )
  (+ loan-amount (/ (* loan-amount interest-rate) u10000))
)

;; Get next loan ID and increment counter
(define-private (get-next-loan-id)
  (let ((current-id (var-get loan-counter)))
    (var-set loan-counter (+ current-id u1))
    current-id
  )
)

;; ============================================================
;; PUBLIC FUNCTIONS
;; ============================================================

;; ------------------------------------------------------------
;; STEP 1: Lender creates a loan offer
;; Lender deposits sBTC into the contract to make it available
;; ------------------------------------------------------------
(define-public (create-loan-offer
    (amount uint)
    (interest-rate uint)
  )
  (let (
      (loan-id (get-next-loan-id))
      (collateral-needed (calculate-collateral amount))
    )
    ;; Transfer lender's sBTC into the contract escrow
    (try! (contract-call? SBTC-TOKEN transfer amount tx-sender (as-contract tx-sender)
      none
    ))

    ;; Store the loan offer
    (map-set loan-offers { loan-id: loan-id } {
      lender: tx-sender,
      amount: amount,
      interest-rate: interest-rate,
      collateral-required: collateral-needed,
      is-taken: false,
      is-active: true,
    })

    ;; Return the loan ID so the lender knows their offer ID
    (ok loan-id)
  )
)

;; ------------------------------------------------------------
;; STEP 2: Borrower accepts a loan offer
;; Borrower deposits collateral  receives the loan amount
;; ------------------------------------------------------------
(define-public (accept-loan (loan-id uint))
  (let (
      (offer (unwrap! (map-get? loan-offers { loan-id: loan-id }) ERR-NOT-FOUND))
      (loan-amount (get amount offer))
      (collateral-needed (get collateral-required offer))
      (repayment-due (calculate-repayment loan-amount (get interest-rate offer)))
      (deadline (+ block-height LOAN-DURATION-BLOCKS))
    )
    ;; Check offer is still open
    (asserts! (get is-active offer) ERR-LOAN-NOT-ACTIVE)
    (asserts! (not (get is-taken offer)) ERR-LOAN-ALREADY-TAKEN)

    ;; Borrower deposits collateral into contract
    (try! (contract-call? SBTC-TOKEN transfer collateral-needed tx-sender
      (as-contract tx-sender) none
    ))

    ;; Contract sends loan amount to borrower
    (try! (as-contract (contract-call? SBTC-TOKEN transfer loan-amount tx-sender tx-sender none)))

    ;; Mark offer as taken
    (map-set loan-offers { loan-id: loan-id }
      (merge offer {
        is-taken: true,
        is-active: false,
      })
    )

    ;; Create active loan record
    (map-set active-loans { loan-id: loan-id } {
      borrower: tx-sender,
      lender: (get lender offer),
      loan-amount: loan-amount,
      collateral-amount: collateral-needed,
      repayment-amount: repayment-due,
      start-block: block-height,
      deadline-block: deadline,
      is-repaid: false,
      is-defaulted: false,
    })

    (ok loan-id)
  )
)

;; ------------------------------------------------------------
;; STEP 3: Borrower repays the loan before deadline
;; Borrower sends repayment  gets collateral back
;; ------------------------------------------------------------
(define-public (repay-loan (loan-id uint))
  (let (
      (loan (unwrap! (map-get? active-loans { loan-id: loan-id }) ERR-NOT-FOUND))
      (repayment-amount (get repayment-amount loan))
      (collateral-amount (get collateral-amount loan))
      (lender (get lender loan))
    )
    ;; Only the borrower can repay
    (asserts! (is-eq tx-sender (get borrower loan)) ERR-NOT-AUTHORIZED)

    ;; Loan must not already be repaid or defaulted
    (asserts! (not (get is-repaid loan)) ERR-LOAN-NOT-ACTIVE)
    (asserts! (not (get is-defaulted loan)) ERR-LOAN-NOT-ACTIVE)

    ;; Must repay before deadline
    (asserts! (<= block-height (get deadline-block loan)) ERR-DEADLINE-PASSED)

    ;; Borrower sends repayment to contract
    (try! (contract-call? SBTC-TOKEN transfer repayment-amount tx-sender
      (as-contract tx-sender) none
    ))

    ;; Contract forwards repayment to lender
    (try! (as-contract (contract-call? SBTC-TOKEN transfer repayment-amount tx-sender lender none)))

    ;; Contract returns collateral to borrower
    (try! (as-contract (contract-call? SBTC-TOKEN transfer collateral-amount tx-sender
      (get borrower loan) none
    )))

    ;; Mark loan as repaid
    (map-set active-loans { loan-id: loan-id } (merge loan { is-repaid: true }))

    (ok true)
  )
)

;; ------------------------------------------------------------
;; STEP 4: Liquidate a defaulted loan (anyone can trigger)
;; If deadline passed and no repayment  lender gets collateral
;; ------------------------------------------------------------
(define-public (liquidate-loan (loan-id uint))
  (let (
      (loan (unwrap! (map-get? active-loans { loan-id: loan-id }) ERR-NOT-FOUND))
      (collateral-amount (get collateral-amount loan))
      (lender (get lender loan))
    )
    ;; Loan must not already be settled
    (asserts! (not (get is-repaid loan)) ERR-LOAN-NOT-ACTIVE)
    (asserts! (not (get is-defaulted loan)) ERR-LOAN-NOT-ACTIVE)

    ;; Deadline must have passed
    (asserts! (> block-height (get deadline-block loan)) ERR-DEADLINE-NOT-PASSED)

    ;; Contract sends collateral to lender as compensation
    (try! (as-contract (contract-call? SBTC-TOKEN transfer collateral-amount tx-sender lender none)))

    ;; Mark loan as defaulted
    (map-set active-loans { loan-id: loan-id }
      (merge loan { is-defaulted: true })
    )

    (ok true)
  )
)

;; ------------------------------------------------------------
;; STEP 5: Lender cancels an untaken offer and gets sBTC back
;; ------------------------------------------------------------
(define-public (cancel-offer (loan-id uint))
  (let ((offer (unwrap! (map-get? loan-offers { loan-id: loan-id }) ERR-NOT-FOUND)))
    ;; Only the lender can cancel
    (asserts! (is-eq tx-sender (get lender offer)) ERR-NOT-AUTHORIZED)

    ;; Can only cancel if not yet taken
    (asserts! (not (get is-taken offer)) ERR-LOAN-ALREADY-TAKEN)
    (asserts! (get is-active offer) ERR-LOAN-NOT-ACTIVE)

    ;; Return lender's sBTC
    (try! (as-contract (contract-call? SBTC-TOKEN transfer (get amount offer) tx-sender
      (get lender offer) none
    )))

    ;; Deactivate the offer
    (map-set loan-offers { loan-id: loan-id } (merge offer { is-active: false }))

    (ok true)
  )
)

;; ============================================================
;; READ-ONLY FUNCTIONS (for the frontend UI)
;; ============================================================

;; Get details of a loan offer
(define-read-only (get-loan-offer (loan-id uint))
  (map-get? loan-offers { loan-id: loan-id })
)

;; Get details of an active loan
(define-read-only (get-active-loan (loan-id uint))
  (map-get? active-loans { loan-id: loan-id })
)

;; Get total number of loans created
(define-read-only (get-loan-count)
  (var-get loan-counter)
)

;; Check if a loan is past its deadline
(define-read-only (is-loan-overdue (loan-id uint))
  (match (map-get? active-loans { loan-id: loan-id })
    loan (> block-height (get deadline-block loan))
    false
  )
)

;; Calculate what a borrower owes for a given loan amount and rate
(define-read-only (preview-repayment
    (loan-amount uint)
    (interest-rate uint)
  )
  (calculate-repayment loan-amount interest-rate)
)

;; Calculate collateral needed for a given loan amount
(define-read-only (preview-collateral (loan-amount uint))
  (calculate-collateral loan-amount)
)
