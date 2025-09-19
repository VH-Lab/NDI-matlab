function [b, answer, apiResponse, apiURL] = listDatasetDocuments(cloudDatasetID, args)
%LISTDATASETDOCUMENTS User-facing wrapper to list documents in a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.listDatasetDocuments(CLOUDDATASETID, 'page', P, 'pageSize', PS)
%
%   Retrieves a paginated list of document summaries from a dataset.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset.
%   Name-Value Inputs:
%       page            - (Optional) The page number of results. Default is 1.
%       pageSize        - (Optional) The number of results per page. Default is 1000.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct containing the document list on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       % Get the first page of documents
%       [success, doc_list] = ndi.cloud.api.documents.listDatasetDocuments('d-12345');
%
%       % Get the second page with 50 results per page
%       [success, doc_list] = ndi.cloud.api.documents.listDatasetDocuments('d-12345', 'page', 2, 'pageSize', 50);
%
%   See also: ndi.cloud.api.implementation.documents.ListDatasetDocuments

    arguments
        cloudDatasetID (1,1) string
        args.page (1,1) double = 1
        args.pageSize (1,1) double = 1000
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.ListDatasetDocuments(...
        'cloudDatasetID', cloudDatasetID, ...
        'page', args.page, ...
        'pageSize', args.pageSize);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

