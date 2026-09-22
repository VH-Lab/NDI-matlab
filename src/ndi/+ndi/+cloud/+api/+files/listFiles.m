function [b, answer, apiResponse, apiURL] = listFiles(cloudDatasetID, args)
% LISTFILES Lists one page of files associated with a given dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.listFiles(CLOUDDATASETID, 'page', P, 'pageSize', PS)
%
%   Retrieves a single, paginated page of file summaries from a cloud dataset.
%   To retrieve the complete file list across all pages, use
%   ndi.cloud.api.files.listFilesAll.
%
%   Inputs:
%       cloudDatasetID  - The unique identifier for the cloud dataset.
%   Name-Value Inputs:
%       page            - (Optional) The page number of results. Default is 1.
%       pageSize        - (Optional) The number of results per page. Default is 1000.
%
%   Outputs:
%       b                   - True if the API call was successful, false otherwise.
%       answer              - A struct array with this page's file details, or an
%                             error structure from the server. The full page
%                             envelope (totalNumber, page, pageSize, files) is
%                             available in APIRESPONSE.Body.Data.
%       apiResponse         - The full matlab.net.http.ResponseMessage object.
%       apiURL              - The URL that was called.
%
%   The ANSWER struct has the following fields:
%       uid                 - The NDI UID of the file.
%       uploaded            - A 0/1 flag indicating if the file has been uploaded.
%       sourceDatasetId     - The cloudDatasetId of the file's parent dataset.
%       size                - The file size in bytes.
%
%   Example:
%       % Get the first page of files
%       [s, files] = ndi.cloud.api.files.listFiles('d-12345');
%
%       % Get the second page with 50 results per page
%       [s, files] = ndi.cloud.api.files.listFiles('d-12345', 'page', 2, 'pageSize', 50);
%
%   See also: ndi.cloud.api.files.listFilesAll,
%             ndi.cloud.api.implementation.files.ListFiles
%
    arguments
        cloudDatasetID (1,1) string
        args.page (1,1) double = 1
        args.pageSize (1,1) double = 1000
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.ListFiles(...
        'cloudDatasetID', cloudDatasetID, ...
        'page', args.page, ...
        'pageSize', args.pageSize);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
