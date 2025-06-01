function save_dataset_docs(S, session_id, datasetInformation)
    %SAVE_DATASET_DOCS - save metadata from metadata editor as ndi.documents to dataset/session
    % SAVE_DATASET_DOCS(S, TEST_NAME)
    %
    % inputs:
    %   S - ndi.session or ndi.dataset object
    %   session_id - the session id of the incoming session or dataset
    %   datasetInformation - metadata collected using the metadata app
    %

    % Call the new function to handle deletion of old documents
    % The 'true' for askUser preserves the original behavior of prompting the user.
    [hadPreviousDocs, previousDocsDeleted] = ndi.database.metadata_ds_core.eraseMetadataEditorNDIDocs(S, true);

    % If previous documents existed but were not deleted (e.g., user said 'No'), then return.
    if hadPreviousDocs && ~previousDocsDeleted
        return;
    end
    % If there were no previous docs, or if they were successfully deleted, proceed.

    documentList = ndi.database.metadata_ds_core.convertFormDataToDocuments(datasetInformation, session_id);
    S.database_add(documentList);
end
