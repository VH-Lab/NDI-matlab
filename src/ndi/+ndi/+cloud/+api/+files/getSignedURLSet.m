function [b, answer, apiResponse, apiURL] = getSignedURLSet(cloudDatasetID, cloudDocumentID, options)
%GETSIGNEDURLSET Fetch one page of the UID -> signed URL map for a document.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getSignedURLSet(CLOUDDATASETID, CLOUDDOCUMENTID)
%   [...] = ndi.cloud.api.files.getSignedURLSet(..., 'limit', N, 'cursor', C)
%
%   Calls GET /v1/datasets/{datasetId}/documents/{documentId}/signed-url-set
%   and returns one page of the file-set: a UID -> signed URL map for the
%   files the document references, in UID-sorted order.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset.
%       cloudDocumentID  - The cloud API ID of the document.
%
%   Name-Value Pairs:
%       'limit'  (double) - Maximum URLs to return per page. Server default
%                           is 500; server cap is 1000.
%       'cursor' (string) - Opaque cursor from a previous response's
%                           nextCursor. Omit (or "") for the first page.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - On success, a struct with fields:
%                        datasetId, documentId, totalCount, pageCount,
%                        nextCursor (may be missing), expiresAt, files.
%                      `files` is a struct whose field names are file UIDs
%                      (or the wrapped struct form MATLAB unpacks the
%                      server's map into) and whose values are pre-signed
%                      GET URLs.
%                      On failure, the server error payload.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [s, page] = ndi.cloud.api.files.getSignedURLSet('d-123','doc-abc');
%       if s && ~isempty(page.nextCursor)
%           [s2, nextPage] = ndi.cloud.api.files.getSignedURLSet('d-123','doc-abc', ...
%               'cursor', string(page.nextCursor));
%       end
%
%   See also: ndi.cloud.api.implementation.files.GetSignedURLSet,
%             ndi.cloud.api.files.getSignedURLSetAll,
%             ndi.cloud.api.files.createSignedURLSetJob

    arguments
        cloudDatasetID   (1,1) string
        cloudDocumentID  (1,1) string
        options.limit    (1,1) double = 500
        options.cursor   (1,1) string = ""
    end

    api_call = ndi.cloud.api.implementation.files.GetSignedURLSet(...
        'cloudDatasetID',  cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'limit',           options.limit, ...
        'cursor',          options.cursor);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
