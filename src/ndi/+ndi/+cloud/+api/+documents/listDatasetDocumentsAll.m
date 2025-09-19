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
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.ListDatasetDocumentsAll(...
        'cloudDatasetID', cloudDatasetID, ...
        'pageSize', args.pageSize);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

