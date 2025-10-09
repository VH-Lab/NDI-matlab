function [status, response] = add(dataset_id, doc_data, varargin)
% MOCK add - A mock implementation for testing.
%
% This function adds a document to the mock datastore.

    % The document data is in JSON format in the real API,
    % but here we'll just expect a struct.

    new_doc_struct = jsondecode(doc_data);

    % Our mock datastore needs a list of structs, not a single one
    if ~isfield(new_doc_struct, 'id')
        new_doc_struct.id = ['mock_api_id_' char(matlab.lang.internal.uuid)];
    end

    ndi.cloud.api.documents.listDatasetDocumentsAll('add', new_doc_struct);

    status = 200;
    response = struct('message', 'Mock document added.');
end
