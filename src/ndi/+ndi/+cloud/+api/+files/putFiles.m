function [b, answer, apiResponse, apiURL] = putFiles(preSignedURL, filePath, options)
%PUTFILES Uploads a local file to a given pre-signed URL.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.putFiles(PRESIGNEDURL, FILEPATH, ...)
%
%   Performs an HTTP PUT request to upload the file specified by FILEPATH
%   to the PRESIGNEDURL. This is typically used after obtaining a URL from
%   a function like getFileUploadURL or getFileCollectionUploadURL.
%
%   Inputs:
%       preSignedURL - The pre-signed URL for the upload, obtained from the API.
%       filePath     - The path to the local file to upload.
%
%   Name-Value Pairs:
%       'useCurl' (logical) - If true, the function will use a system call
%                             to the `curl` command-line tool to perform the
%                             upload. This can be a robust fallback if the native
%                             MATLAB HTTP client fails. Defaults to false.
%
%   Outputs:
%       b            - True if the upload succeeded (HTTP 200), false otherwise.
%       answer       - A success message or an error structure from the server.
%       apiResponse  - The full matlab.net.http.ResponseMessage object (or a struct
%                      if using curl).
%       apiURL       - The URL that was called (the preSignedURL).
%
%   Example:
%       % Get a URL for a single file upload
%       [s, url] = ndi.cloud.api.files.getFileUploadURL('d-123', 'f-abc');
%       if s
%           % If successful, upload the local file
%           [s2] = ndi.cloud.api.files.putFiles(url, 'localfile.dat');
%       end
%
%   See also: ndi.cloud.api.implementation.files.PutFiles,
%             ndi.cloud.api.files.getFileUploadURL,
%             ndi.cloud.api.files.getFileCollectionUploadURL
%
    arguments
        preSignedURL (1,1) string
        filePath (1,1) string {mustBeFile}
        options.useCurl (1,1) logical = false
    end
    % 1. Create an instance of the implementation class, passing the options.
    api_call = ndi.cloud.api.implementation.files.PutFiles(...
        'preSignedURL', preSignedURL, ...
        'filePath', filePath, ...
        'useCurl', options.useCurl);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

