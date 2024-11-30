# Decentralized E-Book Management Smart Contract

This repository contains a **Clarity 2.0** smart contract for managing e-books on a decentralized platform. The contract enables users to upload, update, transfer, and delete e-books while maintaining ownership and access controls. It ensures secure operations with robust error handling and authorization checks.

## Features

- **Upload E-Books:** Upload e-books with metadata such as title, file size, summary, and categories.
- **Update E-Books:** Modify the title, file size, summary, and categories of existing e-books.
- **Transfer Ownership:** Transfer the ownership of an e-book to a new author.
- **Delete E-Books:** Remove e-books from the platform.
- **Access Control:** Ensure only authorized users can perform specific actions like transferring ownership and updating metadata.
- **Error Handling:** Includes error codes for invalid operations (e.g., unauthorized actions, invalid metadata, etc.).

## Smart Contract Overview

This smart contract is designed to operate on a **Clarity 2.0** blockchain and implements a decentralized e-book management system. The contract allows users to:

- Upload e-books with associated metadata.
- Validate and enforce rules such as maximum title length, file size, and number of categories.
- Ensure that only the author (or admin) can modify or transfer ownership of e-books.
- Track total e-books uploaded and store them in a secure, immutable manner.
- Assign and manage access rights to e-books.

## Contract Functions

### Upload E-Book

The `upload-ebook` function allows users to upload a new e-book. It validates the input metadata (title, size, summary, categories) and stores the e-book data securely on the blockchain.

```clarity
(define-public (upload-ebook (title (string-ascii 64)) (file-size uint) (summary (string-ascii 256)) (categories (list 8 (string-ascii 32))))
```

### Transfer E-Book Ownership

The `transfer-ownership` function allows the author to transfer ownership of an e-book to a new author. Only the current owner can initiate this action.

```clarity
(define-public (transfer-ownership (ebook-id uint) (new-author principal))
```

### Update E-Book

The `update-ebook` function allows the author to update the metadata of an existing e-book, including title, file size, summary, and categories.

```clarity
(define-public (update-ebook (ebook-id uint) (new-title (string-ascii 64)) (new-size uint) (new-summary (string-ascii 256)) (new-categories (list 8 (string-ascii 32))))
```

### Delete E-Book

The `delete-ebook` function allows the author to delete an e-book from the platform. This operation removes the e-book's data from storage.

```clarity
(define-public (delete-ebook (ebook-id uint))
```

## Data Storage

- **E-books:** E-books are stored in a `map` indexed by a unique e-book ID. Each e-book has associated metadata, including title, author, file size, upload time, summary, and categories.

- **Access Rights:** The access rights for each e-book are tracked in a separate `map`. Users who are granted access can read the e-book, while unauthorized users are denied access.

- **Total E-books:** The total number of e-books uploaded is stored in a `data-var` to keep track of the platform's growth.

## Constants & Error Codes

The contract includes a set of constants and error codes for validation and error handling:

- **Constants:**
  - `ADMIN`: The administrator's principal.
  - Various limits like `MAX-TITLE-LENGTH`, `MAX-SUMMARY-LENGTH`, and `MAX-CATEGORY-LENGTH` for metadata validation.

- **Error Codes:**
  - `ERR-NOT-FOUND`: E-book not found.
  - `ERR-EXISTS`: E-book already exists.
  - `ERR-TITLE`: Invalid title format or length.
  - `ERR-SIZE`: Invalid file size.
  - `ERR-AUTH`: Unauthorized operation.
  - `ERR-RECIPIENT`: Invalid recipient for transfer.
  - `ERR-ADMIN`: Admin-only operation.
  - `ERR-ACCESS`: Invalid access request.

## Deployment

To deploy this smart contract on the Clarity 2.0 blockchain, follow these steps:

### Prerequisites

- **Clarity 2.0 Blockchain**: Ensure you have a working Clarity 2.0 environment to deploy the smart contract.
- **Clarity CLI**: Install the necessary tools for deploying Clarity smart contracts.

### Deploying the Contract

1. Clone this repository to your local machine:
    ```bash
    git clone https://github.com/your-username/clarity-ebook-management.git
    cd clarity-ebook-management
    ```

2. Deploy the smart contract using the Clarity CLI:
    ```bash
    clarity deploy --contract-name ebook-management-contract.clar
    ```

3. Interact with the deployed contract using the Clarity CLI or any compatible front-end.

## Usage

### Uploading an E-Book

To upload an e-book, use the `upload-ebook` function, passing the required metadata.

```bash
clarity call --contract ebook-management-contract.clar --function upload-ebook --args "title", "file-size", "summary", "categories"
```

### Transferring E-Book Ownership

To transfer ownership of an e-book, use the `transfer-ownership` function.

```bash
clarity call --contract ebook-management-contract.clar --function transfer-ownership --args "ebook-id", "new-author-principal"
```

### Updating E-Book Metadata

To update the metadata of an e-book, use the `update-ebook` function.

```bash
clarity call --contract ebook-management-contract.clar --function update-ebook --args "ebook-id", "new-title", "new-size", "new-summary", "new-categories"
```

### Deleting an E-Book

To delete an e-book, use the `delete-ebook` function.

```bash
clarity call --contract ebook-management-contract.clar --function delete-ebook --args "ebook-id"
```

## Error Handling

The contract ensures proper error handling through the use of assertions and custom error codes. The main error conditions include:

- **Invalid E-Book:** If an e-book does not exist, the error `ERR-NOT-FOUND` is returned.
- **Unauthorized Actions:** If a user tries to perform an operation they are not authorized for, such as transferring ownership or updating metadata, the contract will return the appropriate error code (e.g., `ERR-AUTH`).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

We welcome contributions to improve the contract and extend its functionality. Please follow these steps to contribute:

1. Fork this repository.
2. Create a new branch for your feature or fix.
3. Commit your changes and push to your fork.
4. Submit a pull request.
