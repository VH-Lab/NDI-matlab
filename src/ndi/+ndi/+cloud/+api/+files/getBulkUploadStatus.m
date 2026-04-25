function [b, answer, apiResponse, apiURL] = getBulkUploadStatus(jobId)
%GETBULKUPLOADSTATUS Get the state of a bulk file-upload job.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getBulkUploadStatus(JOBID)
%
%   Calls GET /v1/bulk-uploads/{jobId} and returns the server-side
%   extraction job state. JOBID is the identifier returned alongside the
%   upload URL from ndi.cloud.api.files.getFileCollectionUploadURL.
%
%   Inputs:
%       jobId        - The bulk upload job identifier.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - On success, a struct with fields:
%                        jobId, datasetId, state, createdAt, startedAt,
%                        completedAt, filesExtracted, totalFiles, error.
%                      On failure, the server error payload.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.files.GetBulkUploadStatus,
%             ndi.cloud.api.files.getFileCollectionUploadURL,
%             ndi.cloud.api.files.waitForBulkUpload

    arguments
        jobId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.files.GetBulkUploadStatus(...
        'jobId', jobId);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
