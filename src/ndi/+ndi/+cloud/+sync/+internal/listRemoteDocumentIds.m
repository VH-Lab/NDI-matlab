function [id_map] = listRemoteDocumentIds(cloudDatasetId, options)
% LISTREMOTEDOCUMENTIDS - List all NDI and API document IDs from a remote dataset.
%
%   [ID_MAP] = ndi.cloud.sync.internal.listRemoteDocumentIds(CLOUDDATASETID, Name, Value, ...)
%
%   This function retrieves a complete list of documents from a specified NDI cloud
%   dataset by calling a helper function that handles API result pagination.
%
%   Inputs:
%       cloudDatasetId (1,1) string - The unique identifier of the cloud dataset.
%
%   Name-Value Pair Arguments:
%       'Verbose' (1,1) logical - If true, displays progress information.
%           This is passed to the underlying API function. Default is false.
%
%   Outputs:
%       id_map (struct) - A structure containing two fields:
%           .ndiId (string array): An array of NDI document IDs.
%           .apiId (string array): An array of the corresponding cloud API document IDs ('_id').
%           The arrays are ordered such that id_map.ndiId(i) corresponds to id_map.apiId(i).
%
%   See also:
%       ndi.cloud.api.documents.list_documents_all

    arguments
        cloudDatasetId (1,1) string
        options.Verbose (1,1) logical = false
    end

    if options.Verbose
        fprintf('Fetching complete remote document list for dataset %s...\n', cloudDatasetId);
    end

    try
        % Delegate the fetching and pagination logic to the dedicated function
        [success,all_documents] = ndi.cloud.api.documents.listDatasetDocumentsAll(cloudDatasetId);

        if ~success
             % Handle failure
             if ischar(all_documents) || isstring(all_documents)
                 error('NDI:listRemoteDocumentIds:apiError', ...
                     'Failed to list remote documents for dataset %s. Reason: %s', cloudDatasetId, all_documents);
             elseif isstruct(all_documents) && isfield(all_documents, 'message')
                 error('NDI:listRemoteDocumentIds:apiError', ...
                     'Failed to list remote documents for dataset %s. Reason: %s', cloudDatasetId, all_documents.message);
             else
                 error('NDI:listRemoteDocumentIds:apiError', ...
                     'Failed to list remote documents for dataset %s. Unknown error.', cloudDatasetId);
             end
        end

        if isempty(all_documents)
            % Handle case where the dataset is empty
            id_map = struct('ndiId', string([]), 'apiId', string([]));
            if options.Verbose, fprintf('No remote documents found.\n'); end
            return;
        end
        
        % Efficiently extract IDs from the full list of documents
        all_ndi_ids = string(cat(1,all_documents.ndiId));
        all_api_ids = string(cat(1,all_documents.id));

        if options.Verbose
            fprintf('Total remote documents processed: %d.\n', numel(all_ndi_ids));
        end

    catch ME
        error('NDI:listRemoteDocumentIds:apiError', ...
            'Failed to list all remote documents. Original error: %s', ME.message);
    end

    % Create the final output structure
    id_map = struct('ndiId', all_ndi_ids(:), 'apiId', all_api_ids(:)); % Ensure column vectors
end
