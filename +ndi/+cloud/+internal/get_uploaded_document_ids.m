function uploaded_document_ids = get_uploaded_document_ids(dataset_id)
% get_uploaded_document_ids - Get cell array of uploaded document ids.
%
%   Use api endpoint to get ids for all uploaded documents

    [~, result] = ndi.cloud.api.documents.list_dataset_documents(dataset_id);

    if ~isempty(result.documents)
        uploaded_document_ids = {result.documents.ndiId};
    else
        uploaded_document_ids = {};
    end
end
