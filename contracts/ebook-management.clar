;;-----------------------------------------------------------------------------
;; E-Book Management Smart Contract
;;-----------------------------------------------------------------------------
;; This contract provides a decentralized platform for managing e-books, enabling 

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
