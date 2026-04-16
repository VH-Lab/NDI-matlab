function [b, answer, apiResponse, apiURL] = bulkFetch(cloudDatasetID, cloudDocumentIDs)
%BULKFETCH User-facing wrapper to synchronously fetch multiple documents by ID.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.bulkFetch(CLOUD_DATASET_ID, CLOUD_DOCUMENT_IDS)
%
%   Synchronously fetches up to 500 documents (with full data) from a dataset
%   on the NDI Cloud in a single call. This is the fast, synchronous companion
%   to the asynchronous ndi.cloud.api.documents.getBulkDownloadURL pipeline and
%   is intended for small sets (e.g. a subset of IDs returned by /ndiquery).
%
%   Documents that do not exist, are soft-deleted, or do not belong to the
%   specified dataset are silently omitted from the response (not an error).
%   Callers should compare the input IDs to the returned IDs if they need to
%   detect "missing" documents. Order of the returned documents is not
%   guaranteed to match the request order.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset containing the documents.
%       cloudDocumentIDs - A string array of cloud API document IDs to fetch.
%                          Must be non-empty, at most 500 entries, and each
%                          entry must be a 24-character hex string.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - On success, a struct array of document entries, each with
%                      fields id, ndiId, name, className, datasetId, data.
%                      On failure, the error body returned by the server.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       doc_ids = ["65a1b2c3d4e5f6789abcdef0", "65a1b2c3d4e5f6789abcdef1"];
%       [success, docs] = ndi.cloud.api.documents.bulkFetch('d-12345', doc_ids);
%
%   See also: ndi.cloud.api.implementation.documents.BulkFetch,
%             ndi.cloud.api.documents.getDocument,
%             ndi.cloud.api.documents.getBulkDownloadURL

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentIDs (1,:) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.BulkFetch(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentIDs', cloudDocumentIDs);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
