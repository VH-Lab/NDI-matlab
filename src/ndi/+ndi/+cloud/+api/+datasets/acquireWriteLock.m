function [b, answer, apiResponse, apiURL] = acquireWriteLock(cloudDatasetID, args)
%ACQUIREWRITELOCK Acquire the exclusive write lock on a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.acquireWriteLock( ...
%       CLOUDDATASETID, 'reason', REASON, 'ttlSeconds', TTL)
%
%   Acquires the per-dataset exclusive write lock. The cloud accepts an
%   `idle -> held` transition, or refreshes the existing hold when the
%   caller already owns the lock (idempotent for the current holder).
%
%   Inputs:
%       cloudDatasetID - The ID of the dataset.
%   Name-Value Inputs:
%       reason     - (string) free-form reason for the hold (default
%                    "did2-migration"). Surfaced in 423 rejections so
%                    other writers can show a helpful message.
%       ttlSeconds - (double) optional override of the default server
%                    TTL (~30 min). 0 leaves the default in place.
%
%   Outputs:
%       b            - True if the lock was acquired (or refreshed by
%                      the current holder), false otherwise. 409 from a
%                      concurrent holder returns false; answer carries
%                      heldBy/heldUntil/reason.
%       answer       - Lock state struct on success or error body on
%                      failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.datasets.AcquireWriteLock,
%             ndi.cloud.api.datasets.releaseWriteLock,
%             ndi.cloud.api.datasets.refreshWriteLock,
%             ndi.cloud.api.datasets.getWriteLock.

    arguments
        cloudDatasetID (1,1) string
        args.reason (1,1) string = "did2-migration"
        args.ttlSeconds (1,1) double = 0
    end

    api_call = ndi.cloud.api.implementation.datasets.AcquireWriteLock( ...
        'cloudDatasetID', cloudDatasetID, ...
        'reason', args.reason, ...
        'ttlSeconds', args.ttlSeconds);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
