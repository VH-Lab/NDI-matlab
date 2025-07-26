function syncDataset(ndiDataset, syncOptions)
% SYNCDATASET Synchronizes an NDI dataset with cloud storage.
%
%   ndi.cloud.syncDataset(NDIDATASET, Name, Value, ...)
%
%   This function serves as the primary entry point for synchronizing an NDI
%   dataset with its corresponding cloud storage. It supports various
%   synchronization modes to control how data is transferred and reconciled
%   between the local dataset and the remote cloud representation.
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object to be
%           synchronized. 
%
%       Name-Value Pair Arguments:
%       'SyncMode' (1,1) ndi.cloud.sync.enum.SyncMode - Specifies the
%           synchronization strategy to use. Default is "DownloadNew".
%           Available modes are:
%           - "DownloadNew": Downloads documents (and associated data files)
%             that are present on the remote cloud storage but not yet in the
%             local NDI dataset. No local or remote documents are deleted or
%             modified if they already exist.
%           - "UploadNew": Uploads documents (and associated data files)
%             that are present in the local NDI dataset but not yet on the
%             remote cloud storage. No local or remote documents are deleted
%             or modified if they already exist.
%           - "MirrorFromRemote": Makes the local NDI dataset an exact
%             mirror of the remote cloud storage. This involves:
%               1. Downloading documents from remote that are not local.
%               2. Deleting local documents that are not present on remote.
%             The remote dataset is not modified.
%           - "MirrorToRemote": Makes the remote cloud storage an exact
%             mirror of the local NDI dataset. This involves:
%               1. Uploading local documents that are not on remote.
%               2. Deleting remote documents that are not present locally.
%             The local dataset is not modified.
%           - "TwoWaySync": Performs a bidirectional additive synchronization.
%             This involves:
%               1. Uploading local documents not on remote.
%               2. Downloading remote documents not present locally.
%             No documents are deleted from either local or remote.
%
%       Additional options are derived from ndi.cloud.sync.SyncOptions and
%       can be provided as name-value pairs, which are then passed to the
%       specific sync mode function:
%       'SyncFiles' (1,1) logical - If true, the binary data (file portion)
%           of documents will also be synchronized. Default is true (as per
%           SyncOptions class).
%       'Verbose' (1,1) logical - If true, detailed progress messages are
%           printed to the console. Default is true (as per SyncOptions class).
%       'DryRun' (1,1) logical - If true, synchronization actions are
%           simulated (logged if Verbose is true) but not actually executed.
%           Default is false (as per SyncOptions class).
%       'FileUploadStrategy' (1,1) (string) - "serial" to upload files one by one or
%           "batch" (default) to upload a bundles of files using zip files. 
%           The "batch" option is recommended when uploading many files,
%           and the serial option can be used as a fallback if batch upload fails.
%
%   The function determines the cloud dataset identifier associated with the
%   local NDI dataset and relies on the individual sync mode functions to manage
%   a sync index file (typically located at
%   [NDIDATASET.path]/.ndi/sync/index.json) for tracking synchronization states.
%
%   Example:
%       % Assuming 'mySession' is an existing ndi.session object
%       myDataset = ndi.dataset('Path', mySession.path);
%
%       % Download new documents from the cloud
%       ndi.cloud.syncDataset(myDataset, 'SyncMode', "DownloadNew");
%
%       % Mirror the local dataset to the remote, without syncing file data
%       ndi.cloud.syncDataset(myDataset, 'SyncMode', "MirrorToRemote", 'SyncFiles', false);
%
%       % Perform a two-way sync with verbose output, simulating actions
%       ndi.cloud.syncDataset(myDataset, 'SyncMode', "TwoWaySync", 'Verbose', true, 'DryRun', true);
%
%   See also:
%       ndi.cloud.sync.downloadNew, ndi.cloud.sync.uploadNew,
%       ndi.cloud.sync.mirrorFromRemote, ndi.cloud.sync.mirrorToRemote,
%       ndi.cloud.sync.twoWaySync, ndi.cloud.sync.SyncOptions,
%       ndi.cloud.sync.enum.SyncMode
    arguments
        ndiDataset (1,1) ndi.dataset
        syncOptions.?ndi.cloud.sync.SyncOptions
        syncOptions.SyncMode (1,1) ndi.cloud.sync.enum.SyncMode = "DownloadNew"
    end
    syncMode = syncOptions.SyncMode;
    syncOptions = rmfield(syncOptions, "SyncMode");
    syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);
    syncMode.execute(ndiDataset, syncOptions)
end
