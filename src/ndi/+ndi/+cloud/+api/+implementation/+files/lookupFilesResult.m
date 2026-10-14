function result = lookupFilesResult(decodedData)
%LOOKUPFILESRESULT Turn a POST /files/lookup response body into a result struct.
%
%   RESULT = ndi.cloud.api.implementation.files.LOOKUPFILESRESULT(DECODEDDATA)
%
%   Takes the decoded body rather than the ResponseMessage, so a test can
%   exercise it without a server.
%
%   Inputs:
%       decodedData - The decoded response body (apiResponse.Body.Data): a
%                     struct with fields `files` and `missing`.
%
%   Outputs:
%       result - struct with fields:
%                  files   - Nx1 struct array (uid, uploaded, size, crc32);
%                            see ndi.cloud.api.implementation.files.fileMetadataArray
%                  missing - 1xM string array of requested uids that have no
%                            file record in the dataset
%
%   See also: ndi.cloud.api.files.lookupFiles

    arguments
        decodedData
    end

    rawFiles = [];
    rawMissing = [];
    if isstruct(decodedData)
        if isfield(decodedData, 'files')
            rawFiles = decodedData.files;
        end
        if isfield(decodedData, 'missing')
            rawMissing = decodedData.missing;
        end
    end

    result.files = ndi.cloud.api.implementation.files.fileMetadataArray(rawFiles);
    if isempty(rawMissing)
        result.missing = strings(1, 0);
    else
        result.missing = reshape(string(rawMissing), 1, []);
    end
end
