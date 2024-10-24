function uploaded_document_ids = get_uploaded_document_ids(dataset_id)
    % get_uploaded_document_ids - Get cell array of uploaded document ids.
    %
    %   Use api endpoint to get ids for all uploaded documents

    auth_token = ndi.cloud.uilogin();
    try
        [~, result, ~] = ndi.cloud.documents.get_documents_summary(dataset_id, auth_token);
    catch ME
        rethrow(ME)
    end

    if ~isempty(result.documents)
        uploaded_document_ids = {result.documents.ndiId};
    else
        uploaded_document_ids = {};
    end
end
