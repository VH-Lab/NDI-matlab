function uploaded_document_ids = getUploadedDocumentIds(dataset_id)
% GETUPLOADEDDOCUMENTIDS - Get a list of uploaded document NDI IDs.
%
% UPLOADED_DOCUMENT_IDS = GETUPLOADEDDOCUMENTIDS(DATASET_ID)
%
% This function retrieves a complete list of all documents associated with a
% specific cloud dataset and returns their NDI IDs.
%
% It calls the ndi.cloud.api.documents.listDatasetDocumentsAll function to
% fetch all document metadata from the remote server. If the API call is
% successful, it extracts the 'ndiId' field from each document record.
%
% If the dataset contains no documents, the function returns an empty cell
% array.
%
% Inputs:
%   dataset_id (string) - The unique identifier of the cloud dataset.
%
% Outputs:
%   uploaded_document_ids (string array) - A string array containing the
%     NDI IDs of all documents in the dataset.
%
% Example:
%   % Assume 'd-12345' is a valid cloud dataset ID
%   doc_ids = ndi.cloud.internal.getUploadedDocumentIds('d-12345');
%   if isempty(doc_ids)
%     disp('No documents found in the dataset.');
%   else
%     disp(['Found ' num2str(numel(doc_ids)) ' documents.']);
%   end
%
% See also: ndi.cloud.api.documents.listDatasetDocumentsAll

    arguments
        dataset_id (1,:) char
    end

    [success, result] = ndi.cloud.api.documents.listDatasetDocumentsAll(dataset_id);
    if ~success
        error(['Failed to list dataset documents: ' result.message]);
    end

    if ~isempty(result)
        uploaded_document_ids = {result.ndiId};
    else
        uploaded_document_ids = {};
    end

    uploaded_document_ids = string(uploaded_document_ids);
end
