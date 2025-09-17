function delete_documents_test(dataset_id)
    %DELETE_DOCUMENTS_TEST - test the delete_document and bulk_delete function
    %
    % DELETE_DOCUMENTS_TEST(DATASET_ID)
    %
    % Test the following api commands:
    %   documents/delete_document
    %   documents/bulk_delete_documents
    %   documents/list_dataset_documents
    %

    [success, dataset] = ndi.cloud.api.datasets.getDataset(dataset_id);
    if ~success, error('Failed to get dataset'); end
    number_of_documents = numel(dataset.documents);
    test_document = struct("name", "test document");
    test_document = jsonencode(test_document);
    [~, test_document_id] = ndi.cloud.api.documents.addDocumentAsFile(dataset_id, test_document);
    [~] = ndi.cloud.api.documents.deleteDocument(dataset_id, test_document_id);
    [success, dataset] = ndi.cloud.api.datasets.getDataset(dataset_id);
    if ~success, error('Failed to get dataset'); end
    if (number_of_documents ~= numel(dataset.documents))
        error('ndi.cloud.api.datasets.getDataset returns the same number of documents after deleting a document');
    end
    [~, summary] = ndi.cloud.api.documents.listDatasetDocuments(dataset_id);
    if (number_of_documents ~= numel(summary.documents))
        error('ndi.cloud.api.documents.listDatasetDocuments returns the same number of documents after deleting a document');
    end
    % try getting the document that was deleted. If no error is thrown, then the document was not deleted
    try
        [~, ~] = ndi.cloud.api.documents.getDocument(dataset_id, test_document_id);
        error('ndi.cloud.api.documents.getDocument did not throw an error after delete_document');
    catch
        % do nothing, this is the expected behavior
    end

    % test bulk delete
    % try bulk_delete_documents to delete a document that does not exist
    try
        [~] = ndi.cloud.api.documents.bulkDeleteDocuments(dataset_id, test_document_id);
        error('ndi.cloud.api.documents.bulkDeleteDocuments did not throw an error after using a document that does not exist');
    catch
        % do nothing, this is the expected behavior
    end

    document_ids = {};
    for i = 1:10
        test_document = struct("name", "test document");
        test_document = jsonencode(test_document);
        [~, test_document_id] = ndi.cloud.api.documents.addDocumentAsFile(dataset_id, test_document);
        document_ids{end+1} = test_document_id;
    end
    [~] = ndi.cloud.api.documents.bulkDeleteDocuments(dataset_id, document_ids);
    [success, dataset] = ndi.cloud.api.datasets.getDataset(dataset_id);
    if ~success, error('Failed to get dataset'); end
    if (number_of_documents ~= numel(dataset.documents))
        error('ndi.cloud.api.datasets.getDataset returns the same number of documents after deleting a document');
    end

    % try getting the document that was deleted. If no error is thrown, then the document was not deleted
    % try delete_document to delete a document that does not exist
    for i = 1:numel(document_ids)
        try
            [~, ~] = ndi.cloud.api.documents.getDocument(dataset_id, document_ids(i));
            error('ndi.cloud.api.documents.getDocument did not throw an error after using bulk_delete_documents');
        catch
            % do nothing, this is the expected behavior
        end
        try
            [~] = ndi.cloud.api.documents.deleteDocument(dataset_id, document_ids(i));
            error('ndi.cloud.api.documents.deleteDocument did not throw an error after using bulk_delete_documents');
        catch
            % do nothing, this is the expected behavior
        end
    end
end
