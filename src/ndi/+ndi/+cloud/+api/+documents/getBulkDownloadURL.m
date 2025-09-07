function [b, answer, apiResponse, apiURL] = getBulkDownloadURL(cloudDatasetID, args)
%GETBULKDOWNLOADURL User-facing wrapper to get a bulk document download URL.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.getBulkDownloadURL(CLOUDDATASETID, 'cloudDocumentIDs', DOC_IDS)
%
%   Retrieves a pre-signed URL that can be used to download a zip archive
%   containing multiple documents from a dataset.
%
%   Inputs:
%       cloudDatasetID     - The ID of the dataset.
%   Name-Value Inputs:
%       cloudDocumentIDs   - (Optional) A string array of cloud API document IDs to download.
%                            If not provided, the URL will be for an archive of ALL
%                            documents in the dataset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The pre-signed download URL on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       % Get URL for all documents
%       [success, url] = ndi.cloud.api.documents.getBulkDownloadURL('d-12345');
%
%       % Get URL for specific documents
%       doc_ids = ["doc-abc", "doc-def"];
%       [success, url] = ndi.cloud.api.documents.getBulkDownloadURL('d-12345', 'cloudDocumentIDs', doc_ids);
%
%   See also: ndi.cloud.api.implementation.documents.GetBulkDownloadURL

    arguments
        cloudDatasetID (1,1) string
        args.cloudDocumentIDs (1,:) string = ""
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.GetBulkDownloadURL(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentIDs', args.cloudDocumentIDs);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

