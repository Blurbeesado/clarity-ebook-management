;;-----------------------------------------------------------------------------
;; E-Book Management Smart Contract
;;-----------------------------------------------------------------------------
;; This contract allows users to manage e-book metadata. Users can:
;; 1. Upload new e-books with a title and have their ownership recorded.
;; 2. Retrieve metadata for an e-book using its unique ID.
;; The contract ensures title validation and provides error handling.
;; A decentralized platform for managing the storage and sharing of e-books, that is, it a decentralized e-book management platform on the blockchain that facilitates the secure and transparent storage, management, and sharing of e-books.
;; This contract allows users to upload, transfer ownership, update, and delete e-books.
;; It also ensures proper validation of inputs and access control.
;;-----------------------------------------------------------------------------
;;-----------------------------------------------------------------------------
;; Constants
;;-----------------------------------------------------------------------------

;; Define the admin (default: transaction sender)
(define-constant ADMIN tx-sender)

;; Error Codes for Standardized Error Handling
(define-constant ERR-NOT-FOUND (err u301))          ;; E-book not found
(define-constant ERR-EXISTS (err u302))             ;; E-book already exists
(define-constant ERR-TITLE (err u303))              ;; Invalid e-book title
(define-constant ERR-SIZE (err u304))               ;; Invalid e-book file size
(define-constant ERR-AUTH (err u305))               ;; Unauthorized access
(define-constant ERR-RECIPIENT (err u306))          ;; Invalid recipient for transfer
(define-constant ERR-ADMIN (err u307))              ;; Admin-only action
(define-constant ERR-ACCESS (err u308))             ;; Access rights invalid
(define-constant ERR-DENIED (err u309))             ;; Access denied

;; Validation Constraints
(define-constant MAX-TITLE-LENGTH u64)              ;; Maximum title length
(define-constant MAX-SUMMARY-LENGTH u256)           ;; Maximum summary length
(define-constant MAX-CATEGORY-LENGTH u32)           ;; Maximum length of a category
(define-constant MAX-CATEGORIES u8)                 ;; Maximum number of categories
(define-constant MAX-FILE-SIZE u1000000000)         ;; Maximum file size (in bytes)

;;-----------------------------------------------------------------------------
;; Data Storage
;;-----------------------------------------------------------------------------

;; Global variable tracking total number of e-books
(define-data-var total-ebooks uint u0)

;; Mapping for storing e-book metadata
(define-map ebooks
    { ebook-id: uint }
    {
        title: (string-ascii 64),                   ;; E-book title
        author: principal,                         ;; Author's principal ID
        file-size: uint,                           ;; Size of the e-book file
        upload-time: uint,                         ;; Block height when uploaded
        summary: (string-ascii 256),               ;; Brief summary of the e-book
        categories: (list 8 (string-ascii 32))     ;; List of categories/tags
    }
)

;; Mapping for access permissions by user and e-book
(define-map access-rights
    { ebook-id: uint, user: principal }
    { can-access: bool }                           ;; Access permission flag
)

;; Mapping to track e-book read counts
(define-map read-counts
    { ebook-id: uint }
    { read-count: uint }  ;; Tracks the number of times the e-book has been accessed
)

;;-----------------------------------------------------------------------------
;; Private Functions
;;-----------------------------------------------------------------------------

;; Check if an e-book exists in the system
(define-private (ebook-exists? (ebook-id uint))
    (is-some (map-get? ebooks { ebook-id: ebook-id }))
)

;; Verify if the caller is the author of the specified e-book
(define-private (is-author? (ebook-id uint) (author principal))
    (match (map-get? ebooks { ebook-id: ebook-id })
        book-data (is-eq (get author book-data) author)
        false
    )
)

;; Retrieve the file size of a specific e-book
(define-private (get-ebook-size (ebook-id uint))
    (default-to u0 
        (get file-size 
            (map-get? ebooks { ebook-id: ebook-id })
        )
    )
)

;; Validate a single category string
(define-private (is-valid-category? (category (string-ascii 32)))
    (and 
        (> (len category) u0)
        (< (len category) MAX-CATEGORY-LENGTH)
    )
)

;; Validate an entire list of categories
(define-private (are-categories-valid? (categories (list 8 (string-ascii 32))))
    (and
        (> (len categories) u0)
        (<= (len categories) MAX-CATEGORIES)
        (is-eq (len (filter is-valid-category? categories)) (len categories))
    )
)

;; Increment the read counter for an e-book
(define-private (increment-read-count (ebook-id uint))
    (let
        (
            (current-count (default-to u0 (get read-count (map-get? read-counts { ebook-id: ebook-id }))))
        )
        (map-set read-counts
            { ebook-id: ebook-id }
            { read-count: (+ current-count u1) }
        )
    )
)

;;-----------------------------------------------------------------------------
;; Public Functions
;;-----------------------------------------------------------------------------

;; Fetch complete metadata for a specific e-book
(define-read-only (get-ebook-metadata (ebook-id uint))
    (match (map-get? ebooks { ebook-id: ebook-id })
        book-data 
        (ok {
            title: (get title book-data),
            author: (get author book-data),
            file-size: (get file-size book-data),
            upload-time: (get upload-time book-data),
            summary: (get summary book-data),
            categories: (get categories book-data),
            read-count: (default-to u0 (get read-count (map-get? read-counts { ebook-id: ebook-id })))
        })
        ERR-NOT-FOUND
    )
)

;; Upload a new e-book to the decentralized library
(define-public (upload-ebook 
    (title (string-ascii 64)) 
    (file-size uint) 
    (summary (string-ascii 256)) 
    (categories (list 8 (string-ascii 32))))
    (let
        ((new-id (+ (var-get total-ebooks) u1)))

        ;; Validate inputs
        (asserts! (and (> (len title) u0) (< (len title) MAX-TITLE-LENGTH)) ERR-TITLE)
        (asserts! (and (> file-size u0) (< file-size MAX-FILE-SIZE)) ERR-SIZE)
        (asserts! (and (> (len summary) u0) (< (len summary) MAX-SUMMARY-LENGTH)) ERR-TITLE)
        (asserts! (are-categories-valid? categories) ERR-TITLE)

        ;; Save e-book metadata
        (map-insert ebooks
            { ebook-id: new-id }
            {
                title: title,
                author: tx-sender,
                file-size: file-size,
                upload-time: block-height,
                summary: summary,
                categories: categories
            }
        )

        ;; Grant access to uploader
        (map-insert access-rights
            { ebook-id: new-id, user: tx-sender }
            { can-access: true }
        )

        ;; Increment total e-book count
        (var-set total-ebooks new-id)
        (ok new-id)
    )
)

;; Transfer e-book ownership to another user
(define-public (transfer-ownership (ebook-id uint) (new-author principal))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        
        ;; Validate ownership and existence
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (is-eq (get author book-data) tx-sender) ERR-AUTH)

        ;; Update e-book author
        (map-set ebooks
            { ebook-id: ebook-id }
            (merge book-data { author: new-author })
        )
        (ok true)
    )
)

;; Simulate reading an e-book and increment the read counter
(define-public (read-ebook (ebook-id uint))
    (begin
        ;; Validate that the e-book exists
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)

        ;; Check access permissions for the reader
        (let
            ((access-right (default-to { can-access: false }
                            (map-get? access-rights { ebook-id: ebook-id, user: tx-sender }))))
            (asserts! (get can-access access-right) ERR-ACCESS)
        )

        ;; Increment read count
        (increment-read-count ebook-id)
        (ok true)
    )
)

;; Update metadata of an existing e-book
(define-public (update-ebook 
    (ebook-id uint) 
    (new-title (string-ascii 64)) 
    (new-size uint) 
    (new-summary (string-ascii 256)) 
    (new-categories (list 8 (string-ascii 32))))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        
        ;; Validate ownership and new input
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (is-eq (get author book-data) tx-sender) ERR-AUTH)
        (asserts! (and (> (len new-title) u0) (< (len new-title) MAX-TITLE-LENGTH)) ERR-TITLE)
        (asserts! (and (> new-size u0) (< new-size MAX-FILE-SIZE)) ERR-SIZE)
        (asserts! (and (> (len new-summary) u0) (< (len new-summary) MAX-SUMMARY-LENGTH)) ERR-TITLE)
        (asserts! (are-categories-valid? new-categories) ERR-TITLE)

        ;; Update metadata
        (map-set ebooks
            { ebook-id: ebook-id }
            (merge book-data { 
                title: new-title, 
                file-size: new-size, 
                summary: new-summary, 
                categories: new-categories 
            })
        )
        (ok true)
    )
)

;; Delete an existing e-book
(define-public (delete-ebook (ebook-id uint))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        
        ;; Validate ownership and existence
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (is-eq (get author book-data) tx-sender) ERR-AUTH)

        ;; Remove e-book from storage
        (map-delete ebooks { ebook-id: ebook-id })
        (ok true)
    )
)

;; Verify if a user has access to an e-book.
(define-public (has-access? (ebook-id uint) (user principal))
    (let
        ((access-right (default-to { can-access: false }
            (map-get? access-rights { ebook-id: ebook-id, user: user }))))
        (ok (get can-access access-right))
    )
)

(define-public (grant-access (ebook-id uint) (user principal))
    (begin
        ;; Validate input: Check if the e-book exists
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        
        ;; Ensure that the caller (tx-sender) is the author of the e-book
        (asserts! (is-eq tx-sender (get author (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND))) ERR-AUTH)

        ;; Additional validation for user principal:
        ;; Ensure that the user principal is not the contract itself (to prevent self-access)
        (asserts! (not (is-eq user (as-contract tx-sender))) ERR-RECIPIENT)
        
        ;; Update access rights for the user
        (map-insert access-rights
            { ebook-id: ebook-id, user: user }
            { can-access: true }
        )
        
        ;; Return success
        (ok true)
    )
)

(define-public (revoke-access (ebook-id uint) (user principal))
    (begin
        ;; Validate that the e-book exists
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)

        ;; Validate that the caller is the author of the e-book
        (asserts! (is-author? ebook-id tx-sender) ERR-AUTH)

        ;; Additional input validation: Ensure user is not the contract itself
        (asserts! (not (is-eq user (as-contract tx-sender))) ERR-RECIPIENT)

        ;; Additional validation: Check if the user actually has existing access
        (asserts! 
            (is-some 
                (map-get? access-rights { ebook-id: ebook-id, user: user })
            ) 
            ERR-ACCESS
        )

        ;; Revoke access
        (map-delete access-rights { ebook-id: ebook-id, user: user })
        (ok true)
    )
)

(define-public (get-ebook-author (ebook-id uint))
    (let ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        (ok (get author book-data))
    )
)


(define-public (set-upload-time (ebook-id uint) (upload-time uint))
    (begin
        ;; Validate ebook-id existence
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)

        ;; Ensure upload-time is valid (non-zero block height for example)
        (asserts! (> upload-time u0) ERR-ACCESS)

        ;; Update upload time in the e-book metadata
        (map-set ebooks
            { ebook-id: ebook-id }
            (merge (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)
                   { upload-time: upload-time })
        )

        (ok true)
    )
)

(define-public (donate-access (ebook-id uint) (recipient principal))
    (begin
        ;; Validate e-book existence
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)

        ;; Ensure the caller owns the e-book
        (asserts! (is-author? ebook-id tx-sender) ERR-AUTH)

        ;; Validate recipient (ensure the principal is not null and not the sender)
        (asserts! (not (is-eq recipient tx-sender)) ERR-RECIPIENT)

        ;; Grant access to the recipient
        (map-set access-rights
            { ebook-id: ebook-id, user: recipient }
            { can-access: true }
        )
        (ok true)
    )
)

(define-public (get-upload-time (ebook-id uint))
    (let ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        (ok (get upload-time book-data))
    )
)

;; Update metadata of an existing e-book (with validated summary)
(define-public (set-ebook-summary (ebook-id uint) (new-summary (string-ascii 256)))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        
        ;; Validate ownership and input
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (is-eq (get author book-data) tx-sender) ERR-AUTH)
        (asserts! (and (> (len new-summary) u0) (< (len new-summary) MAX-SUMMARY-LENGTH)) ERR-SIZE)

        ;; Update the summary
        (map-set ebooks
            { ebook-id: ebook-id }
            (merge book-data { summary: new-summary })
        )
        (ok true)
    )
)

;; Fetch the owner of an e-book
(define-public (get-ebook-owner (ebook-id uint))
    (match (map-get? ebooks { ebook-id: ebook-id })
        book-data (ok (get author book-data))
        ERR-NOT-FOUND
    )
)

;; Check if the caller is the owner of an e-book
(define-public (is-owner (ebook-id uint))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        (ok (is-eq (get author book-data) tx-sender))
    )
)

;; Check if the caller is the admin
(define-public (check-admin-access)
    (ok (is-eq tx-sender ADMIN))
)

(define-public (reset-read-count (ebook-id uint))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        ;; Ensure that the e-book exists and the caller is authorized (if needed)
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        ;; Proceed to reset the read count if the e-book is valid
        (map-set read-counts
            { ebook-id: ebook-id }
            { read-count: u0 }  ;; Reset read count to zero
        )
        (ok true)
    )
)

(define-public (set-ebook-file-size (ebook-id uint) (new-file-size uint))
    (begin
        ;; Validate ebook-id existence
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        
        ;; Ensure new file size is valid (non-zero)
        (asserts! (> new-file-size u0) ERR-SIZE)

        ;; Fetch the existing e-book data and update file size
        (let ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
            (map-set ebooks
                { ebook-id: ebook-id }
                (merge book-data { file-size: new-file-size })
            )
        )
        (ok true)
    )
)

;; Set categories for an e-book
(define-public (set-ebook-categories (ebook-id uint) (new-categories (list 8 (string-ascii 32))))
    (begin
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (are-categories-valid? new-categories) ERR-TITLE)
        (let ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
            (map-set ebooks
                { ebook-id: ebook-id }
                (merge book-data { categories: new-categories })
            )
        )
        (ok true)
    )
)

;; Check if an e-book is available for access to the caller
(define-public (check-access (ebook-id uint))
    (let
        ((access-right (default-to { can-access: false }
            (map-get? access-rights { ebook-id: ebook-id, user: tx-sender }))))
        (ok (get can-access access-right))
    )
)

;; Get if a user has access to an e-book
(define-public (get-access-rights (ebook-id uint) (user principal))
    (let ((access-data (unwrap! (map-get? access-rights { ebook-id: ebook-id, user: user }) ERR-NOT-FOUND)))
        (ok (get can-access access-data))
    )
)
