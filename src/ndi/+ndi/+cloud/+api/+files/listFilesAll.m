function [b, answer, apiResponse, apiURL] = listFilesAll(cloudDatasetID, args)
%LISTFILESALL User-facing wrapper to list ALL files in a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.listFilesAll(CLOUDDATASETID, 'pageSize', PS)
%
%   Retrieves a complete list of all file summaries from a dataset by
%   automatically handling pagination. This is the whole-dataset counterpart
%   to ndi.cloud.api.files.listFiles, which returns a single page.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset.
%   Name-Value Inputs:
%       pageSize        - (Optional) The number of results to fetch per API call.
%                         Default is 1000.
%       checkForUpdates - (Optional) If true, the function will check for new
%                         files that were added while it was running and will
%                         attempt to retrieve them before returning.
%                         Default is false.
%       waitForUpdates  - (Optional) The time in seconds to wait before
%                         re-checking the file count for updates. Default is 5.
%       maximumNumberUpdateReads - (Optional) The maximum number of times the
%                         function will re-poll for updates to prevent an
%                         infinite loop. Default is 100.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct array of file summaries on success, or an
%                      error struct on failure, with the following fields:
%                          uid             - The NDI UID of the file.
%                          uploaded        - 0/1 flag: whether the file is uploaded.
%                          sourceDatasetId - The parent dataset's cloud id.
%                          size            - The file size in bytes.
%       apiResponse  - An array of matlab.net.http.ResponseMessage objects from
%                      all page calls.
%       apiURL       - An array of the URLs that were called.
%
%   Example:
%       [success, all_files] = ndi.cloud.api.files.listFilesAll('d-12345');
%
%   See also: ndi.cloud.api.implementation.files.ListFilesAll,
%             ndi.cloud.api.files.listFiles

    arguments
        cloudDatasetID (1,1) string
        args.pageSize (1,1) double = 1000
        args.checkForUpdates (1,1) logical = false
        args.waitForUpdates (1,1) double = 5
        args.maximumNumberUpdateReads (1,1) double = 100
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.ListFilesAll(...
        'cloudDatasetID', cloudDatasetID, ...
        'pageSize', args.pageSize, ...
        'checkForUpdates', args.checkForUpdates, ...
        'waitForUpdates', args.waitForUpdates, ...
        'maximumNumberUpdateReads', args.maximumNumberUpdateReads);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
