function [b, answer, apiResponse, apiURL] = getSignedURLSetJobStatus(jobId)
%GETSIGNEDURLSETJOBSTATUS Get the state of an async signed-url-set job.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.getSignedURLSetJobStatus(JOBID)
%
%   Inputs:
%       jobId - The job identifier returned by
%               ndi.cloud.api.documents.createSignedURLSetJob.
%
%   Outputs:
%       b            - True if the call succeeded.
%       answer       - On success, a struct carrying at least 'state', one of
%                      'queued', 'running', 'ready' or 'failed'. When ready it
%                      also carries resultUrl (a presigned 24 h GET for the
%                      gzipped map) and filesExpireAt. On failure, the error body.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.documents.GetSignedURLSetJobStatus,
%             ndi.cloud.api.documents.waitForSignedURLSetJob

    arguments
        jobId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.documents.GetSignedURLSetJobStatus(...
        'jobId', jobId);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
