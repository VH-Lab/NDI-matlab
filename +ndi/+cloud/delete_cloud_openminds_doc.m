function [size, session_id, openminds_doc] = delete_cloud_openminds_doc(dataset_id)
%DELETE_CLOUD_OPENMINDS_DOC - delete all the openminds documents in the dataset
%   [SIZE,SESSION_ID, OPENMINDS_DOC] = ndi.cloud.delete_cloud_openminds_doc(DATASET_ID)
%
%   input:
%   DATASET_ID - the dataset id where the documents will be deleted
%   
%   output:
%   SIZE - the size (in kilobytes) of the deleted documents
%   SESSION_ID - the session id of the deleted documents
%   OPENMINDS_DOC - the openminds docs that have been deleted

size = 0;
[status, response, documents_summary] = ndi.cloud.api.documents.get_documents_summary(dataset_id);
disp(['There are ' num2str(numel(documents_summary.documents)) ' documents in the dataset' ])
openminds_documents_id = {};
for i=1:numel(documents_summary.documents)
    document_id = documents_summary.documents(i).id;
    [status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
    % if document has an openminds field, delete it
    if isfield(document,'openminds')
        session_id = document.base.session_id;
        doc_str = jsonencode(document);
        %what is the document size
        info = whos('doc_str');
        size = size + info.bytes;
        % add the document id to the list of documents to delete
        openminds_documents_id{end+1}= document_id;
    end
end

openminds_doc = {};
for i = 1:numel(openminds_documents_id)
    [status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, openminds_documents_id{i});
    openminds_doc{i} = document;
end

disp(['There are ' num2str(numel(openminds_documents_id)) ' openminds documents in the dataset' ])
disp(['Deleting ' num2str(size/1024) ' kilobytes of documents' ])
[statu, dataset] = ndi.cloud.api.datasets.post_bulk_delete(dataset_id, openminds_documents_id);

size = size/1024;
[status, response, documents_summary] = ndi.cloud.api.documents.get_documents_summary(dataset_id);
disp(['There are ' num2str(numel(documents_summary.documents)) ' documents left in the dataset' ])

end
