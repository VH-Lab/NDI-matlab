function indexStruct = createSyncIndexStruct(localNdiIds, remoteNdiIds)
% CREATESYNCINDEXSTRUCT Creates the MATLAB structure for the NDI sync index.
%
%   INDEXSTRUCT = ndi.cloud.sync.internal.CREATESYNCINDEXSTRUCT(LOCALNDIIDS, REMOTENDIIDS)
%   creates a structure that can be serialized to JSON for the sync index file.
%
%   Inputs:
%       localNdiIds (string array): A list of NDI document UUIDs
%           that are present in the local NDI dataset.
%       remoteNdiIds (string array): A list of NDI document UUIDs
%           that are present on the remote cloud storage.
%
%   Outputs:
%       indexStruct (struct): A structure with the following fields:
%           localDocumentIdsLastSync (string): String array of local NDI IDs.
%           remoteDocumentIdsLastSync (string): String array of remote NDI IDs.
%           lastSyncTimestamp (string): Current timestamp in ISO 8601 format.
%
%   Example:
%       local_ids = {"uuid-doc-A", "uuid-doc-B"};
%       remote_ids = {"uuid-doc-A", "uuid-doc-C"};
%       idx_struct = ndi.cloud.sync.internal.index.createSyncIndexStruct(local_ids, remote_ids);
%       % idx_struct can then be passed to a JSON writing function.
%
%   See also: ndi.cloud.sync.internal.index.readSyncIndex

    arguments
        localNdiIds (1,:) string % Allow string array, will convert
        remoteNdiIds (1,:) string % Allow string array, will convert
    end
    
    % Create the structure
    indexStruct = struct();
    indexStruct.localDocumentIdsLastSync = localNdiIds;
    indexStruct.remoteDocumentIdsLastSync = remoteNdiIds;
    
    % Get current UTC timestamp in ISO 8601 format
    % Using standard MATLAB datetime function
    dt = datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd''T''HH:mm:ssZZZZ');
    indexStruct.lastSyncTimestamp = char(dt);
end
