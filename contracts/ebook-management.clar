;;-----------------------------------------------------------------------------
;; E-Book Management Smart Contract
;;-----------------------------------------------------------------------------
;; This contract provides a decentralized platform for managing e-books, enabling 
;; users to upload, update, transfer, and delete e-books while maintaining 
;; ownership and access controls. Key features include:
;; - Uploading e-books with metadata (title, size, summary, categories)
;; - Managing ownership and permissions
;; - Validating metadata for consistency and quality
;; - Securing operations with robust error handling and authorization checks
;;-----------------------------------------------------------------------------

;;-----------------------------------------------------------------------------
;; Constants and Error Codes
;;-----------------------------------------------------------------------------
(define-constant ADMIN tx-sender) ;; The administrator of the platform

;; Error Codes
(define-constant ERR-NOT-FOUND (err u301))  ;; E-Book not found in storage
(define-constant ERR-EXISTS (err u302))     ;; E-Book already exists
(define-constant ERR-TITLE (err u303))      ;; Invalid title format or length
(define-constant ERR-SIZE (err u304))       ;; Invalid file size
(define-constant ERR-AUTH (err u305))       ;; Unauthorized operation
(define-constant ERR-RECIPIENT (err u306))  ;; Invalid recipient for transfer
(define-constant ERR-ADMIN (err u307))      ;; Admin-only operation
(define-constant ERR-ACCESS (err u308))     ;; Invalid access request
(define-constant ERR-DENIED (err u309))     ;; Access denied

;; Validation Limits
(define-constant MAX-TITLE-LENGTH u64)       ;; Maximum title length in characters
(define-constant MAX-SUMMARY-LENGTH u256)    ;; Maximum summary length in characters
(define-constant MAX-CATEGORY-LENGTH u32)    ;; Maximum length for a category
(define-constant MAX-CATEGORIES u8)          ;; Maximum number of categories allowed
(define-constant MAX-FILE-SIZE u1000000000)  ;; Maximum file size in bytes

;;-----------------------------------------------------------------------------
;; Data Storage
;;-----------------------------------------------------------------------------

;; Track the total number of e-books uploaded
(define-data-var total-ebooks uint u0)

;; Store e-book details, indexed by a unique e-book ID
(define-map ebooks
    { ebook-id: uint }
    {
        title: (string-ascii 64),         ;; Title of the e-book
        author: principal,               ;; Address of the e-book author
        file-size: uint,                 ;; File size of the e-book in bytes
        upload-time: uint,               ;; Block height when the e-book was uploaded
        summary: (string-ascii 256),     ;; Summary of the e-book
        categories: (list 8 (string-ascii 32)) ;; List of categories assigned to the e-book
    }
)

;; Manage access rights to e-books
(define-map access-rights
    { ebook-id: uint, user: principal }
    { can-access: bool } ;; Indicates whether the user has access to the e-book
)

;;-----------------------------------------------------------------------------
;; Private Utility Functions
;;-----------------------------------------------------------------------------

;; Check if an e-book exists by its ID
(define-private (ebook-exists? (ebook-id uint))
    (is-some (map-get? ebooks { ebook-id: ebook-id }))
)

;; Verify if the specified principal is the author of the e-book
(define-private (is-author? (ebook-id uint) (author principal))
    (match (map-get? ebooks { ebook-id: ebook-id })
        book-data (is-eq (get author book-data) author)
        false
    )
)

;; Retrieve the size of an e-book
(define-private (get-ebook-size (ebook-id uint))
    (default-to u0 
        (get file-size 
            (map-get? ebooks { ebook-id: ebook-id })
        )
    )
)

;; Validate the format and length of a single category
(define-private (is-valid-category? (category (string-ascii 32)))
    (and 
        (> (len category) u0) ;; Must not be empty
        (< (len category) MAX-CATEGORY-LENGTH) ;; Length within the allowed limit
    )
)

;; Validate a list of categories for consistency
(define-private (are-categories-valid? (categories (list 8 (string-ascii 32))))
    (and
        (> (len categories) u0) ;; Ensure at least one category
        (<= (len categories) MAX-CATEGORIES) ;; Within maximum allowed categories
        (is-eq (len (filter is-valid-category? categories)) (len categories))
    )
)

;;-----------------------------------------------------------------------------
;; Public Functions
;;-----------------------------------------------------------------------------

;; Upload a new e-book with metadata
(define-public (upload-ebook 
    (title (string-ascii 64)) 
    (file-size uint) 
    (summary (string-ascii 256)) 
    (categories (list 8 (string-ascii 32))))
    (let
        ((new-id (+ (var-get total-ebooks) u1))) ;; Generate a new unique e-book ID
        
        ;; Validate input
        (asserts! (and (> (len title) u0) (< (len title) MAX-TITLE-LENGTH)) ERR-TITLE)
        (asserts! (and (> file-size u0) (< file-size MAX-FILE-SIZE)) ERR-SIZE)
        (asserts! (and (> (len summary) u0) (< (len summary) MAX-SUMMARY-LENGTH)) ERR-TITLE)
        (asserts! (are-categories-valid? categories) ERR-TITLE)

        ;; Store the e-book data
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

        ;; Assign the uploader access rights to the e-book
        (map-insert access-rights
            { ebook-id: new-id, user: tx-sender }
            { can-access: true }
        )

        ;; Increment the total e-books count
        (var-set total-ebooks new-id)
        (ok new-id)
    )
)

;; Transfer e-book ownership to a new author
(define-public (transfer-ownership (ebook-id uint) (new-author principal))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        
        ;; Validate ownership
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (is-eq (get author book-data) tx-sender) ERR-AUTH)

        ;; Update the author field
        (map-set ebooks
            { ebook-id: ebook-id }
            (merge book-data { author: new-author })
        )
        (ok true)
    )
)

;; Update metadata for an existing e-book
(define-public (update-ebook 
    (ebook-id uint) 
    (new-title (string-ascii 64)) 
    (new-size uint) 
    (new-summary (string-ascii 256)) 
    (new-categories (list 8 (string-ascii 32))))
    (let
        ((book-data (unwrap! (map-get? ebooks { ebook-id: ebook-id }) ERR-NOT-FOUND)))
        
        ;; Validate input and ownership
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (is-eq (get author book-data) tx-sender) ERR-AUTH)
        (asserts! (and (> (len new-title) u0) (< (len new-title) MAX-TITLE-LENGTH)) ERR-TITLE)
        (asserts! (and (> new-size u0) (< new-size MAX-FILE-SIZE)) ERR-SIZE)
        (asserts! (are-categories-valid? new-categories) ERR-TITLE)

        ;; Update the e-book data
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
        
        ;; Validate ownership
        (asserts! (ebook-exists? ebook-id) ERR-NOT-FOUND)
        (asserts! (is-eq (get author book-data) tx-sender) ERR-AUTH)

        ;; Remove the e-book from storage
        (map-delete ebooks { ebook-id: ebook-id })
        (ok true)
    )
)
