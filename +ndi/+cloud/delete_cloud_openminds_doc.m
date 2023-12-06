function [size, session_id] =  delete_cloud_openminds_doc(auth_token,dataset_id)
%DELETE_CLOUD_OPENMINDS_DOC - delete all the openminds documents in the dataset
%   ndi.cloud.delete_cloud_openminds_doc(AUTH_TOKEN,DATASET_ID)
%
%   input:
%   AUTH_TOKEN - the authorization token
%   DATASET_ID - the dataset id where the documents will be deleted
%   
%   output:
%   SIZE - the size (in kilobytes) of the deleted documents
%   SESSION_ID - the session id of the deleted documents

size = 0;
[status, response, documents_summary] = ndi.cloud.documents.get_documents_summary(dataset_id, auth_token);
disp(numel(documents_summary.documents))
for i=1:numel(documents_summary.documents)
    document_id = documents_summary.documents(i).id;
    [status, response, document] = ndi.cloud.documents.get_documents(dataset_id, document_id, auth_token);
    % if document has an openminds field, delete it
    if isfield(document,'openminds')
        session_id = document.base.session_id;
        doc_str = jsonencode(document);
        %what is the document size
        info = whos('doc_str');
        size = size + info.bytes;
        [status, response] = ndi.cloud.documents.delete_documents(dataset_id, document_id, auth_token);
    end
end
size = size/1024;
[status, response, documents_summary] = ndi.cloud.documents.get_documents_summary(dataset_id, auth_token);
disp(numel(documents_summary.documents))
end

