function [b, answer, apiResponse, apiURL] = lookupFiles(cloudDatasetID, cloudFileUIDs)
%LOOKUPFILES Look up the upload state, size and CRC-32 of files by uid.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.lookupFiles(CLOUDDATASETID, CLOUDFILEUIDS)
%
%   Asks NDI Cloud, for each uid, whether the dataset has the file, whether it
%   finished uploading, its size, and the CRC-32 recorded at upload. Use it to
%   decide which files of a document or import batch still need uploading
%   (for example to resume an interrupted upload) without listing the whole
%   dataset. No download URLs are signed.
%
%   The server takes at most 5000 uids per call; longer lists are split into
%   several calls and the results merged. Duplicate uids are looked up once.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset.
%       cloudFileUIDs   - String array (or cellstr) of file uids.
%
%   Outputs:
%       b            - True if every call succeeded, false otherwise.
%       answer       - On success, a struct with fields:
%                        files   - Nx1 struct array, one per uid the dataset
%                                  has a record for, with fields
%                                    uid      - char
%                                    uploaded - logical
%                                    size     - double, bytes
%                                    crc32    - char, base64 big-endian CRC-32
%                                               of the content, '' when none
%                                               was recorded
%                        missing - 1xM string array of uids with no record
%                      On failure, the error body from the failing call.
%       apiResponse  - The matlab.net.http.ResponseMessage of the last call
%                      ([] when CLOUDFILEUIDS is empty).
%       apiURL       - The URL of the last call ([] when CLOUDFILEUIDS is empty).
%
%   A cloud copy matches a local file when it is uploaded and its crc32 equals
%   ndi.fun.file.crc32 of the local file. When crc32 is '' (files uploaded
%   without a checksum), compare size instead.
%
%   Example:
%       [ok, r] = ndi.cloud.api.files.lookupFiles(datasetId, uids);
%       for i = 1:numel(r.files)
%           f = r.files(i);
%           localCrc = ndi.fun.file.crc32(fullfile(folder, f.uid));
%           needsUpload = ~f.uploaded || ~strcmp(f.crc32, localCrc);
%       end
%       % r.missing lists uids never uploaded at all.
%
%   See also: ndi.cloud.api.implementation.files.LookupFiles,
%             ndi.fun.file.crc32, ndi.cloud.api.files.getFileUploadURL

    arguments
        cloudDatasetID (1,1) string
        cloudFileUIDs string
    end

    uids = unique(reshape(cloudFileUIDs, 1, []), 'stable');

    b = true;
    answer = struct('files', ndi.cloud.api.implementation.files.fileMetadataArray([]), ...
        'missing', strings(1, 0));
    apiResponse = [];
    apiURL = [];

    maxUids = ndi.cloud.api.implementation.files.LookupFiles.MaxUids;
    for first = 1:maxUids:numel(uids)
        batch = uids(first:min(first + maxUids - 1, numel(uids)));
        api_call = ndi.cloud.api.implementation.files.LookupFiles(...
            'cloudDatasetID', cloudDatasetID, ...
            'cloudFileUIDs', batch);
        [ok, batchAnswer, apiResponse, apiURL] = api_call.execute();
        if ~ok
            b = false;
            answer = batchAnswer;
            return
        end
        answer.files = [answer.files; batchAnswer.files];
        answer.missing = [answer.missing batchAnswer.missing];
    end
end
