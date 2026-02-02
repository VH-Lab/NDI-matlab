# NDI Cloud Sync Namespace (`ndi.cloud.sync`)

This namespace provides functions for synchronizing NDI documents and their associated binary data between a local machine and the NDI cloud.

## Function Outline

### Core Sync Functions

*   **`downloadNew.m`**: Incrementally downloads new documents from the cloud. It identifies documents present on the remote cloud storage that are not present in the local NDI dataset since the last recorded sync.
*   **`uploadNew.m`**: Incrementally uploads new local documents to the cloud. It identifies and uploads local documents that were created since the last sync.
*   **`mirrorFromRemote.m`**: Ensures the local dataset is an exact mirror of the remote dataset. It downloads missing documents and **deletes** local documents that do not exist on the remote.
*   **`mirrorToRemote.m`**: Ensures the remote dataset is an exact mirror of the local dataset. It uploads missing documents and **deletes** remote documents that do not exist locally.
*   **`twoWaySync.m`**: Performs a bidirectional, additive synchronization. It uploads local-only documents and downloads remote-only documents. It does **not** delete documents from either side (effectively a union).
*   **`validate.m`**: Compares a local NDI dataset with its cloud counterpart. It identifies documents only present on one side and detects content mismatches (excluding file paths and internal IDs) for common documents.

### Support Classes and Internal Logic

*   **`SyncOptions.m`**: Options class for controlling sync behavior (e.g., `SyncFiles`, `Verbose`, `DryRun`, `FileUploadStrategy`).
*   **`ndi.cloud.sync.internal.index`**: Manages the `index.json` file stored in the dataset's `.ndi/sync/` directory. This index tracks the IDs of local and remote documents at the time of the last sync to enable incremental updates.

---

## SyncIndex and File-Level Tracking

The `SyncIndex` (`index.json`) is the primary mechanism for incremental synchronization in `uploadNew` and `downloadNew`. However, it has significant limitations regarding binary data files:

1.  **Document-Centric Tracking**: The index only stores **Document IDs** (`localDocumentIdsLastSync` and `remoteDocumentIdsLastSync`). It does not track individual **File UIDs** or file hashes.
2.  **Proxy for File Presence**: The system uses "New Document ID" as a proxy for "New Files".
    *   **The Issue**: If a file is added to an *existing* document, the sync functions will not detect it because the document ID is already in the index.
    *   **Partial Failures**: In `uploadNew`, the `SyncIndex` is updated even if the file upload phase fails (as long as the metadata upload succeeded). This prevents the system from retrying the failed file uploads in subsequent incremental syncs, as the document is now considered "synced".
3.  **Correctness**: For strictly immutable documents where files are never added post-creation, the logic is mostly correct. For a dynamic database, the `SyncIndex` is insufficient.

### 4. Incremental Sync "Masking" (Critical Logic Flaw)
There is a critical dependency between `uploadNew` and `downloadNew` through the `SyncIndex`:
*   **The Issue**: `downloadNew` updates the `localDocumentIdsLastSync` field with the current local state after it finishes. If there are local documents that have been created but **not yet uploaded**, `downloadNew` will still add their IDs to the "last sync" list.
*   **The Consequence**: When `uploadNew` is subsequently run, it calculates the delta by comparing the current local documents against `localDocumentIdsLastSync`. Since `downloadNew` already added the new local IDs to that list, `uploadNew` will see them as "already processed" and **skip them permanently**.
*   **Comparison**: Interestingly, `twoWaySync.m` avoids this flaw because it performs a live comparison between the local and remote datasets rather than relying on the index to identify new documents. This makes `twoWaySync` more reliable for data integrity than the incremental `uploadNew` function.

---

## Synchronization Logic Analysis & Best Practices

Maintaining a synced database across local and cloud machines involves several challenges. Below is an analysis of the current implementation's logic and potential issues for maintenance.

### 1. Document Mutability and Change Detection
**Current Logic**: Most sync functions (except `validate`) determine sync state based solely on the existence of NDI document UUIDs.
**Issue**: If a document is updated (fields changed) but retains the same UUID, the standard sync functions will not detect the change. They see the ID on both sides and skip the document.
**Best Practice**: Implement a **content hash (ETag)** or a **version/timestamp** field in document metadata. Sync should check if the remote version differs from the local version, not just if the ID exists.

### 2. Conflict Resolution
**Current Logic**: No automated conflict resolution is provided.
**Issue**: If a document is modified on both the local machine and the cloud between syncs, the system has no way to detect or resolve this "split-brain" scenario.
**Best Practice**: Implement a resolution strategy like **Last Writer Wins (LWW)** using synchronized timestamps, or flag conflicts for manual user intervention.

### 3. Propagation of Deletions
**Current Logic**: `twoWaySync.m` is strictly additive.
**Issue**: If a user deletes a document locally, the next `twoWaySync` will re-download it from the cloud. This makes it impossible to delete documents in bidirectional mode.
**Best Practice**: Use **"Tombstones"** (deletion markers) to track when a document has been intentionally removed. Comparing the current state against the "Last Sync" state in the index can distinguish a "new remote document" from a "locally deleted document".

### 4. Concurrency and Atomicity
**Current Logic**: Sync involves multiple API calls (list documents, upload/download metadata, upload/download files).
**Issue**: There is no built-in locking mechanism. Simultaneous syncs by different users or processes against the same cloud dataset could lead to race conditions or inconsistent states.
**Best Practice**: Use a server-side lock or a reserved "lock document" within the NDI dataset to ensure atomicity of the sync operation.

### 5. Data Integrity
**Current Logic**: Files are transferred via batch or serial upload/download.
**Issue**: There is no explicit verification that the transferred binary files are bit-identical to the source (e.g., no MD5/SHA256 verification after transfer).
**Best Practice**: Always compute and verify checksums for binary files as part of the synchronization process.
