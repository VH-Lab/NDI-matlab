classdef SyncMode
    % SyncMode - Enumeration of supported dataset synchronization modes
    %
    % Defines modes for unidirectional and bidirectional sync operations
    % between a local and remote dataset, with or without mirroring.
    
    enumeration
        % Download documents that are new on the remote location
        DownloadNew         ("downloadNew")

        % Download files from remote and remove files locally that no longer exist remotely
        MirrorFromRemote    ("mirrorFromRemote")

        % Upload files that are new on the local location
        UploadNew           ("uploadNew")

        % Upload files to remote and remove files remotely that no longer exist locally
        MirrorToRemote      ("mirrorToRemote")

        % Two-way sync: copy new/updated files both ways, without removing any documents
        TwoWaySync          ("twoWaySync")
    end

    properties (SetAccess = immutable)
        Function function_handle
    end

    methods
        function obj = SyncMode(functionName)
            obj.Function = str2func( sprintf("ndi.cloud.sync.%s", functionName ) );
        end
        function execute(obj, ndiDataset, syncOptions)
            arguments
                obj
                ndiDataset
                syncOptions ndi.cloud.sync.SyncOptions
            end
            obj.Function(ndiDataset, syncOptions.nvpairs())
        end
    end
end
