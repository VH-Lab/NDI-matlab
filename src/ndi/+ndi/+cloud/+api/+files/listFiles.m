function [b, answer, apiResponse, apiURL] = listFiles(cloudDatasetId, options)
% LISTFILES Lists all files associated with a given dataset
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.listFiles(CLOUDDATASETID, OPTIONS)
%
%   Retrieves a list of all files within a specified cloud dataset.
%
%   Inputs:
%       cloudDatasetId      - The unique identifier for the cloud dataset.
%       options             - A struct with the following optional fields:
%           checkForUpdates - If true, the function will check for new files that
%                             were added while it was running. Default is true.
%           waitForUpdates  - The time in seconds to wait before re-checking for
%                             updates. Default is 10.
%           maximumNumberUpdateReads - The maximum number of times to re-poll for
%                                      updates. Default is 100.
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
%       [s, files] = ndi.cloud.api.files.listFiles('d-12345', ...
%           'checkForUpdates', false);
%       if s
%           disp(['Found ' num2str(numel(files)) ' files.']);
%       end
%
%   See also: ndi.cloud.api.implementation.files.ListFiles,
%             ndi.cloud.api.datasets.getDataset
%
    arguments
        cloudDatasetId (1,1) string
        options.checkForUpdates (1,1) logical = true
        options.waitForUpdates (1,1) {mustBeNumeric} = 10
        options.maximumNumberUpdateReads (1,1) {mustBeNumeric} = 100
    end

    % 1. Create an instance of the implementation class
    api_call = ndi.cloud.api.implementation.files.ListFiles(...
        'cloudDatasetId', cloudDatasetId, ...
        'checkForUpdates', options.checkForUpdates, ...
        'waitForUpdates', options.waitForUpdates, ...
        'maximumNumberUpdateReads', options.maximumNumberUpdateReads);

    % 2. Call the execute method and return its outputs directly
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
