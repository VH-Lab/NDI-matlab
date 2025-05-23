classdef SyncMode
    % SyncMode - Enumeration of supported dataset synchronization modes
    %
    % Defines modes for unidirectional and bidirectional sync operations
    % between a local and a remote (NDI Cloud) dataset, with or without mirroring.
    
    enumeration
        % Download documents that are new on the remote dataset
        DownloadNew         ("downloadNew")

        % Download documents from remote and remove documents locally that no longer exist remotely
        MirrorFromRemote    ("mirrorFromRemote")

        % Upload documents that are new in the local dataset
        UploadNew           ("uploadNew")

        % Upload documents to remote and remove documents remotely that no longer exist locally
        MirrorToRemote      ("mirrorToRemote")

        % Two-way sync: copy new/updated documents both ways, without removing any documents
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
