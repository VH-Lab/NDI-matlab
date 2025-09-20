function updateFileInfoForRemoteFiles(cloudDatasetId, ndiDocuments, syncOptions)
%MOCKUPDATEFILEINFOFORREMOTEFILES Mock for updating file info on remote
    if syncOptions.Verbose
        fprintf('[Mock] Updating file info for %d documents on remote...\n', numel(ndiDocuments));
    end
    % This is a no-op for our mock environment, since we don't track files
    % in the remote mock datastore.
end
