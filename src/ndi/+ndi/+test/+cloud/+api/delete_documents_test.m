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

    % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_dataset with ndi.cloud.api.datasets.getDataset
    [dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
    number_of_documents = numel(dataset.documents);
    test_document = struct("name", "test document");
    test_document = jsonencode(test_document);
    % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.add_document_as_file with ndi.cloud.api.documents.addDocumentAsFile
    [response, test_document_id] = ndi.cloud.api.documents.add_document_as_file(dataset_id, test_document);
    % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.delete_document with ndi.cloud.api.documents.deleteDocument
    response = ndi.cloud.api.documents.delete_document(dataset_id, test_document_id);
    % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_dataset with ndi.cloud.api.datasets.getDataset
    [dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
    if (number_of_documents ~= numel(dataset.documents))
        error('ndi.cloud.api.datasets.get_dataset returns the same number of documents after deleting a document');
    end
    % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.list_dataset_documents with ndi.cloud.api.documents.listDatasetDocuments
    [response, summary] = ndi.cloud.api.documents.list_dataset_documents(dataset_id);
    if (number_of_documents ~= numel(summary.documents))
        error('ndi.cloud.api.documents.list_dataset_documents returns the same number of documents after deleting a document');
    end
    % try getting the document that was deleted. If no error is thrown, then the document was not deleted
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.get_document with ndi.cloud.api.documents.getDocument
        [response, test_document] = ndi.cloud.api.documents.get_document(dataset_id, test_document_id);
        error('ndi.cloud.api.documents.get_document did not throw an error after delete_document');
    catch
        % do nothing, this is the expected behavior
    end

    % test bulk delete
    % try bulk_delete_documents to delete a document that does not exist
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.bulk_delete_documents with ndi.cloud.api.documents.bulkDeleteDocuments
        response = ndi.cloud.api.documents.bulk_delete_documents(dataset_id, test_document_id);
        error('ndi.cloud.api.documents.bulk_delete_documents did not throw an error after using a document that does not exist');
    catch
        % do nothing, this is the expected behavior
    end

    document_ids = {};
    for i = 1:10
        test_document = struct("name", "test document");
        test_document = jsonencode(test_document);
        % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.add_document_as_file with ndi.cloud.api.documents.addDocumentAsFile
        [response, test_document_id] = ndi.cloud.api.documents.add_document_as_file(dataset_id, test_document);
        document_ids{end+1} = test_document_id;
    end
    % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.bulk_delete_documents with ndi.cloud.api.documents.bulkDeleteDocuments
    response = ndi.cloud.api.documents.bulk_delete_documents(dataset_id, document_ids);
    % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_dataset with ndi.cloud.api.datasets.getDataset
    [dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
    if (number_of_documents ~= numel(dataset.documents))
        error('ndi.cloud.api.datasets.get_dataset returns the same number of documents after deleting a document');
    end

    % try getting the document that was deleted. If no error is thrown, then the document was not deleted
    % try delete_document to delete a document that does not exist
    for i = 1:numel(document_ids)
        try
            % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.get_document with ndi.cloud.api.documents.getDocument
            [response, test_document] = ndi.cloud.api.documents.get_document(dataset_id, document_ids(i));
            error('ndi.cloud.api.documents.get_document did not throw an error after using bulk_delete_documents');
        catch
            % do nothing, this is the expected behavior
        end
        try
            % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.delete_document with ndi.cloud.api.documents.deleteDocument
            response = ndi.cloud.api.documents.delete_document(dataset_id, document_ids(i));
            error('ndi.cloud.api.documents.delete_document did not throw an error after using bulk_delete_documents');
        catch
            % do nothing, this is the expected behavior
        end
    end
end
