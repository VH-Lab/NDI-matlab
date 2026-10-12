function [b, answer, apiResponse, apiURL] = getFileUploadURL(cloudDatasetID, cloudFileUID, options)
%GETFILEUPLOADURL Get a pre-signed URL for uploading a single file.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFileUploadURL(CLOUDDATASETID, CLOUDFILEUID)
%   [...] = ndi.cloud.api.files.getFileUploadURL(..., 'checksumCRC32', CRC)
%
%   Retrieves a URL that can be used to PUT the contents of a single file
%   for a dataset.
%
%   Inputs:
%       cloudDatasetID      - The ID of the dataset.
%       cloudFileUID        - The unique identifier that will be used for the file.
%
%   Name-Value Inputs:
%       checksumCRC32       - (Optional) The file's CRC-32 as base64 of its
%                             4-byte big-endian value (ndi.fun.file.crc32).
%                             When given, the URL is signed with it, so S3
%                             rejects an upload whose content does not match,
%                             and the cloud records it as the file's crc32.
%                             Default "" (no checksum).
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The pre-signed upload URL (string) on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, upload_url] = ndi.cloud.api.files.getFileUploadURL('d-12345', 'f-newfile');
%
%       % With a checksum, so a corrupted upload is refused:
%       crc = ndi.fun.file.crc32('myfile.dat');
%       [success, upload_url] = ndi.cloud.api.files.getFileUploadURL('d-12345', 'f-newfile', ...
%           'checksumCRC32', crc);
%
%   See also: ndi.cloud.api.implementation.files.GetFileUploadURL,
%             ndi.fun.file.crc32

    arguments
        cloudDatasetID (1,1) string
        cloudFileUID (1,1) string
        options.checksumCRC32 (1,1) string = ""
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.GetFileUploadURL(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudFileUID', cloudFileUID, ...
        'checksumCRC32', options.checksumCRC32);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

