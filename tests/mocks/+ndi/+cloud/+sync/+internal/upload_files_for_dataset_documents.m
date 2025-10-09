function upload_files_for_dataset_documents(cloudDatasetId, ndiDocuments, syncOptions)
%MOCKUPLOAD Mock for uploading documents

    if syncOptions.Verbose
        fprintf('[Mock] Uploading %d documents...\n', numel(ndiDocuments));
    end

    docs_to_add = [];
    for i=1:numel(ndiDocuments)
        doc_struct = ndiDocuments{i}.to_struct();
        doc_struct.id = ['mock_api_id_' char(matlab.lang.internal.uuid)];
        if isempty(docs_to_add)
            docs_to_add = doc_struct;
        else
            docs_to_add(end+1) = doc_struct;
        end
    end

    if ~isempty(docs_to_add)
        ndi.cloud.api.documents.listDatasetDocumentsAll('add', docs_to_add);
    end

end
