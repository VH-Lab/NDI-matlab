function [status, response] = listDatasetDocumentsAll(command, varargin)
% MOCK listDatasetDocumentsAll - A mock implementation for testing.
%
% This function acts as a simple in-memory "database" for documents.
%
% Commands:
%   'list', dataset_id, ...  - Lists documents (the actual mocked function)
%   'set', new_docs          - Overwrites the entire document list.
%   'add', docs_to_add       - Adds new documents to the list.
%   'delete', ids_to_delete  - Deletes documents by their 'ndiId'.
%   'clear'                  - Clears all documents.

persistent mock_documents;

if isempty(mock_documents)
    mock_documents = struct('ndiId', {}, 'id', {}, 'name', {});
end

switch lower(command)
    case 'list'
        % This is the actual mock for the function call
        status = 200;
        response = struct('documents', mock_documents);

    case 'set'
        mock_documents = varargin{1};
        status = 200;
        response = struct('message', 'Mock data set.');

    case 'add'
        new_docs = varargin{1};
        if isempty(mock_documents)
            mock_documents = new_docs;
        else
            mock_documents = [mock_documents; new_docs(:)];
        end
        status = 200;
        response = struct('message', 'Mock data added.');

    case 'delete'
        ids_to_delete = string(varargin{1});
        if ~isempty(mock_documents)
            ids = string({mock_documents.ndiId});
            to_keep = ~ismember(ids, ids_to_delete);
            mock_documents = mock_documents(to_keep);
        end
        status = 200;
        response = struct('message', 'Mock data deleted.');

    case 'clear'
        mock_documents = struct('ndiId', {}, 'id', {}, 'name', {});
        status = 200;
        response = struct('message', 'Mock data cleared.');

    otherwise
        error('Unknown command for mock listDatasetDocumentsAll: %s', command);
end

end
