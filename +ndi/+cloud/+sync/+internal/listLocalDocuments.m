function [documents, documentIds] = listLocalDocuments(ndiDataset)
% listLocalDocuments - List documents in local dataset
%
% Utility function to retrieve all documents from a local dataset and
% optionally also return their document ids.

    arguments
        ndiDataset (1,1) ndi.dataset
    end

    documents = ndiDataset.database_search( ndi.query('','isa','base') );
    if nargout == 2
        documentIds = string( cellfun(@(doc) doc.document_properties.base.id, ...
            documents, 'UniformOutput', false) );
    end
end
