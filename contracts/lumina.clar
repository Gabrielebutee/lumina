;; Enhanced Lumina Art NFT Marketplace with Dynamic Royalties and Auctions

;; Data Maps - Original
(define-map lumina-royalties uint (tuple (creator principal) (percent uint)))
(define-map lumina-listings uint {price: uint, listed: bool})
(define-map lumina-token-uri uint (string-ascii 256))
(define-map lumina-transfer-locks uint {unlock-height: uint})

;; Data Maps - New: Dynamic Royalty System
(define-map lumina-creator-splits uint (list 10 {creator: principal, percentage: uint}))
(define-map lumina-royalty-decay uint {initial-percent: uint, decay-rate: uint, mint-block: uint})

;; Data Maps - New: Auction System
(define-map lumina-auctions uint {
    seller: principal,
    start-price: uint,
    current-bid: uint,
    highest-bidder: (optional principal),
    end-block: uint,
    reserve-price: uint,
    active: bool
})

;; Data Maps - New: Simplified Bid Tracking
(define-map lumina-bid-count uint uint)
(define-map lumina-latest-bid uint {bidder: principal, amount: uint, block: uint})

;; NFT Definition
(define-non-fungible-token lumina-art-nft uint)

;; Data Variables - Original
(define-data-var lumina-next-id uint u1)
(define-data-var lumina-contract-paused bool false)
(define-data-var lumina-marketplace-fee-percent uint u250) ;; 2.5% in basis points
(define-data-var lumina-marketplace-address principal tx-sender)

;; Data Variables - New
(define-data-var lumina-min-auction-duration uint u144) ;; ~1 day in blocks
(define-data-var lumina-max-auction-duration uint u10080) ;; ~1 week in blocks
(define-data-var lumina-auction-extension-blocks uint u72) ;; ~12 hours

;; Constants
(define-constant lumina-contract-owner tx-sender)
(define-constant LUMINA-MAX-ROYALTY-PERCENTAGE u2500) ;; 25% in basis points
(define-constant LUMINA-MAX-MARKETPLACE-FEE u1000) ;; 10% in basis points
(define-constant LUMINA-BASIS-POINTS u10000) ;; 100% = 10000 basis points
(define-constant LUMINA-MAX-CREATORS u10)

;; Error Constants - Original
(define-constant ERR-LUMINA-NOT-AUTHORIZED u403)
(define-constant ERR-LUMINA-INVALID-PRICE u401)
(define-constant ERR-LUMINA-NOT-LISTED u404)
(define-constant ERR-LUMINA-ALREADY-LISTED u409)
(define-constant ERR-LUMINA-INVALID-ADDRESS u405)
(define-constant ERR-LUMINA-CONTRACT-PAUSED u406)
(define-constant ERR-LUMINA-TRANSFER-LOCKED u407)
(define-constant ERR-LUMINA-INSUFFICIENT-PAYMENT u408)
(define-constant ERR-LUMINA-INVALID-PERCENTAGE u410)

;; Error Constants - New
(define-constant ERR-LUMINA-AUCTION-ACTIVE u411)
(define-constant ERR-LUMINA-AUCTION-ENDED u412)
(define-constant ERR-LUMINA-BID-TOO-LOW u413)
(define-constant ERR-LUMINA-AUCTION-NOT-FOUND u414)
(define-constant ERR-LUMINA-INVALID-DURATION u415)
(define-constant ERR-LUMINA-RESERVE-NOT-MET u416)

;; Private Functions - Original
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

;; Private Functions - New: Dynamic Royalty System
(define-private (lumina-validate-creator-splits (creators (list 10 {creator: principal, percentage: uint})))
    (let ((total-percentage (fold + (map get-creator-percentage creators) u0)))
        (and (<= (len creators) LUMINA-MAX-CREATORS)
             (<= total-percentage u10000)
             (> (len creators) u0))
    )
)

(define-private (get-creator-percentage (creator-info {creator: principal, percentage: uint}))
    (get percentage creator-info)
)

(define-private (lumina-calculate-current-royalty (id uint))
    (match (map-get? lumina-royalty-decay id)
        decay-info 
        (let ((blocks-passed (- stacks-block-height (get mint-block decay-info)))
              (decay-amount (/ (* blocks-passed (get decay-rate decay-info)) u1000)))
            (if (> decay-amount (get initial-percent decay-info))
                u0
                (- (get initial-percent decay-info) decay-amount)))
        (match (map-get? lumina-royalties id)
            royalty-info (get percent royalty-info)
            u0))
)

(define-private (lumina-distribute-creator-royalties (id uint) (total-royalty uint) (buyer principal))
    (match (map-get? lumina-creator-splits id)
        creators (begin
            (try! (lumina-pay-creators creators total-royalty buyer))
            (ok true))
        (match (map-get? lumina-royalties id)
            single-creator (stx-transfer? total-royalty buyer (get creator single-creator))
            (ok true)))
)

(define-private (lumina-pay-creators (creators (list 10 {creator: principal, percentage: uint})) (total-amount uint) (buyer principal))
    (fold lumina-pay-single-creator creators (ok {remaining: total-amount, buyer: buyer}))
)

(define-private (lumina-pay-single-creator 
    (creator-info {creator: principal, percentage: uint}) 
    (acc-result (response {remaining: uint, buyer: principal} uint)))
    (match acc-result
        acc-data 
        (let ((creator-amount (/ (* (get remaining acc-data) (get percentage creator-info)) u10000)))
            (match (stx-transfer? creator-amount (get buyer acc-data) (get creator creator-info))
                success (ok {remaining: (- (get remaining acc-data) creator-amount), buyer: (get buyer acc-data)})
                error (err error)))
        error (err error))
)

;; Private Functions - New: Event-Only Bid Tracking (Approach 5)
(define-private (lumina-record-bid-event (id uint) (bidder principal) (amount uint))
    (let ((current-count (default-to u0 (map-get? lumina-bid-count id)))
          (new-count (+ current-count u1)))
        (begin
            ;; Update bid count and latest bid info
            (map-set lumina-bid-count id new-count)
            (map-set lumina-latest-bid id {
                bidder: bidder,
                amount: amount,
                block: stacks-block-height
            })
            ;; Emit detailed event for off-chain indexing
            (print {
                event: "lumina-bid-history",
                token-id: id,
                bidder: bidder,
                amount: amount,
                block-height: stacks-block-height,
                bid-number: new-count
            })
            true)
    )
)

(define-private (lumina-process-auction-payment (id uint) (final-price uint) (seller principal))
    (let ((current-royalty (lumina-calculate-current-royalty id))
          (fees (lumina-calculate-fees final-price current-royalty))
          (marketplace-fee (get marketplace-fee fees))
          (royalty-fee (get royalty-fee fees))
          (seller-amount (- (- final-price marketplace-fee) royalty-fee)))
        (begin
            ;; Transfer marketplace fee
            (try! (as-contract (stx-transfer? marketplace-fee tx-sender (var-get lumina-marketplace-address))))
            ;; Distribute royalties
            (try! (as-contract (lumina-distribute-creator-royalties id royalty-fee tx-sender)))
            ;; Pay seller
            (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
            (ok true)
        )
    )
)

;; Public Functions - Original (Enhanced)
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
          (seller (unwrap! (nft-get-owner? lumina-art-nft id) (err ERR-LUMINA-NOT-LISTED))))
        
        (begin
            ;; Validate listing is active and no auction
            (asserts! (get listed listing) (err ERR-LUMINA-NOT-LISTED))
            (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
            (asserts! (not (lumina-is-transfer-locked id)) (err ERR-LUMINA-TRANSFER-LOCKED))
            (asserts! (not (lumina-is-auction-active id)) (err ERR-LUMINA-AUCTION-ACTIVE))
            
            (let ((price (get price listing))
                  (current-royalty (lumina-calculate-current-royalty id))
                  (fees (lumina-calculate-fees price current-royalty))
                  (marketplace-fee (get marketplace-fee fees))
                  (royalty-fee (get royalty-fee fees))
                  (seller-amount (- (- price marketplace-fee) royalty-fee)))
                
                (begin
                    ;; Transfer payments
                    (try! (stx-transfer? marketplace-fee tx-sender (var-get lumina-marketplace-address)))
                    (try! (lumina-distribute-creator-royalties id royalty-fee tx-sender))
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
        (asserts! (not (lumina-is-auction-active id)) (err ERR-LUMINA-AUCTION-ACTIVE))
        
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
        (asserts! (not (lumina-is-auction-active id)) (err ERR-LUMINA-AUCTION-ACTIVE))
        
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
        (asserts! (not (lumina-is-auction-active id)) (err ERR-LUMINA-AUCTION-ACTIVE))
        
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
        (asserts! (not (lumina-is-auction-active id)) (err ERR-LUMINA-AUCTION-ACTIVE))
        
        ;; Clean up all associated data
        (map-delete lumina-listings id)
        (map-delete lumina-royalties id)
        (map-delete lumina-token-uri id)
        (map-delete lumina-transfer-locks id)
        (map-delete lumina-creator-splits id)
        (map-delete lumina-royalty-decay id)
        (map-delete lumina-auctions id)
        (map-delete lumina-bid-count id)
        (map-delete lumina-latest-bid id)
        
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

;; Public Functions - New: Dynamic Royalty System
(define-public (set-lumina-creator-splits (id uint) (creators (list 10 {creator: principal, percentage: uint})))
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (lumina-validate-creator-splits creators) (err ERR-LUMINA-INVALID-PERCENTAGE))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        
        (map-set lumina-creator-splits id creators)
        (print {event: "lumina-creator-splits-set", token-id: id, creators: creators})
        (ok true)
    )
)

(define-public (set-lumina-royalty-decay (id uint) (initial-percent uint) (decay-rate uint))
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (lumina-validate-percentage initial-percent) (err ERR-LUMINA-INVALID-PERCENTAGE))
        (asserts! (<= decay-rate u100) (err ERR-LUMINA-INVALID-PERCENTAGE)) ;; Max 10% decay per 1000 blocks
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        
        (map-set lumina-royalty-decay id {
            initial-percent: initial-percent,
            decay-rate: decay-rate,
            mint-block: stacks-block-height
        })
        (print {event: "lumina-royalty-decay-set", token-id: id, initial-percent: initial-percent, decay-rate: decay-rate})
        (ok true)
    )
)

;; Public Functions - New: Auction System
(define-public (create-lumina-auction (id uint) (start-price uint) (reserve-price uint) (duration-blocks uint))
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? lumina-art-nft id)) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (> start-price u0) (err ERR-LUMINA-INVALID-PRICE))
        (asserts! (>= reserve-price start-price) (err ERR-LUMINA-INVALID-PRICE))
        (asserts! (and (>= duration-blocks (var-get lumina-min-auction-duration)) 
                      (<= duration-blocks (var-get lumina-max-auction-duration))) (err ERR-LUMINA-INVALID-DURATION))
        (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
        (asserts! (not (lumina-is-transfer-locked id)) (err ERR-LUMINA-TRANSFER-LOCKED))
        (asserts! (not (lumina-is-auction-active id)) (err ERR-LUMINA-AUCTION-ACTIVE))
        
        ;; Remove any existing listing
        (match (map-get? lumina-listings id)
            listing (map-set lumina-listings id {price: (get price listing), listed: false})
            true
        )
        
        (map-set lumina-auctions id {
            seller: tx-sender,
            start-price: start-price,
            current-bid: start-price,
            highest-bidder: none,
            end-block: (+ stacks-block-height duration-blocks),
            reserve-price: reserve-price,
            active: true
        })
        
        (print {event: "lumina-auction-created", token-id: id, start-price: start-price, reserve-price: reserve-price, end-block: (+ stacks-block-height duration-blocks)})
        (ok true)
    )
)

(define-public (place-lumina-bid (id uint) (bid-amount uint))
    (let ((auction (unwrap! (map-get? lumina-auctions id) (err ERR-LUMINA-AUCTION-NOT-FOUND))))
        (begin
            (asserts! (get active auction) (err ERR-LUMINA-AUCTION-NOT-FOUND))
            (asserts! (< stacks-block-height (get end-block auction)) (err ERR-LUMINA-AUCTION-ENDED))
            (asserts! (> bid-amount (get current-bid auction)) (err ERR-LUMINA-BID-TOO-LOW))
            (asserts! (not (var-get lumina-contract-paused)) (err ERR-LUMINA-CONTRACT-PAUSED))
            
            ;; Refund previous highest bidder
            (match (get highest-bidder auction)
                prev-bidder (try! (as-contract (stx-transfer? (get current-bid auction) tx-sender prev-bidder)))
                true)
            
            ;; Accept new bid
            (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
            
            ;; Extend auction if bid placed near end
            (let ((time-left (- (get end-block auction) stacks-block-height))
                  (extension-threshold (var-get lumina-auction-extension-blocks))
                  (new-end-block (if (< time-left extension-threshold)
                                   (+ stacks-block-height extension-threshold)
                                   (get end-block auction))))
                
                ;; Update auction
                (map-set lumina-auctions id (merge auction {
                    current-bid: bid-amount,
                    highest-bidder: (some tx-sender),
                    end-block: new-end-block
                }))
                
                ;; Record bid using event-only approach
                (lumina-record-bid-event id tx-sender bid-amount)
                
                (print {event: "lumina-bid-placed", token-id: id, bidder: tx-sender, amount: bid-amount, new-end-block: new-end-block})
                (ok true)
            )
        )
    )
)

(define-public (settle-lumina-auction (id uint))
    (let ((auction (unwrap! (map-get? lumina-auctions id) (err ERR-LUMINA-AUCTION-NOT-FOUND))))
        (begin
            (asserts! (get active auction) (err ERR-LUMINA-AUCTION-NOT-FOUND))
            (asserts! (>= stacks-block-height (get end-block auction)) (err ERR-LUMINA-AUCTION-ENDED))
            
            (match (get highest-bidder auction)
    winner (begin
        ;; Check reserve price met
        (if (>= (get current-bid auction) (get reserve-price auction))
            (begin
                ;; Transfer NFT to winner
                (try! (as-contract (nft-transfer? lumina-art-nft id (get seller auction) winner)))
                ;; Process payment with fees
                (try! (lumina-process-auction-payment id (get current-bid auction) (get seller auction)))
                (print {event: "lumina-auction-settled", token-id: id, winner: winner, final-price: (get current-bid auction)})
                true)
            (begin
                ;; Reserve not met, refund highest bidder
                (try! (as-contract (stx-transfer? (get current-bid auction) tx-sender winner)))
                (print {event: "lumina-auction-reserve-not-met", token-id: id, final-bid: (get current-bid auction), reserve: (get reserve-price auction)})
                true)))
    ;; No bids, auction ends without sale
    (begin
        (print {event: "lumina-auction-no-bids", token-id: id})
        true))
            
            ;; Mark auction as inactive
            (map-set lumina-auctions id (merge auction {active: false}))
            (ok true)
        )
    )
)

(define-public (cancel-lumina-auction (id uint))
    (let ((auction (unwrap! (map-get? lumina-auctions id) (err ERR-LUMINA-AUCTION-NOT-FOUND))))
        (begin
            (asserts! (is-eq tx-sender (get seller auction)) (err ERR-LUMINA-NOT-AUTHORIZED))
            (asserts! (get active auction) (err ERR-LUMINA-AUCTION-NOT-FOUND))
            (asserts! (is-none (get highest-bidder auction)) (err ERR-LUMINA-NOT-AUTHORIZED)) ;; Can only cancel if no bids
            
            ;; Mark auction as inactive
            (map-set lumina-auctions id (merge auction {active: false}))
            
            (print {event: "lumina-auction-cancelled", token-id: id})
            (ok true)
        )
    )
)

;; Admin Functions - Original
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

;; Admin Functions - New
(define-public (update-lumina-auction-settings (min-duration uint) (max-duration uint) (extension-blocks uint))
    (begin
        (asserts! (is-eq tx-sender lumina-contract-owner) (err ERR-LUMINA-NOT-AUTHORIZED))
        (asserts! (and (> min-duration u0) (< min-duration max-duration)) (err ERR-LUMINA-INVALID-DURATION))
        (asserts! (<= max-duration u20160) (err ERR-LUMINA-INVALID-DURATION)) ;; Max 2 weeks
        (asserts! (<= extension-blocks u1440) (err ERR-LUMINA-INVALID-DURATION)) ;; Max 1 day extension
        
        (var-set lumina-min-auction-duration min-duration)
        (var-set lumina-max-auction-duration max-duration)
        (var-set lumina-auction-extension-blocks extension-blocks)
        
        (print {event: "lumina-auction-settings-updated", min-duration: min-duration, max-duration: max-duration, extension-blocks: extension-blocks})
        (ok true)
    )
)

;; Read-only Functions - Original
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

;; Read-only Functions - New: Dynamic Royalty System
(define-read-only (get-lumina-creator-splits (id uint))
    (ok (map-get? lumina-creator-splits id))
)

(define-read-only (get-lumina-royalty-decay (id uint))
    (ok (map-get? lumina-royalty-decay id))
)

(define-read-only (get-lumina-current-royalty (id uint))
    (ok (lumina-calculate-current-royalty id))
)

;; Read-only Functions - New: Auction System
(define-read-only (get-lumina-auction (id uint))
    (ok (map-get? lumina-auctions id))
)

(define-read-only (get-lumina-bid-count (id uint))
    (ok (map-get? lumina-bid-count id))
)

(define-read-only (get-lumina-latest-bid (id uint))
    (ok (map-get? lumina-latest-bid id))
)

(define-read-only (lumina-is-auction-active (id uint))
    (match (map-get? lumina-auctions id)
        auction (and (get active auction) (< stacks-block-height (get end-block auction)))
        false)
)

(define-read-only (get-lumina-auction-settings)
    (ok {
        min-duration: (var-get lumina-min-auction-duration),
        max-duration: (var-get lumina-max-auction-duration),
        extension-blocks: (var-get lumina-auction-extension-blocks)
    })
)

(define-read-only (get-lumina-auction-time-left (id uint))
    (match (map-get? lumina-auctions id)
        auction (if (and (get active auction) (< stacks-block-height (get end-block auction)))
                   (ok (some (- (get end-block auction) stacks-block-height)))
                   (ok none))
        (ok none))
)
