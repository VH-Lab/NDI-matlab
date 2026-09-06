function [b, answer, apiResponse, apiURL] = getSignedURLSetAll(cloudDatasetID, cloudDocumentID, options)
%GETSIGNEDURLSETALL Page through a document's signed URL set and merge it.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.getSignedURLSetAll(CLOUD_DATASET_ID, CLOUD_DOCUMENT_ID)
%   [...] = ndi.cloud.api.documents.getSignedURLSetAll(..., 'fileSeries', NAME, 'limit', N, 'maxPages', P)
%
%   Follows nextCursor until the server runs out of pages and returns the union
%   as a single containers.Map -- the shape a viewer wants, so a pan or zoom is
%   an O(1) uid lookup rather than another round trip.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset containing the document.
%       cloudDocumentID - The cloud API document ID.
%
%   Name-Value Pairs:
%       'limit'      (double) - Page size. Server default 500, cap 1000.
%       'fileSeries' (string) - Restrict to one named file series.
%       'maxPages'   (double) - Stop after this many pages. Default Inf.
%
%   Outputs:
%       b            - True if every page succeeded.
%       answer       - On success, a struct with fields:
%                        files     - containers.Map, the merged set
%                        pages     - number of pages fetched
%                        expiresAt - expiry reported by the last page
%                        complete  - true if the server ran out of pages,
%                                    false if maxPages stopped the walk early
%                      On failure, the error body from the failing page.
%       apiResponse  - The ResponseMessage from the last page fetched.
%       apiURL       - The URL of the last page fetched.
%
%   See also: ndi.cloud.api.implementation.documents.GetSignedURLSetAll,
%             ndi.cloud.api.documents.getSignedURLSet

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentID (1,1) string
        options.limit (1,1) double {mustBePositive, mustBeInteger} = 500
        options.fileSeries (1,1) string = ""
        options.maxPages (1,1) double {mustBePositive} = Inf
    end

    api_call = ndi.cloud.api.implementation.documents.GetSignedURLSetAll(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'limit', options.limit, ...
        'fileSeries', options.fileSeries, ...
        'maxPages', options.maxPages);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
