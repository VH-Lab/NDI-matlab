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
%                             When given, the URL signs the
%                             x-amz-checksum-crc32 header, so the upload must
%                             send it: pass the same value to putFiles as
%                             'checksumCRC32'. S3 then rejects content that
%                             does not match, and the cloud records the value
%                             as the file's crc32.
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
%       ndi.cloud.api.files.putFiles(upload_url, 'myfile.dat', 'checksumCRC32', crc);
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

