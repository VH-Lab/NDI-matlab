function [b, answer, apiResponse, apiURL] = listDatasetDocumentsAll(cloudDatasetID, args)
%LISTDATASETDOCUMENTSALL User-facing wrapper to list ALL documents in a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.listDatasetDocumentsAll(CLOUDDATASETID, 'pageSize', PS)
%
%   Retrieves a complete list of all document summaries from a dataset by
%   automatically handling pagination.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset.
%   Name-Value Inputs:
%       pageSize        - (Optional) The number of results to fetch per API call.
%                         Default is 1000.
%       checkForUpdates - (Optional) If true, the function will check for new
%                         documents that were added while it was running and
%                         will attempt to retrieve them before returning.
%                         Default is true.
%       waitForUpdates  - (Optional) The time in seconds to wait before
%                         re-checking the document count for updates.
%                         Default is 5.
%       maximumNumberUpdateReads - (Optional) The maximum number of times the
%                         function will re-poll for updates to prevent an
%                         infinite loop. Default is 100.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct containing the complete document list on success, or an error message on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object from the LAST successful page call.
%       apiURL       - The URL that was called for the LAST successful page.
%
%   Example:
%       [success, all_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll('d-12345');
%
%   See also: ndi.cloud.api.implementation.documents.ListDatasetDocumentsAll, ndi.cloud.api.documents.listDatasetDocuments

    arguments
        cloudDatasetID (1,1) string
        args.pageSize (1,1) double = 1000
        args.checkForUpdates (1,1) logical = true
        args.waitForUpdates (1,1) double = 5
        args.maximumNumberUpdateReads (1,1) double = 100
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.ListDatasetDocumentsAll(...
        'cloudDatasetID', cloudDatasetID, ...
        'pageSize', args.pageSize, ...
        'checkForUpdates', args.checkForUpdates, ...
        'waitForUpdates', args.waitForUpdates, ...
        'maximumNumberUpdateReads', args.maximumNumberUpdateReads);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

