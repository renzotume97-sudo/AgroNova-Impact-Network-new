(define-data-var contract-owner principal tx-sender)
(define-data-var next-farmer-id uint u1)
(define-data-var next-project-id uint u1)
(define-data-var next-pledge-id uint u1)
(define-data-var total-supply uint u0)

(define-map farmers
  { id: uint }
  { owner: principal, name: (string-ascii 50), region: (string-ascii 50), active: bool })

(define-map farmer-by-owner
  { owner: principal }
  { id: uint })

(define-map projects
  { id: uint }
  { owner: principal, title: (string-ascii 70), description: (string-ascii 140), impact-score: uint, active: bool, start-height: uint, end-height: (optional uint) })

(define-map pledges
  { id: uint }
  { project-id: uint, backer: principal, amount: uint, claimed: bool })

(define-map balances
  { owner: principal }
  { amount: uint })

(define-map impact-oracles
  { oracle: principal }
  { enabled: bool })

(define-constant err-not-owner (err u100))
(define-constant err-farmer-exists (err u101))
(define-constant err-farmer-not-found (err u102))
(define-constant err-not-farmer (err u103))
(define-constant err-project-not-found (err u104))
(define-constant err-project-inactive (err u105))
(define-constant err-not-oracle (err u106))
(define-constant err-insufficient-balance (err u107))
(define-constant err-pledge-not-found (err u108))
(define-constant err-pledge-claimed (err u109))
(define-constant err-project-active (err u110))
(define-constant err-zero-amount (err u111))

(define-private (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

(define-private (get-balance-internal (owner principal))
  (default-to u0 (get amount (map-get? balances { owner: owner }))))

(define-public (admin-mint (to principal) (amount uint))
  (begin
    (if (not (is-owner tx-sender))
        err-not-owner
        (if (<= amount u0)
            err-zero-amount
            (let ((current (get-balance-internal to))
                  (supply (var-get total-supply)))
              (map-set balances { owner: to } { amount: (+ current amount) })
              (var-set total-supply (+ supply amount))
              (ok true))))))

(define-public (transfer-token (to principal) (amount uint))
  (begin
    (if (<= amount u0)
        err-zero-amount
        (let ((from-bal (get-balance-internal tx-sender)))
          (if (< from-bal amount)
              err-insufficient-balance
              (let ((to-bal (get-balance-internal to)))
                (map-set balances { owner: tx-sender } { amount: (- from-bal amount) })
                (map-set balances { owner: to } { amount: (+ to-bal amount) })
                (ok true)))))))

(define-public (admin-set-oracle (oracle principal) (enabled bool))
  (begin
    (if (not (is-owner tx-sender))
        err-not-owner
        (begin
          (map-set impact-oracles { oracle: oracle } { enabled: enabled })
          (ok true)))))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-balance (owner principal))
  (ok (get-balance-internal owner)))

(define-read-only (is-oracle (oracle principal))
  (ok (default-to false (get enabled (map-get? impact-oracles { oracle: oracle })))))

(define-public (register-farmer (name (string-ascii 50)) (region (string-ascii 50)))
  (let ((existing (map-get? farmer-by-owner { owner: tx-sender })))
    (if (is-some existing)
        err-farmer-exists
        (let ((id (var-get next-farmer-id))
              (height stacks-block-height))
          (var-set next-farmer-id (+ id u1))
          (map-set farmers { id: id } { owner: tx-sender, name: name, region: region, active: true })
          (map-set farmer-by-owner { owner: tx-sender } { id: id })
          (ok { id: id, registered-height: height })))))

(define-public (update-farmer (name (string-ascii 50)) (region (string-ascii 50)) (active bool))
  (let ((entry (map-get? farmer-by-owner { owner: tx-sender })))
    (if (is-none entry)
        err-farmer-not-found
        (let ((id (get id (unwrap-panic entry))))
          (map-set farmers { id: id } { owner: tx-sender, name: name, region: region, active: active })
          (ok true)))))

(define-read-only (get-farmer-by-id (id uint))
  (match (map-get? farmers { id: id })
    entry (ok entry)
    (err u1)))

(define-read-only (get-farmer-by-owner-view (owner principal))
  (match (map-get? farmer-by-owner { owner: owner })
    entry (ok entry)
    (err u1)))

(define-public (create-project (title (string-ascii 70)) (description (string-ascii 140)))
  (let ((entry (map-get? farmer-by-owner { owner: tx-sender })))
    (if (is-none entry)
        err-not-farmer
        (let ((id (var-get next-project-id))
              (height stacks-block-height))
          (var-set next-project-id (+ id u1))
          (map-set projects { id: id }
            { owner: tx-sender,
              title: title,
              description: description,
              impact-score: u0,
              active: true,
              start-height: height,
              end-height: none })
          (ok id)))))

(define-public (close-project (project-id uint))
  (let ((project (map-get? projects { id: project-id })))
    (if (is-none project)
        err-project-not-found
        (let ((p (unwrap-panic project))
              (height stacks-block-height))
          (if (not (and (is-eq (get owner p) tx-sender) (get active p)))
              err-project-inactive
              (begin
                (map-set projects { id: project-id }
                  { owner: (get owner p),
                    title: (get title p),
                    description: (get description p),
                    impact-score: (get impact-score p),
                    active: false,
                    start-height: (get start-height p),
                    end-height: (some height) })
                (ok true)))))))

(define-public (record-impact (project-id uint) (impact-score uint))
  (let ((oracle-entry (map-get? impact-oracles { oracle: tx-sender })))
    (if (or (is-none oracle-entry) (not (get enabled (unwrap-panic oracle-entry))))
        err-not-oracle
        (let ((project (map-get? projects { id: project-id })))
          (if (is-none project)
              err-project-not-found
              (let ((p (unwrap-panic project)))
                (if (not (get active p))
                    err-project-inactive
                    (begin
                      (map-set projects { id: project-id }
                        { owner: (get owner p),
                          title: (get title p),
                          description: (get description p),
                          impact-score: impact-score,
                          active: (get active p),
                          start-height: (get start-height p),
                          end-height: (get end-height p) })
                      (ok true)))))))))

(define-public (pledge-impact (project-id uint) (amount uint))
  (if (<= amount u0)
      err-zero-amount
      (let ((project (map-get? projects { id: project-id })))
        (if (is-none project)
            err-project-not-found
            (let ((p (unwrap-panic project)))
              (if (not (get active p))
                  err-project-inactive
                  (let ((backer tx-sender)
                        (bal (get-balance-internal tx-sender)))
                    (if (< bal amount)
                        err-insufficient-balance
                        (let ((id (var-get next-pledge-id)))
                          (var-set next-pledge-id (+ id u1))
                          (map-set balances { owner: backer } { amount: (- bal amount) })
                          (map-set pledges { id: id }
                            { project-id: project-id,
                              backer: backer,
                              amount: amount,
                              claimed: false })
                          (ok id))))))))))

(define-read-only (get-project (project-id uint))
  (match (map-get? projects { id: project-id })
    p (ok p)
    (err u1)))

(define-read-only (get-pledge (pledge-id uint))
  (match (map-get? pledges { id: pledge-id })
    p (ok p)
    (err u1)))

(define-read-only (get-current-height) (ok stacks-block-height))
