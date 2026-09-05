function [b, answer, apiResponse, apiURL] = getSignedURLSetJob(jobId)
%GETSIGNEDURLSETJOB Get the state of an async signed-URL-set job.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getSignedURLSetJob(JOBID)
%
%   Calls GET /v1/signed-url-set-jobs/{jobId} and returns the current job
%   state. JOBID is the identifier returned by
%   ndi.cloud.api.files.createSignedURLSetJob.
%
%   Inputs:
%       jobId        - The signed-URL-set job identifier.
%
%   Outputs:
%       b            - True if the call succeeded (HTTP 200).
%       answer       - On success, a struct with (at least) fields:
%                        jobId, datasetId, documentId, state,
%                        createdAt, startedAt, completedAt,
%                        heartbeatAt, signedCount, totalCount.
%                      When state is 'ready', also carries `resultUrl`,
%                      `resultByteSize`, `expiresAt`, `filesExpireAt`.
%                      When state is 'failed', also carries `error`.
%                      On failure, the server error payload.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.files.GetSignedURLSetJob,
%             ndi.cloud.api.files.createSignedURLSetJob,
%             ndi.cloud.api.files.waitForSignedURLSetJob

    arguments
        jobId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.files.GetSignedURLSetJob(...
        'jobId', jobId);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
