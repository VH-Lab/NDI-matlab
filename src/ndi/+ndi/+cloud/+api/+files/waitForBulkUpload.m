function [b, answer, apiResponse, apiURL] = waitForBulkUpload(jobId, options)
%WAITFORBULKUPLOAD Poll a bulk file-upload job until it finishes or times out.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.waitForBulkUpload(JOBID)
%   [...] = ndi.cloud.api.files.waitForBulkUpload(JOBID, 'timeout', T, ...)
%
%   Repeatedly calls ndi.cloud.api.files.getBulkUploadStatus(JOBID) at
%   exponentially growing intervals until the job reaches a terminal state
%   ('complete' or 'failed') or the overall timeout elapses.
%
%   Inputs:
%       jobId        - The bulk upload job identifier.
%
%   Name-Value Pairs:
%       'timeout'         (double) - Overall deadline in seconds. Default 60.
%       'initialInterval' (double) - First sleep between polls (s). Default 1.
%       'maxInterval'     (double) - Cap on the per-poll sleep (s). Default 30.
%       'backoffFactor'   (double) - Multiplier applied after each poll. Default 2.
%
%   Outputs:
%       b            - True iff the job reached state 'complete'. False on
%                      'failed', timeout, or API error.
%       answer       - The last status struct from the server. If the call
%                      timed out, a field 'state' is set to 'timeout' and
%                      'elapsed' holds the wall time spent polling.
%       apiResponse  - The ResponseMessage from the last poll.
%       apiURL       - The URL of the last poll.
%
%   See also: ndi.cloud.api.implementation.files.WaitForBulkUpload,
%             ndi.cloud.api.files.getBulkUploadStatus,
%             ndi.cloud.api.files.listActiveBulkUploads

    arguments
        jobId (1,1) string
        options.timeout (1,1) double {mustBePositive} = 60
        options.initialInterval (1,1) double {mustBePositive} = 1
        options.maxInterval (1,1) double {mustBePositive} = 30
        options.backoffFactor (1,1) double {mustBePositive} = 2
    end

    api_call = ndi.cloud.api.implementation.files.WaitForBulkUpload(...
        'jobId', jobId, ...
        'timeout', options.timeout, ...
        'initialInterval', options.initialInterval, ...
        'maxInterval', options.maxInterval, ...
        'backoffFactor', options.backoffFactor);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
