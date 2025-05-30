classdef Constants
    properties (Constant)
        % FileSyncLocation - Temporary relative path (relative to dataset
        % folder) to store files portion of NDI documents during sync
        FileSyncLocation = fullfile('download', 'files')
    end
end
