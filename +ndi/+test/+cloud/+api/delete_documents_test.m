function delete_documents_test(dataset_id)
    %DELETE_DOCUMENTS_TEST - test the delete_documents and bulk_delete function
    %
    % DELETE_DOCUMENTS_TEST(DATASET_ID)
    %
    % Test the following api commands:
    %   documents/delete_documents
    %   documents/post_bulk_delete
    %   documents/get_documents_summary
    %


    [status, dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);
    number_of_documents = numel(dataset.documents);
    test_document = struct("name", "test document");
    test_document = jsonencode(test_document);
    [fid,fname] = ndi.file.temp_fid();
    [status, response, test_document_id] = ndi.cloud.api.documents.post_documents(fname, dataset_id, test_document);
    [status, response] = ndi.cloud.api.documents.delete_documents(dataset_id, test_document_id);
    [status, dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);
    if (number_of_documents ~= numel(dataset.documents))
        error('ndi.cloud.api.datasets.get_datasetId returns the same number of documents after deleting a document');
    end
    [status, response, summary] = ndi.cloud.api.documents.get_documents_summary(dataset_id);
    if (number_of_documents ~= numel(summary.documents))
        error('ndi.cloud.api.documents.get_documents_summary returns the same number of documents after deleting a document');
    end
    % try getting the document that was deleted. If no error is thrown, then the document was not deleted
    try
        [status, response, test_document] = ndi.cloud.api.documents.get_documents(dataset_id, test_document_id);
        error('ndi.cloud.api.documents.get_documents did not throw an error after delete_documents');
    catch
        % do nothing, this is the expected behavior
    end

    % test bulk delete
    % try post_bulk_delete to delete a document that does not exist
    try
        [status, response] = ndi.cloud.api.datasets.post_bulk_delete(dataset_id, test_document_id);
        error('ndi.cloud.api.datasets.post_bulk_delete did not throw an error after using a document that does not exist');
    catch
        % do nothing, this is the expected behavior
    end

    document_ids = {};
    for i = 1:10
        test_document = struct("name", "test document");
        test_document = jsonencode(test_document);
        [fid,fname] = ndi.file.temp_fid();
        [status, response, test_document_id] = ndi.cloud.api.documents.post_documents(fname, dataset_id, test_document);
        if status ~= 0
            error(response);
        end
        document_ids{end+1} = test_document_id;
    end
    [status, response] = ndi.cloud.api.datasets.post_bulk_delete(dataset_id, document_ids);
    [status, dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);
    if (number_of_documents ~= numel(dataset.documents))
        error('ndi.cloud.api.datasets.get_datasetId returns the same number of documents after deleting a document');
    end

    % try getting the document that was deleted. If no error is thrown, then the document was not deleted
    % try delete_document to delete a document that does not exist
    for i = 1:numel(document_ids)
        try
            [status, response, test_document] = ndi.cloud.api.documents.get_documents(dataset_id, document_ids(i));
            error('ndi.cloud.api.documents.get_documents did not throw an error after using post_bulk_delete');
        catch
            % do nothing, this is the expected behavior
        end
        try
            [status, response] = ndi.cloud.api.documents.delete_documents(dataset_id, document_ids(i));
            error('ndi.cloud.api.documents.delete_documents did not throw an error after using post_bulk_delete');
        catch
            % do nothing, this is the expected behavior
        end
    end

end

