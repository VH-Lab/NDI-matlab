function syncIndex = readSyncIndex(ndiDataset, options)
    arguments
        ndiDataset (1,1) ndi.dataset
        options.Verbose (1,1) logical = true
    end

    indexPath = ndi.cloud.sync.internal.index.getIndexFilepath(...
        ndiDataset.path, "read", "Verbose", options.Verbose);

    if isfile(indexPath)
        syncIndex = jsondecode( fileread(indexPath) );
    else
        syncIndex = struct.empty;
    end
end
