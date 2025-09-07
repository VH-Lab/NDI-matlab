function [b, answer, apiResponse, apiURL] = putFiles(preSignedURL, filePath)
%PUTFILES Uploads a local file to a given pre-signed URL.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.putFiles(PRESIGNEDURL, FILEPATH)
%
%   Performs an HTTP PUT request to upload the file specified by FILEPATH
%   to the PRESIGNEDURL. This is typically used after obtaining a URL from
%   a function like getFileUploadURL or getFileCollectionUploadURL.
%
%   Inputs:
%       preSignedURL - The pre-signed URL for the upload.
%       filePath     - The path to the local file to upload.
%
%   Outputs:
%       b            - True if the upload succeeded (HTTP 200), false otherwise.
%       answer       - A success message or an error structure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called (the preSignedURL).
%
%   Example:
%       [s, url] = ndi.cloud.api.files.getFileUploadURL('d-123', 'f-abc');
%       if s, [s2] = ndi.cloud.api.files.putFiles(url, 'localfile.dat'); end
%
%   See also: ndi.cloud.api.implementation.files.PutFiles,
%             ndi.cloud.api.files.getFileUploadURL

    arguments
        preSignedURL (1,1) string
        filePath (1,1) string {mustBeFile}
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.PutFiles(...
        'preSignedURL', preSignedURL, ...
        'filePath', filePath);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

