function [b, answer, apiResponse, apiURL] = getFileTierJob(jobID)
%GETFILETIERJOB Poll an async file-tier job.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFileTierJob(JOBID)
%
%   GET /file-tier-jobs/{jobId}. Returns the job's state (queued | running
%   | completed | failed | superseded), the target tier, per-phase counts,
%   and a bounded error list. See
%   ndi-cloud-node/manuals/file-tier-design.md.
%
%   Inputs:
%       jobID  - Job id returned by ndi.cloud.api.files.setFileTier.
%
%   Outputs:
%       b            - True on HTTP 200.
%       answer       - On success, the job status struct.
%                      On failure, the server error payload.
%       apiResponse  - The full matlab.net.http.ResponseMessage.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.files.setFileTier,
%             ndi.cloud.api.files.waitForFileTierJob

    arguments
        jobID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.files.GetFileTierJob('jobID', jobID);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
