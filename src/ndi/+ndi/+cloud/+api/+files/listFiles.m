function [b, answer, apiResponse, apiURL] = listFiles(cloudDatasetID, args)
% LISTFILES Lists one keyset page of files associated with a given dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.listFiles(CLOUDDATASETID, 'limit', L, 'after', CURSOR)
%
%   Retrieves a single keyset-paginated page of file summaries from a cloud
%   dataset. To retrieve the complete file list across all pages, use
%   ndi.cloud.api.files.listFilesAll.
%
%   Inputs:
%       cloudDatasetID  - The unique identifier for the cloud dataset.
%   Name-Value Inputs:
%       limit           - (Optional) Maximum number of results in the page.
%                         Default is 1000.
%       after           - (Optional) Opaque keyset cursor from a previous page's
%                         response envelope. Omit (or "") for the first page.
%
%   Outputs:
%       b                   - True if the API call was successful, false otherwise.
%       answer              - A struct array with this page's file details, or an
%                             error structure from the server. The page envelope
%                             (cursor, hasMore, totalNumber, files) is available
%                             in APIRESPONSE.Body.Data.
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
%       [s, files, resp] = ndi.cloud.api.files.listFiles('d-12345');
%
%       % Get the next page using the cursor from the previous response
%       [s, files2] = ndi.cloud.api.files.listFiles('d-12345', ...
%           'after', resp.Body.Data.cursor, 'limit', 50);
%
%   See also: ndi.cloud.api.files.listFilesAll,
%             ndi.cloud.api.implementation.files.ListFiles
%
    arguments
        cloudDatasetID (1,1) string
        args.limit (1,1) double = 1000
        args.after (1,1) string = ""
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.ListFiles(...
        'cloudDatasetID', cloudDatasetID, ...
        'limit', args.limit, ...
        'after', args.after);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
