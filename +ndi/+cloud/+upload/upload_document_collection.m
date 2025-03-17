function upload_document_collection(datasetId, documentList)
% upload_document_collection - Upload collection of documents using bulk upload

    arguments
        datasetId (1,1) string
        documentList (1,:) cell
    end

    [zipFilePath, fileCleanupObj] = ndi.cloud.upload.zip_documents_for_upload(documentList); %#ok<ASGLU>
    uploadUrl = ndi.cloud.api.documents.get_bulk_upload_url(datasetId);
    ndi.cloud.api.files.put_files(uploadUrl, zipFilePath);
end
