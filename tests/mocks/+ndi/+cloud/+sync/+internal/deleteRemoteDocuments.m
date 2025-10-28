function deleteRemoteDocuments(cloudDatasetId, remoteDocumentIds, syncOptions)
%MOCKDELETEREMOTEDOCUMENTS Mock for deleting remote documents

    if syncOptions.Verbose
        fprintf('[Mock] Deleting %d documents from remote...\n', numel(remoteDocumentIds));
    end

    % Call the mock datastore to delete the documents
    ndi.cloud.api.documents.listDatasetDocumentsAll('delete', remoteDocumentIds);
end
