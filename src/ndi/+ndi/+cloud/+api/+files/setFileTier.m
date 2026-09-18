function [b, answer, apiResponse, apiURL] = setFileTier(cloudDatasetID, documentIDs, targetTier, options)
%SETFILETIER Move the files referenced by a list of documents to a target S3 storage class.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.setFileTier(...
%       CLOUDDATASETID, DOCUMENTIDS, TARGETTIER)
%
%   Kicks off an async job (POST /datasets/{datasetId}/file-tier-jobs) that
%   copies every file the given documents reference to TARGETTIER.
%   DOCUMENTIDS is a string array or cell array of document ids; each entry
%   may be either a cloud _id or an NDI id, and the server infers which by
%   shape unless you pass idNamespace= to force it. See
%   ndi-cloud-node/manuals/file-tier-design.md.
%
%   TARGETTIER is one of:
%       "STANDARD" | "STANDARD_IA" | "GLACIER_IR" | "GLACIER" | "DEEP_ARCHIVE"
%   ("PSEUDO_COLD" is accepted server-side in non-production stages only.)
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset (string).
%       documentIDs      - A string array or cell array of document ids
%                          (mixed cloud/NDI ids are fine).
%       targetTier       - Target S3 storage class (string).
%
%   Name-value options:
%       idNamespace      - "auto" (default), "cloud", or "ndi". When "auto",
%                          each id is inspected by the server (24-hex is
%                          treated as cloud, anything else as ndi).
%
%   Outputs:
%       b            - True on HTTP 202 (job accepted).
%       answer       - On success, a struct with jobId, fileCount,
%                      resolvedDocumentCount, collateralDocumentIds.
%                      On failure, the server error payload.
%       apiResponse  - The full matlab.net.http.ResponseMessage.
%       apiURL       - The URL that was called.
%
%   Example:
%       [ok, job] = ndi.cloud.api.files.setFileTier( ...
%           "d-12345", ["doc-abc", "ndi_123..."], "GLACIER");
%       if ok
%           [done, status] = ndi.cloud.api.files.waitForFileTierJob(job.jobId);
%       end
%
%   See also: ndi.cloud.api.implementation.files.SetFileTier,
%             ndi.cloud.api.files.getFileTierJob,
%             ndi.cloud.api.files.waitForFileTierJob

    arguments
        cloudDatasetID (1,1) string
        documentIDs
        targetTier     (1,1) string
        options.idNamespace (1,1) string ...
            {mustBeMember(options.idNamespace,["auto","cloud","ndi"])} = "auto"
    end

    api_call = ndi.cloud.api.implementation.files.SetFileTier(...
        'cloudDatasetID', cloudDatasetID, ...
        'documentIDs',    documentIDs, ...
        'targetTier',     targetTier, ...
        'idNamespace',    options.idNamespace);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
