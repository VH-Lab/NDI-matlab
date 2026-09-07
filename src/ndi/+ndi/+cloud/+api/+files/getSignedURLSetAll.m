function [b, answer, apiResponse, apiURL] = getSignedURLSetAll(cloudDatasetID, cloudDocumentID, options)
%GETSIGNEDURLSETALL Walk every page of a document's signed URL set.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getSignedURLSetAll(CLOUDDATASETID, CLOUDDOCUMENTID)
%   [...] = ndi.cloud.api.files.getSignedURLSetAll(..., 'limit', N, 'maxPages', M)
%
%   Calls ndi.cloud.api.files.getSignedURLSet repeatedly, following
%   nextCursor until the server signals no more pages, and merges every
%   page's `files` map into a single struct.
%
%   For a document that references a few thousand files this is fine; for
%   the much larger lightsheet / spatial-transcriptomics case the async
%   job path (createSignedURLSetJob + waitForSignedURLSetJob) is preferred.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset.
%       cloudDocumentID  - The cloud API ID of the document.
%
%   Name-Value Pairs:
%       'limit'    (double) - Per-page limit passed to the server. Default 500.
%       'maxPages' (double) - Safety cap on the number of pages walked.
%                             Default 1000. If reached, b is false and
%                             answer.state is 'maxPagesReached'.
%
%   Outputs:
%       b            - True if every page was fetched successfully.
%       answer       - On success, a struct with fields:
%                        datasetId, documentId, totalCount, pageCount,
%                        pages, expiresAt, files.
%                      `files` is a struct whose field names are file UIDs
%                      and whose values are pre-signed GET URLs.
%       apiResponse  - The matlab.net.http.ResponseMessage from the last page.
%       apiURL       - The URL of the last page.
%
%   See also: ndi.cloud.api.implementation.files.GetSignedURLSetAll,
%             ndi.cloud.api.files.getSignedURLSet,
%             ndi.cloud.api.files.createSignedURLSetJob

    arguments
        cloudDatasetID    (1,1) string
        cloudDocumentID   (1,1) string
        options.limit     (1,1) double = 500
        options.maxPages  (1,1) double = 1000
        options.fileSeries (1,1) string = ""
        % "cloud" (default) sends the mongo _id to the by-_id route;
        % "ndi" sends data.base.id to the ndi-documents route and lets the
        % server resolve it. Callers that hold an NDI document id -- which
        % is both of NDI's own callers -- must say so; passing one as
        % "cloud" is a 404. See NDI-matlab#968.
        options.idNamespace (1,1) string ...
            {mustBeMember(options.idNamespace,["cloud","ndi"])} = "cloud"
    end

    api_call = ndi.cloud.api.implementation.files.GetSignedURLSetAll(...
        'cloudDatasetID',  cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'limit',           options.limit, ...
        'maxPages',        options.maxPages, ...
        'fileSeries',      options.fileSeries, ...
        'idNamespace',     options.idNamespace);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
