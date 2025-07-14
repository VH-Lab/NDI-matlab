function upload_document_collection(datasetId, documentList)
% UPLOAD_DOCUMENT_COLLECTION - Upload a collection of documents using bulk upload
%
%   ndi.cloud.upload.upload_document_collection(datasetId, documentList) performs 
%    a bulk upload of documents to a specified dataset. It creates a ZIP archive 
%    from the provided document list, retrieves a bulk upload URL for the 
%    dataset, and then uploads the ZIP file to the cloud.
%
%  IF the environment variable 'NDI_CLOUD_UPLOAD_NO_ZIP' exists and is true
%    then the documents are uploaded one at a time via a slower process.
%
% INPUTS:
%    datasetId    - (1,1) string
%                   Unique identifier for the dataset to which the documents 
%                   are to be uploaded (NDI Cloud dataset identifier).
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
% See also: 
%   ndi.cloud.api.documents.get_bulk_upload_url
%   ndi.cloud.upload.internal.zip_documents_for_upload

    arguments
        datasetId (1,1) string
        documentList (1,:) cell
    end

    assert(~isempty(documentList), 'List of documents was empty.')

    if isa(documentList{1}, 'ndi.document')
        for i = 1:numel(documentList) % Extract structure from the document object
            documentList{i} = documentList{i}.document_properties;
        end
    end

    ndiCloudUploadNoZipEnvironment = getenv('NDI_CLOUD_UPLOAD_NO_ZIP');
    if isempty(ndiCloudUploadNoZipEnvironment)
       ndiCloudUploadNoZipEnvironment = "false";
    end

    if strcmp(ndiCloudUploadNoZipEnvironment,'true')
        app = ndi.gui.component.ProgressBarWindow('NDI tasks');
        uuid = did.ido.unique_id();
        app.addBar('Label','Uploading documents','tag',uuid,'Auto',true);
        for i=1:numel(documentList)
            r=ndi.cloud.api.documents.add_document(datasetId,jsonencodenan(documentList{i}));
            app.updateBar(uuid,i/numel(documentList));
        end
    else % follow standard procedures
        [zipFilePath, fileCleanupObj] = ...
            ndi.cloud.upload.internal.zip_documents_for_upload(documentList); %#ok<ASGLU>
        uploadUrl = ndi.cloud.api.documents.get_bulk_upload_url(datasetId);
        ndi.cloud.api.files.put_files(uploadUrl, zipFilePath);
    end
end
