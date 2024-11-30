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
        
        ;; Validate input
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
