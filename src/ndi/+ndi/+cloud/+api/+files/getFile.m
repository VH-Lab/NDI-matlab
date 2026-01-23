function [b, answer, apiResponse, apiURL] = getFile(downloadURL, downloadedFile, options)
%GETFILE Downloads a file from a given pre-signed URL.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFile(DOWNLOADURL, DOWNLOADEDFILE, ...)
%
%   Performs an HTTP GET request to download the file from the DOWNLOADURL
%   and saves it to the local path specified by DOWNLOADEDFILE.
%
%   Inputs:
%       downloadURL     - The pre-signed URL for the download, obtained from the API.
%       downloadedFile  - The path to save the downloaded file.
%
%   Name-Value Pairs:
%       'useCurl' (logical) - If true, the function will use a system call
%                             to the `curl` command-line tool to perform the
%                             download. This can be a robust fallback if the native
%                             MATLAB HTTP client fails. Defaults to false.
%
%   Outputs:
%       b            - True if the download succeeded, false otherwise.
%       answer       - A success message or an error structure from the server.
%       apiResponse  - The full matlab.net.http.ResponseMessage object (or a struct
%                      if using curl).
%       apiURL       - The URL that was called (the downloadURL).
%
%   Example:
%       % Get details (including a download URL) for a single file
%       [s, fileInfo] = ndi.cloud.api.files.getFileDetails('d-123', 'f-abc');
%       if s
%           % If successful, download the file
%           [s2] = ndi.cloud.api.files.getFile(fileInfo.downloadUrl, 'localfile.dat');
%       end
%
%   See also: ndi.cloud.api.implementation.files.GetFile,
%             ndi.cloud.api.files.getFileDetails
%
    arguments
        downloadURL (1,1) string
        downloadedFile (1,1) string
        options.useCurl (1,1) logical = false
    end
    % 1. Create an instance of the implementation class, passing the options.
    api_call = ndi.cloud.api.implementation.files.GetFile(...
        'downloadURL', downloadURL, ...
        'downloadedFile', downloadedFile, ...
        'useCurl', options.useCurl);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end