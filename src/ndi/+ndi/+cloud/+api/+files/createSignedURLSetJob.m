function [b, answer, apiResponse, apiURL] = createSignedURLSetJob(cloudDatasetID, cloudDocumentID)
%CREATESIGNEDURLSETJOB Kick off an async job to build a document's signed URL set.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.createSignedURLSetJob(CLOUDDATASETID, CLOUDDOCUMENTID)
%
%   Calls POST /v1/datasets/{datasetId}/documents/{documentId}/signed-url-set-jobs.
%   Returns a job id you can then poll with
%   ndi.cloud.api.files.getSignedURLSetJob or wait on with
%   ndi.cloud.api.files.waitForSignedURLSetJob.
%
%   Use this path (rather than getSignedURLSet / getSignedURLSetAll) for
%   documents that reference thousands of files: the server builds the
%   full UID -> signed URL map, gzips it, uploads it to S3, and hands you
%   a single presigned URL when it's done.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset.
%       cloudDocumentID  - The cloud API ID of the document.
%
%   Outputs:
%       b            - True if the job was accepted (HTTP 202).
%       answer       - On success, a struct with fields:
%                        jobId, datasetId, documentId, statusUrl, pollAfterSec.
%                      On failure, the server error payload.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [s, job] = ndi.cloud.api.files.createSignedURLSetJob('d-123','doc-abc');
%       if s
%           [ok, done] = ndi.cloud.api.files.waitForSignedURLSetJob(job.jobId);
%       end
%
%   See also: ndi.cloud.api.implementation.files.CreateSignedURLSetJob,
%             ndi.cloud.api.files.getSignedURLSetJob,
%             ndi.cloud.api.files.waitForSignedURLSetJob

    arguments
        cloudDatasetID  (1,1) string
        cloudDocumentID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.files.CreateSignedURLSetJob(...
        'cloudDatasetID',  cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
