function [b, answer, apiResponse, apiURL] = getWriteLock(cloudDatasetID)
%GETWRITELOCK Inspect the current write lock state of a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.getWriteLock(CLOUDDATASETID)
%
%   Returns the `writeLock` subdocument of the dataset (state, heldBy,
%   heldUntil, acquiredAt, reason). Useful for diagnostics and for
%   clients deciding whether to wait or fail fast.
%
%   See also: ndi.cloud.api.datasets.acquireWriteLock.

    arguments
        cloudDatasetID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.datasets.GetWriteLock( ...
        'cloudDatasetID', cloudDatasetID);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
