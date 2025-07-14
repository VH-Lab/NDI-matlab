function writeSyncIndex(ndiDataset, syncIndex, options)
    arguments
        ndiDataset (1,1) ndi.dataset
        syncIndex (1,1) struct
        options.Verbose (1,1) logical = false
    end

    indexPath = ndi.cloud.sync.internal.index.getIndexFilepath(...
        ndiDataset.path, "write", "Verbose", options.Verbose);

    fid = fopen(indexPath, "wt");
    fwrite(fid, jsonencode(syncIndex));
    fclose(fid);
end
