function [b, answer, apiResponse, apiURL] = getSignedURLSet(cloudDatasetID, cloudDocumentID, options)
%GETSIGNEDURLSET Get one page of signed download URLs for a document's files.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.getSignedURLSet(CLOUD_DATASET_ID, CLOUD_DOCUMENT_ID)
%   [...] = ndi.cloud.api.documents.getSignedURLSet(..., 'limit', N, 'cursor', C, 'fileSeries', NAME)
%
%   Returns a uid -> signed URL map for the files a document references,
%   paginated over uid-sorted order with an opaque cursor. Use
%   ndi.cloud.api.documents.getSignedURLSetAll to follow the cursor to the end,
%   or the asynchronous job (createSignedURLSetJob) when the set is large enough
%   that paging is the wrong shape.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset containing the document.
%       cloudDocumentID - The cloud API document ID.
%
%   Name-Value Pairs:
%       'limit'      (double) - Max URLs in this page. Server default 500,
%                               server cap 1000.
%       'cursor'     (string) - Cursor from a previous response's nextCursor.
%                               Omit for the first page.
%       'fileSeries' (string) - Restrict the set to the members of one named
%                               file series. Omit for every file the document
%                               references. A document holding a dual image
%                               pyramid references several series; asking for
%                               one keeps the map to the level being viewed.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - On success, a struct with fields:
%                        files      - containers.Map from uid (char) to signed
%                                     URL (char)
%                        nextCursor - char cursor for the next page, '' when
%                                     this was the last page
%                        expiresAt  - char timestamp when the URLs expire
%                      On failure, the error body returned by the server.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [ok, page] = ndi.cloud.api.documents.getSignedURLSet(dsid, docid, ...
%           'fileSeries', "chunkdata.bin", 'limit', 1000);
%       url = page.files('4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6');
%
%   See also: ndi.cloud.api.implementation.documents.GetSignedURLSet,
%             ndi.cloud.api.documents.getSignedURLSetAll,
%             ndi.cloud.api.documents.createSignedURLSetJob

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentID (1,1) string
        options.limit (1,1) double {mustBePositive, mustBeInteger} = 500
        options.cursor (1,1) string = ""
        options.fileSeries (1,1) string = ""
    end

    api_call = ndi.cloud.api.implementation.documents.GetSignedURLSet(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'limit', options.limit, ...
        'cursor', options.cursor, ...
        'fileSeries', options.fileSeries);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
