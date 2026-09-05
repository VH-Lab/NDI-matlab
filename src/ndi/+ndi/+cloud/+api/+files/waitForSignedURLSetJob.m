function [b, answer, apiResponse, apiURL] = waitForSignedURLSetJob(jobId, options)
%WAITFORSIGNEDURLSETJOB Poll a signed-URL-set job until it finishes or times out.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.waitForSignedURLSetJob(JOBID)
%   [...] = ndi.cloud.api.files.waitForSignedURLSetJob(JOBID, 'timeout', T, ...)
%
%   Repeatedly calls ndi.cloud.api.files.getSignedURLSetJob(JOBID) at
%   exponentially growing intervals until the job reaches a terminal
%   state ('ready' or 'failed') or the overall timeout elapses.
%
%   Inputs:
%       jobId        - The signed-URL-set job identifier.
%
%   Name-Value Pairs:
%       'timeout'         (double) - Overall deadline in seconds. Default 300.
%       'initialInterval' (double) - First sleep between polls (s). Default 3.
%       'maxInterval'     (double) - Cap on the per-poll sleep (s). Default 30.
%       'backoffFactor'   (double) - Multiplier applied after each poll. Default 2.
%
%   Outputs:
%       b            - True iff the job reached state 'ready'. False on
%                      'failed', timeout, or API error.
%       answer       - The last status struct from the server. On 'ready',
%                      carries `resultUrl` for the gzipped JSON blob. If
%                      the call timed out, `state` is set to 'timeout' and
%                      `elapsed` holds the wall time spent polling.
%       apiResponse  - The ResponseMessage from the last poll.
%       apiURL       - The URL of the last poll.
%
%   See also: ndi.cloud.api.implementation.files.WaitForSignedURLSetJob,
%             ndi.cloud.api.files.createSignedURLSetJob,
%             ndi.cloud.api.files.getSignedURLSetJob

    arguments
        jobId (1,1) string
        options.timeout         (1,1) double {mustBePositive} = 300
        options.initialInterval (1,1) double {mustBePositive} = 3
        options.maxInterval     (1,1) double {mustBePositive} = 30
        options.backoffFactor   (1,1) double {mustBePositive} = 2
    end

    api_call = ndi.cloud.api.implementation.files.WaitForSignedURLSetJob(...
        'jobId',           jobId, ...
        'timeout',         options.timeout, ...
        'initialInterval', options.initialInterval, ...
        'maxInterval',     options.maxInterval, ...
        'backoffFactor',   options.backoffFactor);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
