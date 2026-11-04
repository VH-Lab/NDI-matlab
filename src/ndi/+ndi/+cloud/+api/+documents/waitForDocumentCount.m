function [b, answer, apiResponse, apiURL] = waitForDocumentCount(cloudDatasetID, expectedCount, options)
%WAITFORDOCUMENTCOUNT Wait until a dataset lists at least a given number of documents.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.waitForDocumentCount(CLOUDDATASETID, EXPECTEDCOUNT)
%   [...] = ndi.cloud.api.documents.waitForDocumentCount(CLOUDDATASETID, EXPECTEDCOUNT, 'timeout', T, ...)
%
%   Repeatedly calls ndi.cloud.api.documents.documentCount(CLOUDDATASETID)
%   at exponentially growing intervals until the count is at least
%   EXPECTEDCOUNT or the overall timeout elapses.
%
%   Use it after a bulk document upload: the upload returns once the zip
%   is stored, before the server has ingested the documents, so a listing
%   made straight away can miss some of them. Bulk document uploads have
%   no job id, so ndi.cloud.api.files.waitForAllBulkUploads (which waits
%   on bulk FILE uploads) does not cover them.
%
%   Inputs:
%       cloudDatasetID - The cloud dataset id.
%       expectedCount  - The number of documents the dataset should list.
%
%   Name-value options:
%       'timeout'         - Overall deadline in seconds. Default 300.
%       'initialInterval' - First sleep between polls (s). Default 1.
%       'maxInterval'     - Cap on the per-poll sleep (s). Default 10.
%       'backoffFactor'   - Multiplier applied after each poll. Default 2.
%
%   Outputs:
%       b            - True iff the count reached EXPECTEDCOUNT before the
%                      timeout.
%       answer       - Struct with fields state ('complete' or 'timeout'),
%                      count (the last count read; NaN if no poll
%                      succeeded), expectedCount and elapsed (seconds).
%       apiResponse  - The ResponseMessage from the last poll.
%       apiURL       - The URL of the last poll.
%
%   Example:
%       [ok, status] = ndi.cloud.api.documents.waitForDocumentCount('d-12345', 250, 'timeout', 120);
%
%   See also: ndi.cloud.api.implementation.documents.WaitForDocumentCount,
%             ndi.cloud.api.documents.documentCount,
%             ndi.cloud.upload.uploadDocumentCollection,
%             ndi.cloud.api.files.waitForAllBulkUploads

    arguments
        cloudDatasetID (1,1) string
        expectedCount  (1,1) double {mustBeNonnegative, mustBeInteger}
        options.timeout         (1,1) double {mustBePositive} = 300
        options.initialInterval (1,1) double {mustBePositive} = 1
        options.maxInterval     (1,1) double {mustBePositive} = 10
        options.backoffFactor   (1,1) double {mustBePositive} = 2
    end

    api_call = ndi.cloud.api.implementation.documents.WaitForDocumentCount(...
        'cloudDatasetID',  cloudDatasetID, ...
        'expectedCount',   expectedCount, ...
        'timeout',         options.timeout, ...
        'initialInterval', options.initialInterval, ...
        'maxInterval',     options.maxInterval, ...
        'backoffFactor',   options.backoffFactor);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
