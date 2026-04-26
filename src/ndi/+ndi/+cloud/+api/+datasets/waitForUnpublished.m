function [b, answer, apiResponse, apiURL] = waitForUnpublished(cloudDatasetID, options)
%WAITFORUNPUBLISHED Poll a dataset until its 'isPublished' flag is false.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.waitForUnpublished(CLOUDDATASETID)
%   [...] = ndi.cloud.api.datasets.waitForUnpublished(CLOUDDATASETID, 'timeout', T, ...)
%
%   Repeatedly calls ndi.cloud.api.datasets.getDataset(CLOUDDATASETID) at
%   exponentially growing intervals until the dataset's 'isPublished' field
%   becomes false or the overall timeout elapses. The backend flips
%   'isPublished' from true to false only when unpublishing has completed,
%   so this is the canonical signal that an unpublish workflow is finished.
%
%   Inputs:
%       cloudDatasetID - The string ID of the dataset.
%
%   Name-Value Pairs:
%       'timeout'         (double) - Overall deadline in seconds. Default 180.
%       'initialInterval' (double) - First sleep between polls (s). Default 2.
%       'maxInterval'     (double) - Cap on the per-poll sleep (s). Default 30.
%       'backoffFactor'   (double) - Multiplier applied after each poll. Default 2.
%
%   Outputs:
%       b            - True iff the dataset reached isPublished=false before
%                      the timeout. False on API error or timeout.
%       answer       - The last dataset struct returned by the server. On
%                      timeout, a field 'state' is set to 'timeout' and
%                      'elapsed' holds the wall time spent polling.
%       apiResponse  - The ResponseMessage from the last poll.
%       apiURL       - The URL of the last poll.
%
%   See also: ndi.cloud.api.implementation.datasets.WaitForUnpublished,
%             ndi.cloud.api.datasets.unpublishDataset,
%             ndi.cloud.api.datasets.waitForPublished

    arguments
        cloudDatasetID (1,1) string
        options.timeout (1,1) double {mustBePositive} = 180
        options.initialInterval (1,1) double {mustBePositive} = 2
        options.maxInterval (1,1) double {mustBePositive} = 30
        options.backoffFactor (1,1) double {mustBePositive} = 2
    end

    api_call = ndi.cloud.api.implementation.datasets.WaitForUnpublished(...
        'cloudDatasetID', cloudDatasetID, ...
        'timeout', options.timeout, ...
        'initialInterval', options.initialInterval, ...
        'maxInterval', options.maxInterval, ...
        'backoffFactor', options.backoffFactor);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
