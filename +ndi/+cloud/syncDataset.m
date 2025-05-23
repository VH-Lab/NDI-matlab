function syncDataset(ndiDataset, syncOptions)
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
