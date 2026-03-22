# Instructions for NDI-Python: Remove Outdated Download Pipeline

## Context

The MATLAB codebase (`NDI-matlab`) had two parallel cloud download pipelines for
downloading dataset documents. The older pipeline has been removed because it:

1. Downloads documents **one at a time** instead of in bulk
2. Writes documents to disk as JSON files then re-reads them (unnecessary round-trip)
3. Was missing `rehydrateJSONNanNull` on the read-back path, causing NaN/Infinity
   values encoded as placeholder strings (`"__NDI__NaN__"`, `"__NDI__Infinity__"`,
   `"__NDI__-Infinity__"`) to not be converted back to actual numeric values

## Removed MATLAB Files (Old Pipeline)

These four files have been deleted from NDI-matlab:

| File | Purpose |
|---|---|
| `+ndi/+cloud/+download/dataset.m` | Top-level "download a dataset" entry point. Downloaded files one-by-one, called `datasetDocuments` then `jsons2documents`, built an `ndi.dataset.dir`. |
| `+ndi/+cloud/+download/datasetDocuments.m` | Downloaded documents individually via `ndi.cloud.api.documents.getDocument()`, saved each as a `.json` file on disk. |
| `+ndi/+cloud/+download/jsons2documents.m` | Read `.json` files from disk, ran `jsondecode`, constructed `ndi.document` objects. **Missing NaN rehydration.** |
| `+ndi/+cloud/+download/+internal/setFileInfo.m` | Patched `file_info` fields (`delete_original`, `ingest`, file paths) based on download mode (`local` vs `hybrid`). |

## Modern MATLAB Replacement Files

The current (correct) pipeline uses these files instead:

### Document Download
| File | Purpose |
|---|---|
| `+ndi/+cloud/+download/downloadDocumentCollection.m` | **Bulk downloads** documents as a ZIP via `getBulkDownloadURL` API. Applies `rehydrateJSONNanNull` before `jsondecode`. Handles chunking for large document sets. Returns `ndi.document` objects in memory (no disk round-trip). |
| `+ndi/+cloud/+download/+internal/structsToNdiDocuments.m` | Converts decoded structs to `ndi.document` objects. Called by `downloadDocumentCollection`. |

### File Info Patching (now in sync layer, not download layer)
| File | Purpose |
|---|---|
| `+ndi/+cloud/+sync/+internal/updateFileInfoForLocalFiles.m` | For **local** mode: calls `reset_file_info()` then `add_file()` with local file paths. Replaces the `local` case from old `setFileInfo`. |
| `+ndi/+cloud/+sync/+internal/updateFileInfoForRemoteFiles.m` | For **hybrid/remote** mode: sets `delete_original` and `ingest` to 0. Replaces the `hybrid` case from old `setFileInfo`. |

### File Download
| File | Purpose |
|---|---|
| `+ndi/+cloud/+download/downloadDatasetFiles.m` | Downloads binary files associated with documents. Uses `getFileCollectionUploadURL` / bulk download. |
| `+ndi/+cloud/+download/downloadGenericFiles.m` | Lower-level helper for downloading files by UUID. |

### Top-Level Entry Points
| File | Purpose |
|---|---|
| `+ndi/+cloud/downloadDataset.m` | **Recommended** top-level function for downloading a dataset. Uses `downloadDocumentCollection` internally via the sync pipeline. |
| `+ndi/+cloud/syncDataset.m` | Synchronization entry point (download, upload, mirror, two-way). |

## What to Do in NDI-Python

1. **Search for Python equivalents** of the removed functions:
   - `dataset()` download function (downloads docs one-by-one)
   - `datasetDocuments()` (individual doc download + JSON file save)
   - `jsons2documents()` (reads JSON files from disk)
   - `setFileInfo()` (patches file_info fields)

2. **Check if the Python codebase has a bulk download pipeline** equivalent to
   `downloadDocumentCollection`. If not, that's the modern pattern to implement:
   - Use the bulk download API (`getBulkDownloadURL`) to get a ZIP of documents
   - Apply NaN/Infinity rehydration before JSON decoding
   - Return document objects in memory without a disk round-trip

3. **Check NaN handling**: Ensure any JSON decoding of cloud documents handles the
   placeholder strings `"__NDI__NaN__"`, `"__NDI__Infinity__"`, `"__NDI__-Infinity__"`
   and converts them to actual `float('nan')`, `float('inf')`, `float('-inf')`.

4. **File info patching** should be separated from the download step — it belongs
   in the sync layer, not the download layer.

5. **Remove** any Python equivalents of the four deleted MATLAB files if they exist
   and are not called by other code paths.
