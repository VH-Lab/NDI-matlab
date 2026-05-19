function [b, answer, apiResponse, apiURL] = refreshWriteLock(cloudDatasetID)
%REFRESHWRITELOCK Refresh the exclusive write lock on a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.refreshWriteLock(CLOUDDATASETID)
%
%   Extends the heldUntil of the current write lock. Only the holder
%   may refresh; 403 otherwise, 410 if the lock has expired since the
%   holder last touched it.
%
%   See also: ndi.cloud.api.datasets.acquireWriteLock.

    arguments
        cloudDatasetID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.datasets.RefreshWriteLock( ...
        'cloudDatasetID', cloudDatasetID);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
