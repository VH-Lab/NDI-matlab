# NDI Cloud Developer Manual

## Introduction

### NDI in the Cloud vs. NDI on Local Computers

NDI datasets and documents can exist both on local computers and in the NDI Cloud. Understanding the relationship between local and cloud representations is fundamental to working with NDI Cloud.

#### Dataset Identifiers

Every NDI dataset has a **local identifier** obtained via `D.id()`. When a dataset is uploaded to the cloud, it receives a distinct **cloud dataset identifier** (`cloudDatasetID`). These two identifiers are not the same. This intentional separation allows multiple independent copies of the same local dataset to exist in the cloud — for example, in different user accounts or organizational spaces — without conflict.

#### Document Identifiers

Similarly, every NDI document has a **local identifier** accessible via `doc.id()`, which is also stored in the `document_properties.base.id` field. When a document is represented in the cloud, it is referred to by its `ndiID` (corresponding to `base.id`), but it also receives a separate **cloud API document identifier** that is assigned by the cloud system. As with datasets, these two identifiers are different, permitting multiple cloud copies of the same logical document to coexist across different datasets or user spaces.

This dual-identifier design means you should be careful to distinguish between:

- `D.id()` — the local dataset identifier
- `cloudDatasetID` — the identifier assigned to the dataset's representation in the cloud
- `doc.id()` / `document_properties.base.id` / `ndiID` — the local (NDI-native) document identifier
- cloud document ID — the identifier assigned by the cloud API to a specific stored document

#### Organization of Cloud Functions

The NDI Cloud functions are organized into the following namespaces:

| Namespace | Purpose |
|---|---|
| `ndi.cloud.*` | Primary user-facing functions for authentication, downloading, uploading, and syncing |
| `ndi.cloud.download.*` | Functions for downloading datasets, documents, and files from the cloud |
| `ndi.cloud.upload.*` | Functions for uploading datasets, documents, and files to the cloud |
| `ndi.cloud.sync.*` | Functions for synchronizing local datasets with cloud counterparts |
| `ndi.cloud.api.*` | Direct wrappers around the NDI Cloud REST API endpoints |

The `ndi.cloud.*`, `ndi.cloud.download.*`, `ndi.cloud.upload.*`, and `ndi.cloud.sync.*` namespaces contain the high-level user functions intended for everyday use. The `ndi.cloud.api.*` namespace provides lower-level, one-to-one wrappers around the REST API, which are useful when you need precise control over API calls or are building higher-level tooling.

> **Note on `ndi.cloud.api.implementation.*`**: There is also an internal namespace `ndi.cloud.api.implementation.*` that contains the class-based implementations underlying each `ndi.cloud.api.*` function. These implementation classes are not intended for direct use; the `ndi.cloud.api.*` wrapper functions are the appropriate interface for developers.

---

## Authentication

Before calling any cloud function that requires network access, you must authenticate with the NDI Cloud.

### `ndi.cloud.authenticate`

```matlab
[token, organizationID] = ndi.cloud.authenticate()
ndi.cloud.authenticate("UserName", aUserName)
```

Authenticates the user with the NDI Cloud. Authentication is attempted in the following order:

1. If a valid token is already cached (from a previous call), it is reused.
2. If the MATLAB Vault (R2024a+) contains stored credentials under `NDICloud:Email` and `NDICloud:Password`, those are used.
3. If the environment variables `NDI_CLOUD_USERNAME` and `NDI_CLOUD_PASSWORD` are set, those are used.
4. Otherwise, a GUI login dialog is displayed.

**Optional name-value inputs:**
- `UserName` (string) — Force authentication with a specific username. If a token already exists for a different user, this triggers a re-login.
- `InteractionEnabled` (matlab.lang.OnOffSwitchState) — Set to `"off"` to disable interactive prompts (useful in automated/testing contexts).

**Outputs:**
- `token` — The authentication token retrieved after successful authentication.
- `organizationID` — The organization ID fetched from the environment variable `NDI_CLOUD_ORGANIZATION_ID`.

### `ndi.cloud.logout`

```matlab
ndi.cloud.logout()
```

Logs out the current user. This calls the NDI Cloud API to invalidate the session token server-side and clears the `NDI_CLOUD_TOKEN` and `NDI_CLOUD_ORGANIZATION_ID` environment variables locally. After calling this function, subsequent cloud calls will require re-authentication.

---

## Downloading Datasets and Documents

### Primary Download Function

#### `ndi.cloud.downloadDataset`

```matlab
ndiDataset = ndi.cloud.downloadDataset(cloudDatasetId, targetFolder, ...)
```

Downloads a dataset from the NDI Cloud to a local folder. This is the recommended high-level function for obtaining a cloud dataset locally.

**Inputs:**
- `cloudDatasetId` (string) — The cloud dataset identifier. If omitted, a GUI dialog prompts the user to select a dataset.
- `targetFolder` (string) — The local folder where the dataset will be saved. If omitted, a folder picker dialog is shown.

**Optional name-value inputs (via `ndi.cloud.sync.SyncOptions`):**
- `SyncFiles` (logical) — If `true`, binary data files associated with documents are also downloaded. Default: `false`.
- `Verbose` (logical) — If `true`, progress messages are printed. Default: `true`.

**Outputs:**
- `ndiDataset` — An `ndi.dataset` object representing the downloaded dataset.

The dataset is created in a subfolder named after the `cloudDatasetId` within `targetFolder`. A sync index is saved to track the download state, and a `dataset_remote` document recording the `cloudDatasetID` is added to the local dataset to link it to its cloud counterpart.

### Lower-Level Download Functions (`ndi.cloud.download.*`)

#### `ndi.cloud.download.dataset`

```matlab
[b, msg, D] = ndi.cloud.download.dataset(dataset_id, mode, output_path)
```

Downloads a dataset from NDI Cloud, including its documents and (optionally) its files.

**Inputs:**
- `dataset_id` — The cloud dataset identifier.
- `mode` — `'local'` to download all files locally, or `'hybrid'` to leave binary files in the cloud.
- `output_path` — (Optional) The local path where the dataset should be placed. If empty, a directory picker is shown.

**Optional name-value inputs:**
- `verbose` (logical) — Enables verbose output. Default: `true`.

**Outputs:**
- `b` — `1` if download succeeded, `0` if it failed.
- `msg` — An error message string if the download failed; `''` otherwise.
- `D` — An `ndi.dataset` object built from the downloaded documents.

#### `ndi.cloud.download.datasetDocuments`

```matlab
[b, msg] = ndi.cloud.download.datasetDocuments(dataset, mode, jsonpath, filepath)
```

Downloads the documents belonging to a dataset from NDI Cloud and saves each document as a JSON file.

**Inputs:**
- `dataset` — The dataset structure returned by `ndi.cloud.api.datasets.getDataset`.
- `mode` — `'local'` or `'hybrid'` (controls how file paths within documents are set).
- `jsonpath` — Directory where document JSON files are saved.
- `filepath` — Directory where associated binary files are saved.

**Optional name-value inputs:**
- `verbose` (logical) — Enables verbose output. Default: `true`.

**Outputs:**
- `b` — `1` if successful, `0` otherwise.
- `msg` — An error message if the operation failed; `''` otherwise.

#### `ndi.cloud.download.downloadDatasetFiles`

```matlab
ndi.cloud.download.downloadDatasetFiles(cloudDatasetId, targetFolder)
ndi.cloud.download.downloadDatasetFiles(cloudDatasetId, targetFolder, fileUuids)
```

Downloads binary files associated with a cloud dataset to a local folder.

**Inputs:**
- `cloudDatasetId` (string) — The cloud dataset identifier.
- `targetFolder` (string) — The local directory where files will be written.
- `fileUuids` (string array, optional) — UUIDs of specific files to download. If omitted, all files in the dataset are downloaded.

**Optional name-value inputs:**
- `Verbose` (logical) — Enables verbose output. Default: `true`.
- `AbortOnError` (logical) — If `true`, an error during download raises an exception. If `false`, a warning is issued and the download continues. Default: `true`.

#### `ndi.cloud.download.downloadDocumentCollection`

```matlab
documents = ndi.cloud.download.downloadDocumentCollection(datasetId)
documents = ndi.cloud.download.downloadDocumentCollection(datasetId, documentIds)
documents = ndi.cloud.download.downloadDocumentCollection(datasetId, documentIds, ChunkSize=2000)
```

Downloads a collection of documents from a cloud dataset using the bulk download mechanism. Large collections are automatically split into chunks to avoid server-side limits.

**Inputs:**
- `datasetId` (string) — The cloud dataset identifier.
- `documentIds` (string array, optional) — Cloud API document IDs to download. If omitted or empty, all documents in the dataset are downloaded.

**Optional name-value inputs:**
- `Timeout` (double) — Timeout in seconds for the download operation. Default: `20`.
- `ChunkSize` (double) — Maximum number of document IDs per bulk download request. Default: `2000`.

**Outputs:**
- `documents` — A cell array of `ndi.document` objects.

---

## Uploading Datasets

### Primary Upload Function

#### `ndi.cloud.uploadDataset`

```matlab
[success, cloudDatasetId, message] = ndi.cloud.uploadDataset(ndiDataset, ...)
```

Uploads an `ndi.dataset` object to NDI Cloud. This is the recommended high-level function for publishing a local dataset to the cloud.

**Inputs:**
- `ndiDataset` (ndi.dataset) — The local NDI dataset to upload.

**Optional name-value inputs (via `ndi.cloud.sync.SyncOptions`):**
- `SyncFiles` (logical) — Controls whether file data is synced. Default: `false` (files are always uploaded regardless).
- `Verbose` (logical) — Enables verbose progress output. Default: `true`.
- `FileUploadStrategy` (string) — `"batch"` (default, uses ZIP archives) or `"serial"` (uploads files one at a time). Use `"serial"` as a fallback if batch upload fails.

**Additional name-value inputs:**
- `uploadAsNew` (logical) — If `true`, a new remote dataset is always created even if one already exists for this local dataset. The local reference to the original remote dataset is removed, but the original remote dataset is not deleted. Default: `false`.
- `skipMetadataEditorMetadata` (logical) — If `true`, skips automatic metadata generation from the dataset. You must provide `remoteDatasetName` when using this option. Default: `false`.
- `remoteDatasetName` (char) — The name to assign to the dataset on the remote server. Required if `skipMetadataEditorMetadata` is `true`.

**Outputs:**
- `success` (logical) — `true` if the upload succeeded.
- `cloudDatasetId` (string) — The cloud dataset identifier of the uploaded (or existing) remote dataset.
- `message` (string) — An error message if `success` is `false`.

The function performs three steps: (1) creates a remote dataset record (or reuses an existing one), (2) uploads all NDI documents, and (3) uploads associated binary files.

### Lower-Level Upload Functions (`ndi.cloud.upload.*`)

#### `ndi.cloud.upload.uploadDocumentCollection`

```matlab
[b, report] = ndi.cloud.upload.uploadDocumentCollection(datasetId, documentList)
[b, report] = ndi.cloud.upload.uploadDocumentCollection(datasetId, documentList, maxDocumentChunk=N)
```

Uploads a collection of `ndi.document` objects to a cloud dataset. Uses bulk (ZIP-based) upload by default; falls back to serial upload if the environment variable `NDI_CLOUD_UPLOAD_NO_ZIP` is set to `'true'`.

**Inputs:**
- `datasetId` (string) — The cloud dataset identifier.
- `documentList` (cell array) — A cell array of `ndi.document` objects to upload.

**Optional name-value inputs:**
- `maxDocumentChunk` (double) — Maximum number of documents per ZIP batch. Default: `Inf` (all in one batch).
- `onlyUploadMissing` (logical) — If `true`, documents already present on the remote are skipped. Default: `true`.

**Outputs:**
- `b` (logical) — `true` if the entire upload succeeded.
- `report` (struct) — Upload report with fields:
  - `uploadType` — `'batch'` or `'serial'` or `'none'`.
  - `manifest` — Cell array of document IDs per batch.
  - `status` — `'success'` or `'failure'` for each batch.

#### `ndi.cloud.upload.newDataset`

```matlab
datasetId = ndi.cloud.upload.newDataset(D)
```

Creates a new dataset record on NDI Cloud from an `ndi.dataset` object and uploads its documents and files. Returns the `cloudDatasetID` of the newly created dataset.

#### `ndi.cloud.upload.uploadToNDICloud`

```matlab
[b, msg] = ndi.cloud.upload.uploadToNDICloud(S, dataset_id)
```

Uploads an NDI session's database (documents and files) to an existing cloud dataset identified by `dataset_id`. This is an older interface that operates on `ndi.session` objects. Prefer `ndi.cloud.uploadDataset` for new code.

**Inputs:**
- `S` — An `ndi.session` object.
- `dataset_id` — The cloud dataset identifier to upload into.

**Outputs:**
- `b` — `1` if successful, `0` otherwise.
- `msg` — An error message if the upload failed; `''` otherwise.

#### `ndi.cloud.upload.scanForUpload`

```matlab
[doc_json_struct, doc_file_struct, total_size] = ndi.cloud.upload.scanForUpload(S, d, new, dataset_id)
```

Scans a set of documents for their JSON content and associated binary files, and determines which items still need to be uploaded to the cloud.

**Inputs:**
- `S` — An `ndi.session` object.
- `d` — Documents returned by a `database_search` call.
- `new` — `1` if this is a brand-new dataset with no prior uploads; `0` otherwise.
- `dataset_id` — The cloud dataset identifier (may be `''` for new datasets).

**Outputs:**
- `doc_json_struct` — Struct array with fields `docid` and `is_uploaded` for each document.
- `doc_file_struct` — Struct array with fields `uid`, `name`, `docid`, `bytes`, and `is_uploaded` for each file.
- `total_size` — Total size (in KB) of files that still need to be uploaded.

---

## Synchronization

Synchronization functions keep a local NDI dataset and its cloud counterpart in correspondence. The primary entry point is `ndi.cloud.syncDataset`; the individual mode functions in `ndi.cloud.sync.*` can also be called directly.

### Synchronization Options: `ndi.cloud.sync.SyncOptions`

All synchronization functions accept options that conform to the `ndi.cloud.sync.SyncOptions` class. The available options are:

| Option | Type | Default | Description |
|---|---|---|---|
| `SyncFiles` | logical | `false` | If `true`, binary file data is downloaded along with document metadata. Files are always uploaded regardless of this setting. |
| `Verbose` | logical | `true` | If `true`, detailed progress messages are printed. |
| `DryRun` | logical | `false` | If `true`, actions are logged but not actually performed. |
| `FileUploadStrategy` | string | `"batch"` | `"batch"` uses ZIP archives for efficient bulk upload; `"serial"` uploads files one at a time (use as a fallback). |

### Primary Synchronization Function

#### `ndi.cloud.syncDataset`

```matlab
ndi.cloud.syncDataset(ndiDataset, 'SyncMode', syncMode, ...)
```

The primary entry point for synchronizing a local NDI dataset with its cloud counterpart. Dispatches to the appropriate sync mode function based on `SyncMode`.

**Inputs:**
- `ndiDataset` (ndi.dataset) — The local NDI dataset to synchronize.

**Name-value inputs:**
- `SyncMode` (ndi.cloud.sync.enum.SyncMode) — The synchronization strategy. Default: `"DownloadNew"`. Available modes:

  | Mode | Description |
  |---|---|
  | `"DownloadNew"` | Downloads documents added to the remote since the last sync. No deletions. |
  | `"UploadNew"` | Uploads documents added locally since the last sync. No deletions. |
  | `"MirrorFromRemote"` | Makes local an exact copy of remote: downloads missing docs, deletes local extras. Remote is unchanged. |
  | `"MirrorToRemote"` | Makes remote an exact copy of local: uploads missing docs, deletes remote extras. Local is unchanged. |
  | `"TwoWaySync"` | Bidirectional additive sync: uploads local-only docs and downloads remote-only docs. No deletions. |

- All `ndi.cloud.sync.SyncOptions` properties (`SyncFiles`, `Verbose`, `DryRun`, `FileUploadStrategy`) are accepted as additional name-value pairs.

**Example:**
```matlab
% Download new documents from the cloud
ndi.cloud.syncDataset(myDataset, 'SyncMode', "DownloadNew");

% Mirror local to remote without syncing file data
ndi.cloud.syncDataset(myDataset, 'SyncMode', "MirrorToRemote", 'SyncFiles', false);

% Simulate a two-way sync without making changes
ndi.cloud.syncDataset(myDataset, 'SyncMode', "TwoWaySync", 'DryRun', true);
```

### Individual Sync Mode Functions (`ndi.cloud.sync.*`)

#### `ndi.cloud.sync.downloadNew`

```matlab
[success, errorMessage, report] = ndi.cloud.sync.downloadNew(ndiDataset, ...)
```

Downloads documents that exist on the remote but were not present at the last sync. No documents are deleted locally or remotely.

Uses a sync index file (`[dataset.path]/.ndi/sync/index.json`) to track the remote document state at the last sync and identify what is new.

**Outputs:** `success` (logical), `errorMessage` (string), `report` (struct with field `downloaded_document_ids`).

#### `ndi.cloud.sync.uploadNew`

```matlab
[success, errorMessage, report] = ndi.cloud.sync.uploadNew(ndiDataset, ...)
```

Uploads documents that were added locally since the last sync. No documents are deleted locally or remotely.

**Outputs:** `success` (logical), `errorMessage` (string), `report` (struct with fields `uploaded_document_ids` and `uploaded_documents_report`).

#### `ndi.cloud.sync.mirrorFromRemote`

```matlab
[success, errorMessage, report] = ndi.cloud.sync.mirrorFromRemote(ndiDataset, ...)
```

Makes the local dataset an exact mirror of the remote:
1. Downloads remote documents not present locally.
2. Deletes local documents not present on the remote.

The remote dataset is not modified.

**Outputs:** `success` (logical), `errorMessage` (string), `report` (struct with fields `downloaded_document_ids` and `deleted_local_document_ids`).

#### `ndi.cloud.sync.mirrorToRemote`

```matlab
[success, errorMessage, report] = ndi.cloud.sync.mirrorToRemote(ndiDataset, ...)
```

Makes the remote dataset an exact mirror of the local dataset:
1. Uploads local documents not present on the remote.
2. Deletes remote documents not present locally.

The local dataset is not modified.

**Outputs:** `success` (logical), `errorMessage` (string), `report` (struct with fields `uploaded_document_ids`, `deleted_remote_document_ids`, and `uploaded_documents_report`).

#### `ndi.cloud.sync.twoWaySync`

```matlab
[success, errorMessage, report] = ndi.cloud.sync.twoWaySync(ndiDataset, ...)
```

Performs a bidirectional additive synchronization:
1. Uploads local-only documents to the remote.
2. Downloads remote-only documents to local.

No documents are deleted from either side.

**Outputs:** `success` (logical), `errorMessage` (string), `report` (struct with fields `uploaded_document_ids`, `downloaded_document_ids`, and `uploaded_documents_report`).

#### `ndi.cloud.sync.validate`

```matlab
[comparison_report, local_comparison_structs, remote_comparison_structs] = ndi.cloud.sync.validate(ndiDataset, ...)
```

Compares a local NDI dataset against its cloud counterpart, identifying documents that exist only locally, only remotely, or on both sides — and for common documents, checking whether their content matches.

**Name-value inputs:**
- `Mode` (string) — `"bulk"` (default, downloads all remote docs at once for faster comparison) or `"serial"` (downloads and compares documents one at a time).
- `Verbose` (logical) — Enables verbose output. Default: `true`.

**Outputs:**
- `comparison_report` (struct) — Fields:
  - `local_only_ids` — NDI IDs of documents found only locally.
  - `remote_only_ids` — NDI IDs of documents found only on the remote.
  - `common_ids` — NDI IDs of documents found in both.
  - `mismatched_ids` — NDI IDs of common documents whose content does not match.
  - `mismatch_details` — Struct array with `ndiId`, `apiId`, and `reason` for each mismatch.
- `local_comparison_structs` — Cell array of local document property structs for mismatched documents.
- `remote_comparison_structs` — Cell array of remote document property structs for mismatched documents.

---

## NDI Cloud API Reference (`ndi.cloud.api.*`)

The `ndi.cloud.api.*` namespace provides direct, one-to-one wrappers around the NDI Cloud REST API. Each function follows the same return convention:

```matlab
[b, answer, apiResponse, apiURL] = ndi.cloud.api.<subpackage>.<function>(...)
```

Where:
- `b` (logical) — `true` if the API call succeeded, `false` otherwise.
- `answer` — On success, the parsed response body (struct, string, or value). On failure, an error struct.
- `apiResponse` — The full `matlab.net.http.ResponseMessage` object.
- `apiURL` — The URL that was called.

> **Note on `ndi.cloud.api.implementation.*`**: Each `ndi.cloud.api.*` function delegates to a corresponding class in `ndi.cloud.api.implementation.*`. These implementation classes handle the details of constructing HTTP requests and parsing responses. They are not intended to be used directly by application developers.

### Authentication (`ndi.cloud.api.auth.*`)

| Function | Signature | Description |
|---|---|---|
| `ndi.cloud.api.auth.login` | `login(email, password)` | Authenticates a user and retrieves a session token. Returns token and user info including organization ID. |
| `ndi.cloud.api.auth.logout` | `logout()` | Invalidates the current session token on the server. |
| `ndi.cloud.api.auth.changePassword` | `changePassword(oldPassword, newPassword)` | Updates the current user's password. |
| `ndi.cloud.api.auth.resetPassword` | `resetPassword(email)` | Sends a password reset email to the specified address. |
| `ndi.cloud.api.auth.resendConfirmation` | `resendConfirmation(email)` | Resends the account confirmation email. |
| `ndi.cloud.api.auth.verifyUser` | `verifyUser(token)` | Verifies a user account using a verification token. |

### Users (`ndi.cloud.api.users.*`)

| Function | Signature | Description |
|---|---|---|
| `ndi.cloud.api.users.me` | `me()` | Retrieves the current authenticated user's profile information. |
| `ndi.cloud.api.users.createUser` | `createUser(email, name, password)` | Registers a new user account. |
| `ndi.cloud.api.users.GetUser` | `GetUser(userId)` | Retrieves profile information for a user specified by ID. |

### Datasets (`ndi.cloud.api.datasets.*`)

| Function | Signature | Description |
|---|---|---|
| `ndi.cloud.api.datasets.createDataset` | `createDataset(datasetInfoStruct)` | Creates a new dataset record in the cloud. Returns the new `cloudDatasetID`. |
| `ndi.cloud.api.datasets.getDataset` | `getDataset(cloudDatasetID)` | Retrieves the full details for a dataset, including its document and file lists. |
| `ndi.cloud.api.datasets.updateDataset` | `updateDataset(cloudDatasetID, datasetInfoStruct)` | Updates a dataset's metadata. |
| `ndi.cloud.api.datasets.deleteDataset` | `deleteDataset(cloudDatasetID, 'when', '7d')` | Marks a dataset for deletion. The `when` option specifies when deletion occurs (e.g., `'7d'`, `'now'`). |
| `ndi.cloud.api.datasets.listDatasets` | `listDatasets('page', P, 'pageSize', PS)` | Lists datasets in the current user's organization. Supports pagination. |
| `ndi.cloud.api.datasets.listDeletedDatasets` | `listDeletedDatasets()` | Lists datasets that have been marked for deletion. |
| `ndi.cloud.api.datasets.undeleteDataset` | `undeleteDataset(cloudDatasetID)` | Restores a dataset that was marked for deletion. |
| `ndi.cloud.api.datasets.publishDataset` | `publishDataset(cloudDatasetID)` | Marks a dataset as publicly published. |
| `ndi.cloud.api.datasets.unpublishDataset` | `unpublishDataset(cloudDatasetID)` | Reverts a dataset to unpublished status. |
| `ndi.cloud.api.datasets.submitDataset` | `submitDataset(cloudDatasetID)` | Submits a dataset for administrative review. |
| `ndi.cloud.api.datasets.getPublished` | `getPublished('page', P, 'pageSize', PS)` | Retrieves a paginated list of published datasets. |
| `ndi.cloud.api.datasets.getUnpublished` | `getUnpublished('page', P, 'pageSize', PS)` | Retrieves a paginated list of unpublished datasets. |
| `ndi.cloud.api.datasets.getBranches` | `getBranches(cloudDatasetID)` | Retrieves the list of branches for a given dataset. |
| `ndi.cloud.api.datasets.createDatasetBranch` | `createDatasetBranch(cloudDatasetID, branchInfo)` | Creates a new branch for a dataset. |

### Documents (`ndi.cloud.api.documents.*`)

| Function | Signature | Description |
|---|---|---|
| `ndi.cloud.api.documents.addDocument` | `addDocument(cloudDatasetID, jsonDocument)` | Adds a single document (provided as a JSON string) to a dataset. |
| `ndi.cloud.api.documents.addDocumentAsFile` | `addDocumentAsFile(cloudDatasetID, jsonDocument)` | Adds a single document to a dataset by uploading it as a file. |
| `ndi.cloud.api.documents.getDocument` | `getDocument(cloudDatasetID, cloudDocumentID)` | Retrieves the content of a single document by its cloud API document ID. |
| `ndi.cloud.api.documents.updateDocument` | `updateDocument(cloudDatasetID, cloudDocumentID, jsonDocument)` | Replaces the content of an existing document. |
| `ndi.cloud.api.documents.deleteDocument` | `deleteDocument(cloudDatasetID, cloudDocumentID, 'when', '7d')` | Marks a single document for deletion. |
| `ndi.cloud.api.documents.bulkDeleteDocuments` | `bulkDeleteDocuments(cloudDatasetID, cloudDocumentIDs, 'when', '7d')` | Marks multiple documents for deletion in a single call. |
| `ndi.cloud.api.documents.listDatasetDocuments` | `listDatasetDocuments(cloudDatasetID, 'page', P, 'pageSize', PS)` | Retrieves a paginated list of document summaries (ID, ndiID, name, className) from a dataset. |
| `ndi.cloud.api.documents.listDatasetDocumentsAll` | `listDatasetDocumentsAll(cloudDatasetID, 'pageSize', PS)` | Retrieves all document summaries from a dataset by automatically handling pagination. |
| `ndi.cloud.api.documents.listDeletedDocuments` | `listDeletedDocuments(cloudDatasetID)` | Lists documents that have been marked for deletion in a dataset. |
| `ndi.cloud.api.documents.countDocuments` | `countDocuments(cloudDatasetID)` | Returns the total number of documents in a dataset (via a dedicated count endpoint). |
| `ndi.cloud.api.documents.documentCount` | `documentCount(cloudDatasetID)` | Returns the total number of documents via an alternative count endpoint. |
| `ndi.cloud.api.documents.getBulkDownloadURL` | `getBulkDownloadURL(cloudDatasetID, 'cloudDocumentIDs', ids)` | Returns a pre-signed URL for downloading a ZIP archive of specified documents (or all documents if none specified). |
| `ndi.cloud.api.documents.getBulkUploadURL` | `getBulkUploadURL(cloudDatasetID)` | Returns a pre-signed URL for uploading a ZIP archive of documents to a dataset. |
| `ndi.cloud.api.documents.ndiquery` | `ndiquery(scope, query_obj, 'page', P, 'pageSize', PS)` | Executes an `ndi.query` against the cloud database within the given scope (`'public'`, `'private'`, or `'all'`). Returns a paginated result. |
| `ndi.cloud.api.documents.ndiqueryAll` | `ndiqueryAll(scope, query_obj, 'pageSize', PS)` | Executes an `ndi.query` against the cloud database and automatically paginates to return all matching documents. |

### Files (`ndi.cloud.api.files.*`)

| Function | Signature | Description |
|---|---|---|
| `ndi.cloud.api.files.getFileDetails` | `getFileDetails(cloudDatasetID, cloudFileUID)` | Retrieves metadata for a single file, including a pre-signed download URL. |
| `ndi.cloud.api.files.getFile` | `getFile(downloadURL, downloadedFile, 'useCurl', false)` | Downloads a file from a pre-signed URL and saves it to a local path. Set `useCurl` to `true` to use the system `curl` command as a fallback. |
| `ndi.cloud.api.files.getFileUploadURL` | `getFileUploadURL(cloudDatasetID, cloudFileUID)` | Returns a pre-signed URL for uploading a single file. |
| `ndi.cloud.api.files.getFileCollectionUploadURL` | `getFileCollectionUploadURL(cloudDatasetID)` | Returns a pre-signed URL for uploading a ZIP archive of multiple files. |
| `ndi.cloud.api.files.putFiles` | `putFiles(preSignedURL, filePath, 'useCurl', false)` | Uploads a local file to a pre-signed URL via HTTP PUT. Set `useCurl` to `true` to use the system `curl` command as a fallback. |
| `ndi.cloud.api.files.listFiles` | `listFiles(cloudDatasetId, ...)` | Lists all files associated with a dataset, with optional polling for newly uploaded files. |

### Compute (`ndi.cloud.api.compute.*`)

The compute API supports running cloud-side computational pipelines against NDI datasets.

| Function | Signature | Description |
|---|---|---|
| `ndi.cloud.api.compute.startSession` | `startSession(pipelineId, inputParameters)` | Starts a new compute session for the specified pipeline. `inputParameters` is an optional struct. |
| `ndi.cloud.api.compute.getSessionStatus` | `getSessionStatus(sessionId)` | Retrieves the current status and details of a compute session. |
| `ndi.cloud.api.compute.listSessions` | `listSessions()` | Lists all compute sessions associated with the current user. |
| `ndi.cloud.api.compute.abortSession` | `abortSession(sessionId)` | Aborts a running compute session. |
| `ndi.cloud.api.compute.finalizeSession` | `finalizeSession(sessionId)` | Finalizes a compute session. |
| `ndi.cloud.api.compute.triggerStage` | `triggerStage(sessionId, stageId)` | Triggers a specific stage within a running compute session. |
