;; Materials Quality Verification Contract
;; Ensures building materials meet specifications and quality standards

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-MATERIAL-NOT-FOUND (err u401))
(define-constant ERR-INVALID-RATING (err u402))
(define-constant ERR-INVALID-INPUT (err u403))
(define-constant ERR-SUPPLIER-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-VERIFIED (err u405))

;; Data Variables
(define-data-var next-material-id uint u1)
(define-data-var total-materials uint u0)
(define-data-var verified-materials uint u0)

;; Data Maps
(define-map materials
  { material-id: uint }
  {
    permit-id: uint,
    supplier: principal,
    material-type: (string-ascii 50),
    specification: (string-ascii 200),
    quantity: uint,
    unit: (string-ascii 20),
    delivery-date: uint,
    verification-date: (optional uint),
    quality-rating: uint,
    test-results: (string-ascii 300),
    certification-hash: (string-ascii 64),
    compliance-status: (string-ascii 20),
    inspector: (optional principal),
    usage-tracking: bool
  }
)

(define-map permit-materials
  { permit-id: uint }
  { material-ids: (list 100 uint), compliance-score: uint }
)

(define-map suppliers
  { supplier: principal }
  {
    name: (string-ascii 100),
    certification-level: uint,
    materials-supplied: uint,
    quality-average: uint,
    verified: bool,
    specializations: (list 10 (string-ascii 50))
  }
)

(define-map material-specifications
  { spec-name: (string-ascii 50) }
  {
    required-tests: (list 5 (string-ascii 50)),
    minimum-rating: uint,
    certification-required: bool
  }
)

(define-map quality-tests
  { material-id: uint, test-name: (string-ascii 50) }
  {
    result: (string-ascii 100),
    pass: bool,
    test-date: uint,
    tester: principal
  }
)

;; Public Functions

;; Register new material delivery
(define-public (register-material
  (permit-id uint)
  (supplier principal)
  (material-type (string-ascii 50))
  (specification (string-ascii 200))
  (quantity uint)
  (unit (string-ascii 20))
  (certification-hash (string-ascii 64)))
  (let
    (
      (material-id (var-get next-material-id))
      (current-block block-height)
    )
    (asserts! (> permit-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len material-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len specification) u0) ERR-INVALID-INPUT)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    (asserts! (> (len unit) u0) ERR-INVALID-INPUT)

    ;; Create new material record
    (map-set materials
      { material-id: material-id }
      {
        permit-id: permit-id,
        supplier: supplier,
        material-type: material-type,
        specification: specification,
        quantity: quantity,
        unit: unit,
        delivery-date: current-block,
        verification-date: none,
        quality-rating: u0,
        test-results: "",
        certification-hash: certification-hash,
        compliance-status: "pending",
        inspector: none,
        usage-tracking: false
      }
    )

    ;; Update permit materials list
    (let
      (
        (current-materials (default-to (list) (get material-ids (map-get? permit-materials { permit-id: permit-id }))))
        (updated-materials (unwrap! (as-max-len? (append current-materials material-id) u100) ERR-INVALID-INPUT))
      )
      (map-set permit-materials
        { permit-id: permit-id }
        { material-ids: updated-materials, compliance-score: u0 }
      )
    )

    ;; Update supplier statistics
    (let
      (
        (supplier-info (map-get? suppliers { supplier: supplier }))
        (materials-count (+ (default-to u0 (get materials-supplied supplier-info)) u1))
      )
      (map-set suppliers
        { supplier: supplier }
        (merge (default-to {
          name: "",
          certification-level: u1,
          materials-supplied: u0,
          quality-average: u0,
          verified: false,
          specializations: (list)
        } supplier-info) {
          materials-supplied: materials-count
        })
      )
    )

    ;; Update counters
    (var-set next-material-id (+ material-id u1))
    (var-set total-materials (+ (var-get total-materials) u1))

    (ok material-id)
  )
)

;; Verify material quality
(define-public (verify-material-quality
  (material-id uint)
  (quality-rating uint)
  (test-results (string-ascii 300))
  (compliance-status (string-ascii 20)))
  (let
    (
      (material (unwrap! (map-get? materials { material-id: material-id }) ERR-MATERIAL-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-some (get inspector material))) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= quality-rating u0) (<= quality-rating u100)) ERR-INVALID-RATING)
    (asserts! (> (len test-results) u0) ERR-INVALID-INPUT)
    (asserts! (> (len compliance-status) u0) ERR-INVALID-INPUT)

    (map-set materials
      { material-id: material-id }
      (merge material {
        verification-date: (some block-height),
        quality-rating: quality-rating,
        test-results: test-results,
        compliance-status: compliance-status,
        inspector: (some tx-sender)
      })
    )

    ;; Update verified materials counter
    (if (>= quality-rating u70)
      (var-set verified-materials (+ (var-get verified-materials) u1))
      true
    )

    ;; Update supplier quality average
    (let
      (
        (supplier-info (unwrap! (map-get? suppliers { supplier: (get supplier material) }) ERR-SUPPLIER-NOT-FOUND))
        (current-avg (get quality-average supplier-info))
        (materials-count (get materials-supplied supplier-info))
        (new-avg (/ (+ (* current-avg (- materials-count u1)) quality-rating) materials-count))
      )
      (map-set suppliers
        { supplier: (get supplier material) }
        (merge supplier-info { quality-average: new-avg })
      )
    )

    (ok true)
  )
)

;; Record quality test result
(define-public (record-test-result
  (material-id uint)
  (test-name (string-ascii 50))
  (result (string-ascii 100))
  (pass bool))
  (let
    (
      (material (unwrap! (map-get? materials { material-id: material-id }) ERR-MATERIAL-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-some (get inspector material))) ERR-NOT-AUTHORIZED)
    (asserts! (> (len test-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len result) u0) ERR-INVALID-INPUT)

    (map-set quality-tests
      { material-id: material-id, test-name: test-name }
      {
        result: result,
        pass: pass,
        test-date: block-height,
        tester: tx-sender
      }
    )

    (ok true)
  )
)

;; Register supplier
(define-public (register-supplier
  (supplier principal)
  (name (string-ascii 100))
  (certification-level uint)
  (specializations (list 10 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= certification-level u1) (<= certification-level u5)) ERR-INVALID-INPUT)

    (map-set suppliers
      { supplier: supplier }
      {
        name: name,
        certification-level: certification-level,
        materials-supplied: u0,
        quality-average: u0,
        verified: true,
        specializations: specializations
      }
    )

    (ok true)
  )
)

;; Add material specification
(define-public (add-material-specification
  (spec-name (string-ascii 50))
  (required-tests (list 5 (string-ascii 50)))
  (minimum-rating uint)
  (certification-required bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len spec-name) u0) ERR-INVALID-INPUT)
    (asserts! (<= minimum-rating u100) ERR-INVALID-RATING)

    (map-set material-specifications
      { spec-name: spec-name }
      {
        required-tests: required-tests,
        minimum-rating: minimum-rating,
        certification-required: certification-required
      }
    )

    (ok true)
  )
)

;; Enable usage tracking for material
(define-public (enable-usage-tracking (material-id uint))
  (let
    (
      (material (unwrap! (map-get? materials { material-id: material-id }) ERR-MATERIAL-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq (get supplier material) tx-sender)) ERR-NOT-AUTHORIZED)

    (map-set materials
      { material-id: material-id }
      (merge material { usage-tracking: true })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get material details
(define-read-only (get-material (material-id uint))
  (map-get? materials { material-id: material-id })
)

;; Get materials for a permit
(define-read-only (get-permit-materials (permit-id uint))
  (map-get? permit-materials { permit-id: permit-id })
)

;; Get supplier information
(define-read-only (get-supplier (supplier principal))
  (map-get? suppliers { supplier: supplier })
)

;; Get material specification
(define-read-only (get-material-specification (spec-name (string-ascii 50)))
  (map-get? material-specifications { spec-name: spec-name })
)

;; Get test result
(define-read-only (get-test-result (material-id uint) (test-name (string-ascii 50)))
  (map-get? quality-tests { material-id: material-id, test-name: test-name })
)

;; Get total materials count
(define-read-only (get-total-materials)
  (var-get total-materials)
)

;; Get verified materials count
(define-read-only (get-verified-materials)
  (var-get verified-materials)
)

;; Calculate permit compliance score
(define-read-only (calculate-compliance-score (permit-id uint))
  (match (map-get? permit-materials { permit-id: permit-id })
    permit-info (get compliance-score permit-info)
    u0
  )
)

;; Check if material meets specification
(define-read-only (meets-specification (material-id uint) (spec-name (string-ascii 50)))
  (match (map-get? materials { material-id: material-id })
    material (match (map-get? material-specifications { spec-name: spec-name })
      spec (>= (get quality-rating material) (get minimum-rating spec))
      false
    )
    false
  )
)
