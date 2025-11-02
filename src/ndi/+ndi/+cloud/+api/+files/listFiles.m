function [b, answer, apiResponse, apiURL] = listFiles(cloudDatasetId)
% LISTFILES Lists all files associated with a given dataset
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.listFiles(CLOUDDATASETID)
%
%   Retrieves a list of all files within a specified cloud dataset.
%
%   Inputs:
%       cloudDatasetId      - The unique identifier for the cloud dataset.
%
%   Outputs:
%       b                   - True if the API call was successful, false otherwise.
%       answer              - A struct array with file details, or an error
%                             structure from the server.
%       apiResponse         - The full matlab.net.http.ResponseMessage object.
%       apiURL              - The URL that was called.
%
%   The ANSWER struct has the following fields:
%       uid                 - The NDI UID of the file.
%       isRaw               - A 0/1 flag indicating if the file is raw.
%       uploaded            - A 0/1 flag indicating if the file has been uploaded.
%       sourceDatasetId     - The cloudDatasetId of the file's parent dataset.
%       size                - The file size in bytes.
%
%   Example:
%       [s, files] = ndi.cloud.api.files.listFiles('d-12345');
%       if s
%           disp(['Found ' num2str(numel(files)) ' files.']);
%       end
%
%   See also: ndi.cloud.api.implementation.files.ListFiles,
%             ndi.cloud.api.datasets.getDataset
%
    arguments
        cloudDatasetId (1,1) string
    end

    % 1. Create an instance of the implementation class
    api_call = ndi.cloud.api.implementation.files.ListFiles(...
        'cloudDatasetId', cloudDatasetId);

    % 2. Call the execute method and return its outputs directly
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
