;; CreatorRoyaltyHub - Creator royalty distribution and rights management
(define-data-var rights-administrator principal tx-sender)
(define-data-var total-royalty-pool uint u0)
(define-data-var distribution-rate uint u35)
(define-data-var last-distribution-cycle uint u0)

(define-map creator-earnings principal uint)
(define-map content-licenses principal (string-utf8 64))
(define-map registered-licenses (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-admin (err u8200))
(define-constant err-admin-already-set (err u8201))
(define-constant err-invalid-royalty-amount (err u8202))
(define-constant err-insufficient-royalty-balance (err u8203))
(define-constant err-no-creator-earnings (err u8204))
(define-constant err-invalid-license-type (err u8205))
(define-constant err-license-not-registered (err u8206))

;; Verify rights administrator
(define-private (is-rights-admin (caller principal))
  (begin
    (asserts! (is-eq caller (var-get rights-administrator)) err-unauthorized-admin)
    (ok true)))

;; Initialize creator royalty platform
(define-public (launch-royalty-platform (administrator principal))
  (begin
    (asserts! (is-none (map-get? creator-earnings administrator)) err-admin-already-set)
    (var-set rights-administrator administrator)
    (ok "CreatorRoyaltyHub platform launched")))

;; Register content license type
(define-public (register-content-license (license-type (string-utf8 64)))
  (begin
    (try! (is-rights-admin tx-sender))
    (asserts! (> (len license-type) u0) err-invalid-license-type)
    (map-set registered-licenses license-type true)
    (ok "Content license registered")))

;; Record creator royalty earnings
(define-public (record-creator-royalty (royalty-amount uint) (license-type (string-utf8 64)))
  (begin
    (asserts! (> royalty-amount u0) err-invalid-royalty-amount)
    (asserts! (default-to false (map-get? registered-licenses license-type)) err-license-not-registered)
    
    (let ((current-earnings (default-to u0 (map-get? creator-earnings tx-sender))))
      (map-set creator-earnings tx-sender (+ current-earnings royalty-amount))
      (map-set content-licenses tx-sender license-type)
      (var-set total-royalty-pool (+ (var-get total-royalty-pool) royalty-amount))
      (ok (+ current-earnings royalty-amount)))))

;; Execute royalty distribution cycle
(define-public (execute-distribution-cycle)
  (begin
    (try! (is-rights-admin tx-sender))
    (let ((cycle-count (+ (var-get last-distribution-cycle) u1))
          (pool-balance (var-get total-royalty-pool)))
      (asserts! (> pool-balance (var-get last-distribution-cycle)) err-insufficient-royalty-balance)
      
      (let ((distribution-amount (* (var-get distribution-rate) pool-balance)))
        (var-set last-distribution-cycle cycle-count)
        (ok distribution-amount)))))

;; Claim creator royalty rewards
(define-public (claim-creator-royalties)
  (begin
    (let ((creator-balance (default-to u0 (map-get? creator-earnings tx-sender))))
      (asserts! (> creator-balance u0) err-no-creator-earnings)
      
      (let ((total-pool (var-get total-royalty-pool))
            (base-distribution (* (var-get distribution-rate) creator-balance))
            (creator-share (/ (* creator-balance u100000) total-pool)))
        
        (let ((final-royalty-payout (/ (* creator-share base-distribution) u100000)))
          (map-delete creator-earnings tx-sender)
          (map-delete content-licenses tx-sender)
          (var-set total-royalty-pool (- (var-get total-royalty-pool) creator-balance))
          (ok (+ creator-balance final-royalty-payout)))))))

;; Read-only functions
(define-read-only (get-creator-earnings (creator principal))
  (default-to u0 (map-get? creator-earnings creator)))

(define-read-only (get-content-license (creator principal))
  (map-get? content-licenses creator))

(define-read-only (get-total-royalty-pool)
  (var-get total-royalty-pool))

(define-read-only (is-license-registered (license-type (string-utf8 64)))
  (default-to false (map-get? registered-licenses license-type)))