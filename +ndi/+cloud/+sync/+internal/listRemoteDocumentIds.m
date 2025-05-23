function documentIds = listRemoteDocumentIds(cloudDatasetId)

    arguments
        cloudDatasetId (1,1) string
    end

    [~, documentSummary] = ndi.cloud.api.documents.list_dataset_documents(cloudDatasetId);
    
    if isempty(documentSummary.documents)
        ndiDocumentIds = string.empty(0,1);
        apiDocumentIds = string.empty(0,1);
    else
        ndiDocumentIds = string( {documentSummary.documents.ndiId}' );
        apiDocumentIds = string( {documentSummary.documents.id}' );
    end

    documentIds = table(ndiDocumentIds, apiDocumentIds, ...
        'VariableNames', {'ndiId', 'apiId'});

    % if isempty(currentRemoteIdMap)
    %     currentRemoteNdiDocumentIds = strings(0,1);
    % else
    %     currentRemoteNdiDocumentIds = string(currentRemoteIdMap(:,1));
    % end
end
