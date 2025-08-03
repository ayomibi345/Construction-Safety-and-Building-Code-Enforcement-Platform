;; Occupancy Permit Issuance Contract
;; Final certification for building occupancy after all safety checks

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-PERMIT-NOT-FOUND (err u501))
(define-constant ERR-CERTIFICATE-NOT-FOUND (err u502))
(define-constant ERR-REQUIREMENTS-NOT-MET (err u503))
(define-constant ERR-INVALID-INPUT (err u504))
(define-constant ERR-ALREADY-ISSUED (err u505))
(define-constant ERR-EXPIRED (err u506))

;; Data Variables
(define-data-var next-certificate-id uint u1)
(define-data-var total-certificates uint u0)
(define-data-var active-certificates uint u0)

;; Data Maps
(define-map occupancy-certificates
  { certificate-id: uint }
  {
    permit-id: uint,
    building-address: (string-ascii 200),
    occupancy-type: (string-ascii 50),
    max-occupancy: uint,
    issue-date: uint,
    expiration-date: uint,
    status: (string-ascii 20),
    issuing-authority: principal,
    special-conditions: (string-ascii 300),
    renewal-required: bool,
    safety-compliance-verified: bool,
    final-inspection-passed: bool
  }
)

(define-map permit-certificates
  { permit-id: uint }
  { certificate-ids: (list 5 uint), current-certificate: (optional uint) }
)

(define-map occupancy-requirements
  { permit-id: uint }
  {
    building-permit-approved: bool,
    final-inspection-completed: bool,
    safety-incidents-resolved: bool,
    materials-verified: bool,
    compliance-score: uint,
    requirements-met: bool
  }
)

(define-map certificate-renewals
  { certificate-id: uint }
  {
    renewal-date: uint,
    previous-certificate: uint,
    changes-made: (string-ascii 300),
    renewed-by: principal
  }
)

(define-map occupancy-types
  { type-name: (string-ascii 50) }
  {
    max-occupancy-limit: uint,
    special-requirements: (string-ascii 200),
    renewal-period-blocks: uint
  }
)

;; Public Functions

;; Issue occupancy certificate
(define-public (issue-occupancy-certificate
  (permit-id uint)
  (building-address (string-ascii 200))
  (occupancy-type (string-ascii 50))
  (max-occupancy uint)
  (expiration-blocks uint)
  (special-conditions (string-ascii 300)))
  (let
    (
      (certificate-id (var-get next-certificate-id))
      (current-block block-height)
      (requirements (unwrap! (map-get? occupancy-requirements { permit-id: permit-id }) ERR-REQUIREMENTS-NOT-MET))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> permit-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len building-address) u0) ERR-INVALID-INPUT)
    (asserts! (> (len occupancy-type) u0) ERR-INVALID-INPUT)
    (asserts! (> max-occupancy u0) ERR-INVALID-INPUT)
    (asserts! (> expiration-blocks u0) ERR-INVALID-INPUT)
    (asserts! (get requirements-met requirements) ERR-REQUIREMENTS-NOT-MET)

    ;; Create new certificate
    (map-set occupancy-certificates
      { certificate-id: certificate-id }
      {
        permit-id: permit-id,
        building-address: building-address,
        occupancy-type: occupancy-type,
        max-occupancy: max-occupancy,
        issue-date: current-block,
        expiration-date: (+ current-block expiration-blocks),
        status: "active",
        issuing-authority: tx-sender,
        special-conditions: special-conditions,
        renewal-required: false,
        safety-compliance-verified: true,
        final-inspection-passed: true
      }
    )

    ;; Update permit certificates
    (let
      (
        (current-certificates (default-to (list) (get certificate-ids (map-get? permit-certificates { permit-id: permit-id }))))
        (updated-certificates (unwrap! (as-max-len? (append current-certificates certificate-id) u5) ERR-INVALID-INPUT))
      )
      (map-set permit-certificates
        { permit-id: permit-id }
        { certificate-ids: updated-certificates, current-certificate: (some certificate-id) }
      )
    )

    ;; Update counters
    (var-set next-certificate-id (+ certificate-id u1))
    (var-set total-certificates (+ (var-get total-certificates) u1))
    (var-set active-certificates (+ (var-get active-certificates) u1))

    (ok certificate-id)
  )
)

;; Set occupancy requirements for permit
(define-public (set-occupancy-requirements
  (permit-id uint)
  (building-permit-approved bool)
  (final-inspection-completed bool)
  (safety-incidents-resolved bool)
  (materials-verified bool)
  (compliance-score uint))
  (let
    (
      (requirements-met (and
        building-permit-approved
        final-inspection-completed
        safety-incidents-resolved
        materials-verified
        (>= compliance-score u80)
      ))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> permit-id u0) ERR-INVALID-INPUT)
    (asserts! (<= compliance-score u100) ERR-INVALID-INPUT)

    (map-set occupancy-requirements
      { permit-id: permit-id }
      {
        building-permit-approved: building-permit-approved,
        final-inspection-completed: final-inspection-completed,
        safety-incidents-resolved: safety-incidents-resolved,
        materials-verified: materials-verified,
        compliance-score: compliance-score,
        requirements-met: requirements-met
      }
    )

    (ok requirements-met)
  )
)

;; Renew occupancy certificate
(define-public (renew-certificate
  (certificate-id uint)
  (new-expiration-blocks uint)
  (changes-made (string-ascii 300)))
  (let
    (
      (certificate (unwrap! (map-get? occupancy-certificates { certificate-id: certificate-id }) ERR-CERTIFICATE-NOT-FOUND))
      (new-certificate-id (var-get next-certificate-id))
      (current-block block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-expiration-blocks u0) ERR-INVALID-INPUT)
    (asserts! (is-eq (get status certificate) "active") ERR-INVALID-INPUT)

    ;; Mark old certificate as renewed
    (map-set occupancy-certificates
      { certificate-id: certificate-id }
      (merge certificate { status: "renewed" })
    )

    ;; Create new certificate
    (map-set occupancy-certificates
      { certificate-id: new-certificate-id }
      (merge certificate {
        issue-date: current-block,
        expiration-date: (+ current-block new-expiration-blocks),
        status: "active",
        issuing-authority: tx-sender,
        renewal-required: false
      })
    )

    ;; Record renewal information
    (map-set certificate-renewals
      { certificate-id: new-certificate-id }
      {
        renewal-date: current-block,
        previous-certificate: certificate-id,
        changes-made: changes-made,
        renewed-by: tx-sender
      }
    )

    ;; Update permit certificates
    (let
      (
        (permit-certs (unwrap! (map-get? permit-certificates { permit-id: (get permit-id certificate) }) ERR-PERMIT-NOT-FOUND))
        (current-certificates (get certificate-ids permit-certs))
        (updated-certificates (unwrap! (as-max-len? (append current-certificates new-certificate-id) u5) ERR-INVALID-INPUT))
      )
      (map-set permit-certificates
        { permit-id: (get permit-id certificate) }
        { certificate-ids: updated-certificates, current-certificate: (some new-certificate-id) }
      )
    )

    ;; Update counters
    (var-set next-certificate-id (+ new-certificate-id u1))
    (var-set total-certificates (+ (var-get total-certificates) u1))

    (ok new-certificate-id)
  )
)

;; Revoke occupancy certificate
(define-public (revoke-certificate
  (certificate-id uint)
  (reason (string-ascii 200)))
  (let
    (
      (certificate (unwrap! (map-get? occupancy-certificates { certificate-id: certificate-id }) ERR-CERTIFICATE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len reason) u0) ERR-INVALID-INPUT)
    (asserts! (is-eq (get status certificate) "active") ERR-INVALID-INPUT)

    (map-set occupancy-certificates
      { certificate-id: certificate-id }
      (merge certificate {
        status: "revoked",
        special-conditions: reason
      })
    )

    ;; Update active certificates counter
    (var-set active-certificates (- (var-get active-certificates) u1))

    (ok true)
  )
)

;; Add occupancy type
(define-public (add-occupancy-type
  (type-name (string-ascii 50))
  (max-occupancy-limit uint)
  (special-requirements (string-ascii 200))
  (renewal-period-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len type-name) u0) ERR-INVALID-INPUT)
    (asserts! (> max-occupancy-limit u0) ERR-INVALID-INPUT)
    (asserts! (> renewal-period-blocks u0) ERR-INVALID-INPUT)

    (map-set occupancy-types
      { type-name: type-name }
      {
        max-occupancy-limit: max-occupancy-limit,
        special-requirements: special-requirements,
        renewal-period-blocks: renewal-period-blocks
      }
    )

    (ok true)
  )
)

;; Update certificate status
(define-public (update-certificate-status
  (certificate-id uint)
  (new-status (string-ascii 20)))
  (let
    (
      (certificate (unwrap! (map-get? occupancy-certificates { certificate-id: certificate-id }) ERR-CERTIFICATE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len new-status) u0) ERR-INVALID-INPUT)

    (map-set occupancy-certificates
      { certificate-id: certificate-id }
      (merge certificate { status: new-status })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get certificate details
(define-read-only (get-certificate (certificate-id uint))
  (map-get? occupancy-certificates { certificate-id: certificate-id })
)

;; Get certificates for a permit
(define-read-only (get-permit-certificates (permit-id uint))
  (map-get? permit-certificates { permit-id: permit-id })
)

;; Get occupancy requirements
(define-read-only (get-occupancy-requirements (permit-id uint))
  (map-get? occupancy-requirements { permit-id: permit-id })
)

;; Get renewal information
(define-read-only (get-renewal-info (certificate-id uint))
  (map-get? certificate-renewals { certificate-id: certificate-id })
)

;; Get occupancy type details
(define-read-only (get-occupancy-type (type-name (string-ascii 50)))
  (map-get? occupancy-types { type-name: type-name })
)

;; Get total certificates count
(define-read-only (get-total-certificates)
  (var-get total-certificates)
)

;; Get active certificates count
(define-read-only (get-active-certificates)
  (var-get active-certificates)
)

;; Check if certificate is valid
(define-read-only (is-certificate-valid (certificate-id uint))
  (match (map-get? occupancy-certificates { certificate-id: certificate-id })
    certificate (and
      (is-eq (get status certificate) "active")
      (> (get expiration-date certificate) block-height)
    )
    false
  )
)

;; Check if certificate is expired
(define-read-only (is-certificate-expired (certificate-id uint))
  (match (map-get? occupancy-certificates { certificate-id: certificate-id })
    certificate (<= (get expiration-date certificate) block-height)
    false
  )
)

;; Check if requirements are met for permit
(define-read-only (are-requirements-met (permit-id uint))
  (match (map-get? occupancy-requirements { permit-id: permit-id })
    requirements (get requirements-met requirements)
    false
  )
)
