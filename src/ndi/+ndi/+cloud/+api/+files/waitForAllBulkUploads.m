function [b, answer, apiResponse, apiURL] = waitForAllBulkUploads(cloudDatasetID, options)
%WAITFORALLBULKUPLOADS Wait for every bulk-upload job on a dataset to finish.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.waitForAllBulkUploads(CLOUDDATASETID)
%   [...] = ndi.cloud.api.files.waitForAllBulkUploads(CLOUDDATASETID, 'timeout', T, ...)
%
%   Polls ndi.cloud.api.files.listActiveBulkUploads at exponentially
%   growing intervals until no active (queued + extracting) bulk-upload
%   jobs remain on the dataset or the overall timeout elapses. Intended
%   for use at sync-pipeline boundaries: before inventorying remote
%   state, callers should wait for any in-flight extractions so the
%   inventory is stable.
%
%   Inputs:
%       cloudDatasetID - The cloud dataset id.
%
%   Name-Value Pairs:
%       'timeout'         (double) - Overall deadline in seconds. Default 300.
%       'initialInterval' (double) - First sleep between polls (s). Default 1.
%       'maxInterval'     (double) - Cap on the per-poll sleep (s). Default 30.
%       'backoffFactor'   (double) - Multiplier applied after each poll. Default 2.
%       'requireAllComplete' (logical) - If true, return b=false when any
%                          job on the dataset ended in state='failed'.
%                          If false, return b=true as soon as the active
%                          set drains, regardless of failure history.
%                          Default true.
%
%   Outputs:
%       b            - True iff no active jobs remain AND, when
%                      requireAllComplete=true, no jobs ended in 'failed'
%                      before the timeout.
%       answer       - Struct describing the final state. On success:
%                        .state='complete', .jobs=[], .elapsed=<seconds>.
%                      On failed: .state='failed', .jobs=<failed jobs>,
%                                 .elapsed=<seconds>.
%                      On timeout: .state='timeout', .elapsed=<seconds>,
%                                  .jobs=<jobs still active>.
%       apiResponse  - The ResponseMessage from the last poll.
%       apiURL       - The URL of the last poll.
%
%   See also: ndi.cloud.api.implementation.files.WaitForAllBulkUploads,
%             ndi.cloud.api.files.waitForBulkUpload,
%             ndi.cloud.api.files.listActiveBulkUploads,
%             ndi.cloud.api.files.getBulkUploadStatus

    arguments
        cloudDatasetID (1,1) string
        options.timeout (1,1) double {mustBePositive} = 300
        options.initialInterval (1,1) double {mustBePositive} = 1
        options.maxInterval (1,1) double {mustBePositive} = 30
        options.backoffFactor (1,1) double {mustBePositive} = 2
        options.requireAllComplete (1,1) logical = true
    end

    api_call = ndi.cloud.api.implementation.files.WaitForAllBulkUploads(...
        'cloudDatasetID', cloudDatasetID, ...
        'timeout', options.timeout, ...
        'initialInterval', options.initialInterval, ...
        'maxInterval', options.maxInterval, ...
        'backoffFactor', options.backoffFactor, ...
        'requireAllComplete', options.requireAllComplete);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
