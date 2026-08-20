function [b, answer, apiResponse, apiURL] = releaseWriteLock(cloudDatasetID)
%RELEASEWRITELOCK Release the exclusive write lock on a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.releaseWriteLock(CLOUDDATASETID)
%
%   Releases the per-dataset write lock. Only the current holder may
%   release. Anyone else gets 403.
%
%   See also: ndi.cloud.api.datasets.acquireWriteLock.

    arguments
        cloudDatasetID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.datasets.ReleaseWriteLock( ...
        'cloudDatasetID', cloudDatasetID);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
