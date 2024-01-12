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
disp(['There are ' numel(documents_summary.documents) ' documents in the dataset' ])
openminds_documents_id = {};
for i=1:numel(documents_summary.documents)
    document_id = documents_summary.documents(i).id;
    [status, response, document] = ndi.cloud.documents.get_documents(dataset_id, document_id, auth_token);
    % if document has an openminds field, delete it
    if isfield(document.document_properties,'openminds')
        session_id = document.document_properties.base.session_id;
        doc_str = jsonencode(document);
        %what is the document size
        info = whos('doc_str');
        size = size + info.bytes;
        % add the document id to the list of documents to delete
        openminds_documents_id{end+1}= document_id;
    end
end
disp(['There are ' numel(openminds_documents_id) ' openminds documents in the dataset' ])
disp(['Deleting ' num2str(size/1024) ' kilobytes of documents' ])
[statu, dataset] = ndi.cloud.datasets.post_bulk_delete(dataset_id, openminds_documents_id, auth_token);

size = size/1024;
[status, response, documents_summary] = ndi.cloud.documents.get_documents_summary(dataset_id, auth_token);
disp(['There are ' numel(documents_summary.documents) ' documents left in the dataset' ])
end

