function documentIds = listRemoteDocumentIds(cloudDatasetId)
    % listRemoteDocumentIds - Retrieves document IDs from a remote cloud dataset
    %
    % Syntax:
    %   documentIds = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId) 
    %   This function retrieves the NDI and API document IDs associated with 
    %   a specified cloud dataset ID and returns them in a table format.
    %
    % Input Arguments:
    %   cloudDatasetId (1,1) string - The ID of the cloud dataset from which to 
    %   retrieve document IDs.
    %
    % Output Arguments:
    %   documentIds - A table containing the NDI and API document IDs with 
    %   variable names 'ndiId' and 'apiId'.

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

