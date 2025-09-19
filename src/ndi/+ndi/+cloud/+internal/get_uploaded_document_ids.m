function uploaded_document_ids = get_uploaded_document_ids(dataset_id)
% get_uploaded_document_ids - Get cell array of uploaded document ids.
%
%   Use api endpoint to get ids for all remote (cloud) documents

    [success, result] = ndi.cloud.api.documents.listDatasetDocumentsAll(dataset_id);
    if ~success
        error(['Failed to list dataset documents: ' result.message]);
    end

    if ~isempty(result.documents)
        uploaded_document_ids = {result.documents.ndiId};
    else
        uploaded_document_ids = {};
    end

    uploaded_document_ids = string(uploaded_document_ids);
end
