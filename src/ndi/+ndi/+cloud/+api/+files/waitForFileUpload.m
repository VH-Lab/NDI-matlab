function [b, answer, apiResponse, apiURL] = waitForFileUpload(cloudDatasetID, cloudFileUIDs, options)
%WAITFORFILEUPLOAD Wait until single-file uploads are recorded by the server.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.waitForFileUpload(CLOUDDATASETID, CLOUDFILEUIDS)
%   [...] = ndi.cloud.api.files.waitForFileUpload(CLOUDDATASETID, CLOUDFILEUIDS, 'timeout', T, ...)
%
%   A PUT to a signed upload URL returning 200 only means S3 has the object.
%   The server then records the upload (uploaded=true, size, crc32) in an
%   S3-triggered step that can lag the PUT by seconds or more when other
%   uploads are queued on the same stage. This function polls
%   ndi.cloud.api.files.lookupFiles at exponentially growing intervals until
%   every uid is marked uploaded or the overall timeout elapses.
%
%   This is the single-file counterpart to waitForBulkUpload; bulk (zip)
%   uploads should use that function, or putFiles(..., 'waitForCompletion',
%   true), instead.
%
%   Inputs:
%       cloudDatasetID - The cloud dataset id.
%       cloudFileUIDs  - String array (or cellstr) of file uids to wait for.
%
%   Name-Value Pairs:
%       'timeout'         (double) - Overall deadline in seconds. Default 120.
%       'initialInterval' (double) - First sleep between polls (s). Default 1.
%       'maxInterval'     (double) - Cap on the per-poll sleep (s). Default 10.
%       'backoffFactor'   (double) - Multiplier applied after each poll. Default 2.
%
%   Outputs:
%       b            - True iff every uid was marked uploaded before the timeout.
%       answer       - Struct describing the final state:
%                        .state   - 'complete' or 'timeout'
%                        .files   - lookupFiles rows (uid, uploaded, size,
%                                   crc32) for the uploaded uids, plus on
%                                   timeout the last rows for pending ones
%                        .pending - string array of uids not yet uploaded
%                                   (including uids with no record)
%                        .elapsed - seconds spent waiting
%       apiResponse  - The ResponseMessage from the last poll.
%       apiURL       - The URL of the last poll.
%
%   Example:
%       [s, url] = ndi.cloud.api.files.getFileUploadURL('d-123', 'f-abc');
%       ndi.cloud.api.files.putFiles(url, 'localfile.dat');
%       b = ndi.cloud.api.files.waitForFileUpload('d-123', 'f-abc');
%
%   See also: ndi.cloud.api.implementation.files.WaitForFileUpload,
%             ndi.cloud.api.files.lookupFiles,
%             ndi.cloud.api.files.putFiles,
%             ndi.cloud.api.files.waitForBulkUpload

    arguments
        cloudDatasetID (1,1) string
        cloudFileUIDs (1,:) string
        options.timeout (1,1) double {mustBePositive} = 120
        options.initialInterval (1,1) double {mustBePositive} = 1
        options.maxInterval (1,1) double {mustBePositive} = 10
        options.backoffFactor (1,1) double {mustBePositive} = 2
    end

    api_call = ndi.cloud.api.implementation.files.WaitForFileUpload(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudFileUIDs', cloudFileUIDs, ...
        'timeout', options.timeout, ...
        'initialInterval', options.initialInterval, ...
        'maxInterval', options.maxInterval, ...
        'backoffFactor', options.backoffFactor);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
