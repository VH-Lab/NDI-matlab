function upload_document_collection(datasetId, documentList)
% UPLOAD_DOCUMENT_COLLECTION - Upload a collection of documents using bulk upload
%
%   ndi.cloud.upload.upload_document_collection(datasetId, documentList) performs 
%    a bulk upload of documents to a specified dataset. It creates a ZIP archive 
%    from the provided document list, retrieves a bulk upload URL for the 
%    dataset, and then uploads the ZIP file to the cloud.
%
% INPUTS:
%    datasetId    - (1,1) string
%                   Unique identifier for the dataset to which the documents 
%                   are to be uploaded.
%
%    documentList - (1,:) cell
%                   A cell array containing the documents to be uploaded. 
%                   Each element of the cell array is a structure representing 
%                   an individual document for inclusion in the upload.
%
% EXAMPLE:
%    % Upload a collection of documents to a dataset:
%    docs = {doc1, doc2, doc3};
%    ndi.cloud.upload.upload_document_collection("dataset123", docs);
%
% See also: ndi.cloud.upload.zip_documents_for_upload, ndi.cloud.api.documents.get_bulk_upload_url

    arguments
        datasetId (1,1) string
        documentList (1,:) cell
    end

    [zipFilePath, fileCleanupObj] = ndi.cloud.upload.zip_documents_for_upload(documentList); %#ok<ASGLU>
    uploadUrl = ndi.cloud.api.documents.get_bulk_upload_url(datasetId);
    ndi.cloud.api.files.put_files(uploadUrl, zipFilePath);
end
