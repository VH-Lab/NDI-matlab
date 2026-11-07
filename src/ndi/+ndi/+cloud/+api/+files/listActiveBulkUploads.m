function [b, answer, apiResponse, apiURL] = listActiveBulkUploads(cloudDatasetID, options)
%LISTACTIVEBULKUPLOADS List bulk upload jobs for a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.listActiveBulkUploads(CLOUDDATASETID)
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.listActiveBulkUploads(CLOUDDATASETID, 'state', STATE)
%   [...] = ndi.cloud.api.files.listActiveBulkUploads(CLOUDDATASETID, 'state', STATE, 'since', SINCE)
%
%   Calls GET /v1/datasets/{id}/bulk-uploads[?state=...&since=...] and returns the
%   set of bulk upload jobs the server is tracking for this dataset.
%
%   Inputs:
%       cloudDatasetID - The cloud dataset ID.
%
%   Name-Value Pairs:
%       'state' (string) - Filter by job state. One of:
%                          'active' (default, = queued + extracting),
%                          'all' (includes recent history),
%                          'queued', 'extracting', 'complete', 'failed'.
%       'since' (datetime) - Only return terminal ('complete'/'failed')
%                          jobs whose completedAt is at or after this
%                          time; active jobs are always returned. A
%                          datetime without a time zone is taken as UTC.
%                          Default: no limit. Servers that predate this
%                          filter ignore it.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - Struct with fields datasetId (string) and jobs
%                      (struct array; see getBulkUploadStatus for fields).
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.files.ListActiveBulkUploads,
%             ndi.cloud.api.files.getBulkUploadStatus,
%             ndi.cloud.api.files.waitForBulkUpload

    arguments
        cloudDatasetID (1,1) string
        options.state (1,1) string {mustBeMember(options.state, ...
            ["active","all","queued","extracting","complete","failed"])} = "active"
        options.since datetime {mustBeScalarOrEmpty} = datetime.empty
    end

    api_call = ndi.cloud.api.implementation.files.ListActiveBulkUploads(...
        'cloudDatasetID', cloudDatasetID, ...
        'state', options.state, ...
        'since', options.since);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
