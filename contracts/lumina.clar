;; Data Maps
(define-map lumina-royalties uint (tuple (creator principal) (percent uint)))
(define-map lumina-listings uint {price: uint, listed: bool})
(define-map lumina-token-uri uint (string-ascii 256))
(define-map lumina-transfer-locks uint {unlock-height: uint})

;; NFT Definition
(define-non-fungible-token lumina-art-nft uint)

;; Data Variables
(define-data-var lumina-next-id uint u1)
(define-data-var lumina-contract-paused bool false)
(define-data-var lumina-marketplace-fee-percent uint u250) ;; 2.5% in basis points
(define-data-var lumina-marketplace-address principal tx-sender)

;; Constants
(define-constant lumina-contract-owner tx-sender)
(define-constant LUMINA-MAX-ROYALTY-PERCENTAGE u2500) ;; 25% in basis points
(define-constant LUMINA-MAX-MARKETPLACE-FEE u1000) ;; 10% in basis points
(define-constant LUMINA-BASIS-POINTS u10000) ;; 100% = 10000 basis points

;; Error Constants
(define-constant ERR-LUMINA-NOT-AUTHORIZED u403)
(define-constant ERR-LUMINA-INVALID-PRICE u401)
(define-constant ERR-LUMINA-NOT-LISTED u404)
(define-constant ERR-LUMINA-ALREADY-LISTED u409)
(define-constant ERR-LUMINA-INVALID-ADDRESS u405)
(define-constant ERR-LUMINA-CONTRACT-PAUSED u406)
(define-constant ERR-LUMINA-TRANSFER-LOCKED u407)
(define-constant ERR-LUMINA-INSUFFICIENT-PAYMENT u408)
(define-constant ERR-LUMINA-INVALID-PERCENTAGE u410)

;; Private Functions
(define-private (lumina-is-valid-principal (address principal))
    (is-ok (principal-destruct? address))
)

(define-private (lumina-validate-percentage (value uint))
    (<= value LUMINA-MAX-ROYALTY-PERCENTAGE)
)

(define-private (lumina-is-transfer-locked (id uint))
    (match (map-get? lumina-transfer-locks id)
        lock-info (> (get unlock-height lock-info) stacks-block-height)
        false
    )
)

(define-private (lumina-calculate-fees (price uint) (royalty-percent uint))
    (let ((marketplace-fee (/ (* price (var-get lumina-marketplace-fee-percent)) LUMINA-BASIS-POINTS))
          (royalty-fee (/ (* price royalty-percent) LUMINA-BASIS-POINTS)))
        {marketplace-fee: marketplace-fee, royalty-fee: royalty-fee}
    )
)

;; Public Functions
(define-public (mint-lumina-art (recipient principal) (percent uint) (uri (string-ascii 256)))
    (begin
        ;; Validate inputs
        (asserts! (lumina-is-valid-principal recipient) (err ERR-LUMINA-INVALID-ADDRESS))
        (asserts! (lumina-validate-percentage percent) (err ERR-LUMINA-INVALID-PERCENTAGE))
        (asserts! (>= (len uri) u1) (err ERR-LUMINA-INVALID-PRICE))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        
        (let ((id (var-get lumina-next-id)))
            (begin
                (var-set lumina-next-id (+ id u1))
                (try! (nft-mint? lumina-art-nft id recipient))
                (map-set lumina-royalties id {creator: recipient, percent: percent})
                (map-set lumina-token-uri id uri)
                (print {event: "lumina-mint", token-id: id, recipient: recipient, royalty-percent: percent})
                (ok id)
            )
        )
    )
)

(define-public (buy-lumina-art (id uint))
    (let ((listing (unwrap! (map-get? lumina-listings id) (err ERR-LUMINA-NOT-LISTED)))
          (royalty-info (unwrap! (map-get? lumina-royalties id) (err ERR-LUMINA-NOT-LISTED)))
          (seller (unwrap! (nft-get-owner? lumina-art-nft id) (err ERR-LUMINA-NOT-LISTED))))
        
        (begin
            ;; Validate listing is active
            (asserts! (get listed listing) (err ERR-LUMINA-NOT-LISTED))
            (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
            (asserts! (not (lumina-is-transfer-locked id)) (err ERR-LUMINA-TRANSFER-LOCKED))
            
            (let ((price (get price listing))
                  (fees (lumina-calculate-fees price (get percent royalty-info)))
                  (marketplace-fee (get marketplace-fee fees))
                  (royalty-fee (get royalty-fee fees))
                  (seller-amount (- (- price marketplace-fee) royalty-fee)))
                
                (begin
                    ;; Transfer payments
                    (try! (stx-transfer? marketplace-fee tx-sender (var-get lumina-marketplace-address)))
                    (try! (stx-transfer? royalty-fee tx-sender (get creator royalty-info)))
                    (try! (stx-transfer? seller-amount tx-sender seller))
                    
                    ;; Transfer NFT
                    (try! (nft-transfer? lumina-art-nft id seller tx-sender))
                    
                    ;; Remove listing
                    (map-delete lumina-listings id)
                    
                    ;; Emit event
                    (print {event: "lumina-purchase", token-id: id, buyer: tx-sender, seller: seller, price: price})
                    (ok true)
                )
            )
        )
    )
)

(define-public (list-lumina-art (id uint) (price uint))
    (begin
        (asserts! (> price u0) (err ERR-LUMINA-INVALID-PRICE))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        (asserts! (not (lumina-is-transfer-locked id)) (err ERR-LUMINA-TRANSFER-LOCKED))
        
        ;; Check if already listed
        (match (map-get? lumina-listings id)
            existing-listing (asserts! (not (get listed existing-listing)) (err ERR-LUMINA-ALREADY-LISTED))
            true
        )
        
        (map-set lumina-listings id {price: price, listed: true})
        (print {event: "lumina-list", token-id: id, seller: tx-sender, price: price})
        (ok true)
    )
)

(define-public (delist-lumina-art (id uint))
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        
        (let ((listing (unwrap! (map-get? lumina-listings id) (err ERR-LUMINA-NOT-LISTED))))
            (asserts! (get listed listing) (err ERR-LUMINA-NOT-LISTED))
            (map-set lumina-listings id {price: (get price listing), listed: false})
            (print {event: "lumina-delist", token-id: id, seller: tx-sender})
            (ok true)
        )
    )
)

(define-public (update-lumina-listing-price (id uint) (new-price uint))
    (begin
        (asserts! (> new-price u0) (err ERR-LUMINA-INVALID-PRICE))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        
        (let ((listing (unwrap! (map-get? lumina-listings id) (err ERR-LUMINA-NOT-LISTED))))
            (asserts! (get listed listing) (err ERR-LUMINA-NOT-LISTED))
            (map-set lumina-listings id {price: new-price, listed: true})
            (print {event: "lumina-price-update", token-id: id, seller: tx-sender, new-price: new-price})
            (ok true)
        )
    )
)

(define-public (set-lumina-token-uri (id uint) (uri (string-ascii 256)))
    (begin
        (asserts! (>= (len uri) u1) (err ERR-LUMINA-INVALID-PRICE))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        
        (map-set lumina-token-uri id uri)
        (print {event: "lumina-uri-update", token-id: id, uri: uri})
        (ok true)
    )
)

(define-public (transfer-lumina-art (id uint) (recipient principal))
    (begin
        (asserts! (lumina-is-valid-principal recipient) (err ERR-LUMINA-INVALID-ADDRESS))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (not (lumina-is-transfer-locked id)) (err ERR-LUMINA-TRANSFER-LOCKED))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        
        ;; Remove any active listings
        (match (map-get? lumina-listings id)
            listing (if (get listed listing)
                       (map-set lumina-listings id {price: (get price listing), listed: false})
                       true)
            true
        )
        
        (try! (nft-transfer? lumina-art-nft id tx-sender recipient))
        (print {event: "lumina-transfer", token-id: id, from: tx-sender, to: recipient})
        (ok true)
    )
)

(define-public (burn-lumina-art (id uint))
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (not (lumina-is-transfer-locked id)) (err ERR-LUMINA-TRANSFER-LOCKED))
        
        ;; Clean up all associated data
        (map-delete lumina-listings id)
        (map-delete lumina-royalties id)
        (map-delete lumina-token-uri id)
        (map-delete lumina-transfer-locks id)
        
        (try! (nft-burn? lumina-art-nft id tx-sender))
        (print {event: "lumina-burn", token-id: id, owner: tx-sender})
        (ok true)
    )
)

(define-public (lock-lumina-transfer (id uint) (blocks uint))
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (and (> blocks u0) (<= blocks u1000)) (err ERR-LUMINA-INVALID-PRICE))
        
        (map-set lumina-transfer-locks id {unlock-height: (+ stacks-block-height blocks)})
        (print {event: "lumina-transfer-lock", token-id: id, unlock-height: (+ stacks-block-height blocks)})
        (ok true)
    )
)

;; Admin Functions
(define-public (toggle-lumina-pause)
    (begin
        (asserts! (is-eq tx-sender lumina-contract-owner) (err ERR-LUMINA-NOT-AUTHORIZED))
        (var-set lumina-contract-paused (not (var-get lumina-contract-paused)))
        (print {event: "lumina-pause-toggle", paused: (var-get lumina-contract-paused)})
        (ok true)
    )
)

(define-public (update-lumina-marketplace-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender lumina-contract-owner) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (<= new-fee LUMINA-MAX-MARKETPLACE-FEE) (err ERR-LUMINA-INVALID-PERCENTAGE))
        (var-set lumina-marketplace-fee-percent new-fee)
        (print {event: "lumina-marketplace-fee-update", new-fee: new-fee})
        (ok true)
    )
)

(define-public (update-lumina-marketplace-address (new-address principal))
    (begin
        (asserts! (is-eq tx-sender lumina-contract-owner) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (lumina-is-valid-principal new-address) (err ERR-LUMINA-INVALID-ADDRESS))
        (var-set lumina-marketplace-address new-address)
        (print {event: "lumina-marketplace-address-update", new-address: new-address})
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-lumina-token-uri (id uint))
    (ok (map-get? lumina-token-uri id))
)

(define-read-only (get-lumina-listing (id uint))
    (ok (map-get? lumina-listings id))
)

(define-read-only (get-lumina-royalty-info (id uint))
    (ok (map-get? lumina-royalties id))
)

(define-read-only (get-lumina-transfer-lock (id uint))
    (ok (map-get? lumina-transfer-locks id))
)

(define-read-only (get-lumina-marketplace-address)
    (ok (var-get lumina-marketplace-address))
)

(define-read-only (get-lumina-marketplace-fee)
    (ok (var-get lumina-marketplace-fee-percent))
)

(define-read-only (is-lumina-contract-paused)
    (ok (var-get lumina-contract-paused))
)

(define-read-only (get-lumina-next-token-id)
    (ok (var-get lumina-next-id))
)