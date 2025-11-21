(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_STUDY_NOT_FOUND u101)
(define-constant ERR_INSUFFICIENT_FUNDS u102)
(define-constant ERR_ALREADY_CLAIMED u103)
(define-constant ERR_INVALID_STATUS u104)
(define-constant ERR_REPLICATION_NOT_FOUND u105)
(define-constant ERR_NOT_STUDY_AUTHOR u106)
(define-constant ERR_STUDY_EXPIRED u107)
(define-constant ERR_INVALID_RESULT u108)
(define-constant ERR_INVALID_EXTENSION u109)
(define-constant ERR_ALREADY_VOTED u110)
(define-constant ERR_CONSENSUS_NOT_REACHED u111)

(define-constant STATUS_PENDING u0)
(define-constant STATUS_VALIDATED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_CLAIMED u3)

(define-data-var next-study-id uint u1)
(define-data-var next-replication-id uint u1)
(define-data-var platform-fee uint u250)
(define-data-var consensus-threshold uint u2)

(define-map studies
  uint
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
)

(define-map replications
  uint
  {
    study-id: uint,
    researcher: principal,
    result-hash: (string-ascii 64),
    status: uint,
    submitted-at: uint,
    validated-at: (optional uint),
    validator: (optional principal)
  }
)

(define-map study-replications
  {study-id: uint, researcher: principal}
  uint
)

(define-map researcher-stats
  principal
  {
    total-replications: uint,
    successful-replications: uint,
    total-rewards: uint
  }
)

(define-map validators
  principal
  bool
)

(define-map replication-votes
  {replication-id: uint, validator: principal}
  {vote: bool, voted-at: uint}
)

(define-map replication-vote-counts
  uint
  {approve-count: uint, reject-count: uint, total-validators: uint}
)

(define-public (initialize-platform)
  (begin
    (asserts! (is-eq tx-sender (var-get platform-owner)) (err ERR_NOT_AUTHORIZED))
    (map-set validators tx-sender true)
    (ok true)
  )
)

(define-data-var platform-owner principal tx-sender)

(define-public (add-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-owner)) (err ERR_NOT_AUTHORIZED))
    (map-set validators validator true)
    (ok true)
  )
)

(define-public (remove-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-owner)) (err ERR_NOT_AUTHORIZED))
    (map-delete validators validator)
    (ok true)
  )
)

(define-public (create-study 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (bounty-amount uint)
  (duration-blocks uint)
)
  (let
    (
      (study-id (var-get next-study-id))
      (deadline (+ burn-block-height duration-blocks))
    )
    (asserts! (> bounty-amount u0) (err ERR_INSUFFICIENT_FUNDS))
    (try! (stx-transfer? bounty-amount tx-sender (as-contract tx-sender)))
    
    (map-set studies study-id
      {
        author: tx-sender,
        title: title,
        description: description,
        bounty-amount: bounty-amount,
        deadline: deadline,
        status: STATUS_PENDING,
        created-at: burn-block-height,
        validator: none
      }
    )
    
    (var-set next-study-id (+ study-id u1))
    (ok study-id)
  )
)

(define-public (submit-replication
  (study-id uint)
  (result-hash (string-ascii 64))
)
  (let
    (
      (study (unwrap! (map-get? studies study-id) (err ERR_STUDY_NOT_FOUND)))
      (replication-id (var-get next-replication-id))
    )
    (asserts! (< burn-block-height (get deadline study)) (err ERR_STUDY_EXPIRED))
    (asserts! (is-none (map-get? study-replications {study-id: study-id, researcher: tx-sender}))
              (err ERR_ALREADY_CLAIMED))
    
    (map-set replications replication-id
      {
        study-id: study-id,
        researcher: tx-sender,
        result-hash: result-hash,
        status: STATUS_PENDING,
        submitted-at: burn-block-height,
        validated-at: none,
        validator: none
      }
    )
    
    (map-set study-replications {study-id: study-id, researcher: tx-sender} replication-id)
    
    (let ((current-stats (default-to {total-replications: u0, successful-replications: u0, total-rewards: u0}
                                   (map-get? researcher-stats tx-sender))))
      (map-set researcher-stats tx-sender
        (merge current-stats {total-replications: (+ (get total-replications current-stats) u1)}))
    )
    
    (var-set next-replication-id (+ replication-id u1))
    (ok replication-id)
  )
)

(define-public (validate-replication
  (replication-id uint)
  (is-valid bool)
)
  (let
    (
      (replication (unwrap! (map-get? replications replication-id) (err ERR_REPLICATION_NOT_FOUND)))
      (study-id (get study-id replication))
      (researcher (get researcher replication))
    )
    (asserts! (default-to false (map-get? validators tx-sender)) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq (get status replication) STATUS_PENDING) (err ERR_INVALID_STATUS))
    
    (let ((new-status (if is-valid STATUS_VALIDATED STATUS_REJECTED)))
      (map-set replications replication-id
        (merge replication
          {
            status: new-status,
            validated-at: (some burn-block-height),
            validator: (some tx-sender)
          }
        )
      )
      
      (if is-valid
        (let ((current-stats (default-to {total-replications: u0, successful-replications: u0, total-rewards: u0}
                                       (map-get? researcher-stats researcher))))
          (map-set researcher-stats researcher
            (merge current-stats {successful-replications: (+ (get successful-replications current-stats) u1)}))
        )
        true
      )
      
      (ok new-status)
    )
  )
)

(define-public (claim-reward (replication-id uint))
  (let
    (
      (replication (unwrap! (map-get? replications replication-id) (err ERR_REPLICATION_NOT_FOUND)))
      (study-id (get study-id replication))
      (study (unwrap! (map-get? studies study-id) (err ERR_STUDY_NOT_FOUND)))
    )
    (asserts! (is-eq tx-sender (get researcher replication)) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq (get status replication) STATUS_VALIDATED) (err ERR_INVALID_STATUS))
    
    (let
      (
        (bounty-amount (get bounty-amount study))
        (fee-amount (/ (* bounty-amount (var-get platform-fee)) u10000))
        (reward-amount (- bounty-amount fee-amount))
      )
      
      (try! (as-contract (stx-transfer? reward-amount tx-sender (get researcher replication))))
      (try! (as-contract (stx-transfer? fee-amount tx-sender (var-get platform-owner))))
      
      (map-set replications replication-id
        (merge replication {status: STATUS_CLAIMED})
      )
      
      (let ((current-stats (default-to {total-replications: u0, successful-replications: u0, total-rewards: u0}
                                     (map-get? researcher-stats tx-sender))))
        (map-set researcher-stats tx-sender
          (merge current-stats {total-rewards: (+ (get total-rewards current-stats) reward-amount)}))
      )
      
      (ok reward-amount)
    )
  )
)

(define-public (extend-bounty
  (study-id uint)
  (additional-amount uint)
  (additional-blocks uint)
)
  (let
    (
      (study (unwrap! (map-get? studies study-id) (err ERR_STUDY_NOT_FOUND)))
      (new-bounty (+ (get bounty-amount study) additional-amount))
      (new-deadline (+ (get deadline study) additional-blocks))
    )
    (asserts! (is-eq tx-sender (get author study)) (err ERR_NOT_STUDY_AUTHOR))
    (asserts! (is-eq (get status study) STATUS_PENDING) (err ERR_INVALID_STATUS))
    (asserts! (> additional-amount u0) (err ERR_INVALID_EXTENSION))
    (asserts! (<= burn-block-height (get deadline study)) (err ERR_STUDY_EXPIRED))
    
    (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
    
    (map-set studies study-id
      (merge study
        {
          bounty-amount: new-bounty,
          deadline: new-deadline
        }
      )
    )
    
    (ok {new-bounty: new-bounty, new-deadline: new-deadline})
  )
)

(define-public (withdraw-expired-bounty (study-id uint))
  (let
    (
      (study (unwrap! (map-get? studies study-id) (err ERR_STUDY_NOT_FOUND)))
    )
    (asserts! (is-eq tx-sender (get author study)) (err ERR_NOT_STUDY_AUTHOR))
    (asserts! (> burn-block-height (get deadline study)) (err ERR_STUDY_EXPIRED))
    
    (try! (as-contract (stx-transfer? (get bounty-amount study) tx-sender (get author study))))
    
    (map-set studies study-id
      (merge study {status: STATUS_REJECTED})
    )
    
    (ok (get bounty-amount study))
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-owner)) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= new-fee u1000) (err ERR_INVALID_RESULT))
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-read-only (get-study (study-id uint))
  (map-get? studies study-id)
)

(define-read-only (get-replication (replication-id uint))
  (map-get? replications replication-id)
)

(define-read-only (get-researcher-replication (study-id uint) (researcher principal))
  (match (map-get? study-replications {study-id: study-id, researcher: researcher})
    replication-id (map-get? replications replication-id)
    none
  )
)

(define-read-only (get-researcher-stats (researcher principal))
  (default-to {total-replications: u0, successful-replications: u0, total-rewards: u0}
              (map-get? researcher-stats researcher))
)

(define-read-only (is-validator (validator principal))
  (default-to false (map-get? validators validator))
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (get-platform-owner)
  (var-get platform-owner)
)

(define-read-only (get-next-study-id)
  (var-get next-study-id)
)

(define-read-only (get-next-replication-id)
  (var-get next-replication-id)
)

(define-public (vote-on-replication
  (replication-id uint)
  (approve bool)
)
  (let
    (
      (replication (unwrap! (map-get? replications replication-id) (err ERR_REPLICATION_NOT_FOUND)))
      (vote-key {replication-id: replication-id, validator: tx-sender})
      (vote-counts (default-to {approve-count: u0, reject-count: u0, total-validators: u0}
                               (map-get? replication-vote-counts replication-id)))
      (threshold (var-get consensus-threshold))
    )
    (asserts! (default-to false (map-get? validators tx-sender)) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq (get status replication) STATUS_PENDING) (err ERR_INVALID_STATUS))
    (asserts! (is-none (map-get? replication-votes vote-key)) (err ERR_ALREADY_VOTED))
    
    (map-set replication-votes vote-key
      {vote: approve, voted-at: burn-block-height}
    )
    
    (let
      (
        (new-approve-count (if approve (+ (get approve-count vote-counts) u1) (get approve-count vote-counts)))
        (new-reject-count (if approve (get reject-count vote-counts) (+ (get reject-count vote-counts) u1)))
        (new-total (+ (get total-validators vote-counts) u1))
      )
      (map-set replication-vote-counts replication-id
        {approve-count: new-approve-count, reject-count: new-reject-count, total-validators: new-total}
      )
      
      (if (>= new-approve-count threshold)
        (begin
          (map-set replications replication-id
            (merge replication
              {
                status: STATUS_VALIDATED,
                validated-at: (some burn-block-height),
                validator: (some tx-sender)
              }
            )
          )
          (let
            (
              (researcher (get researcher replication))
              (current-stats (default-to {total-replications: u0, successful-replications: u0, total-rewards: u0}
                                         (map-get? researcher-stats researcher)))
            )
            (map-set researcher-stats researcher
              (merge current-stats {successful-replications: (+ (get successful-replications current-stats) u1)}))
          )
          (ok {status: STATUS_VALIDATED, approve-count: new-approve-count, reject-count: new-reject-count})
        )
        (if (>= new-reject-count threshold)
          (begin
            (map-set replications replication-id
              (merge replication
                {
                  status: STATUS_REJECTED,
                  validated-at: (some burn-block-height),
                  validator: (some tx-sender)
                }
              )
            )
            (ok {status: STATUS_REJECTED, approve-count: new-approve-count, reject-count: new-reject-count})
          )
          (ok {status: STATUS_PENDING, approve-count: new-approve-count, reject-count: new-reject-count})
        )
      )
    )
  )
)

(define-public (set-consensus-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-owner)) (err ERR_NOT_AUTHORIZED))
    (asserts! (> new-threshold u0) (err ERR_INVALID_RESULT))
    (var-set consensus-threshold new-threshold)
    (ok true)
  )
)

(define-read-only (get-replication-votes (replication-id uint))
  (default-to {approve-count: u0, reject-count: u0, total-validators: u0}
              (map-get? replication-vote-counts replication-id))
)

(define-read-only (get-validator-vote (replication-id uint) (validator principal))
  (map-get? replication-votes {replication-id: replication-id, validator: validator})
)

(define-read-only (get-consensus-threshold)
  (var-get consensus-threshold)
)
