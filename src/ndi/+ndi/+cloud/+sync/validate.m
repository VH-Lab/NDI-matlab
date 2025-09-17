function [comparison_report, local_comparison_structs, remote_comparison_structs] = validate(ndiDataset, options)
% VALIDATE - Compare a local NDI dataset with its cloud counterpart.
%
%   [COMPARISON_REPORT, LOCAL_STRUCTS, REMOTE_STRUCTS] = ndi.cloud.sync.validate(NDIDATASET, Name, Value, ...)
%
%   This function compares the documents of a local ndi.dataset object with
%   the documents in its corresponding remote NDI cloud dataset. It identifies
%   documents that exist only locally, only remotely, or on both, and for
%   common documents, it checks if their content matches (excluding the 'files' field).
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object to be
%           validated against its remote counterpart.
%
%   Name-Value Pair Arguments:
%       'Mode' (1,1) string - Specifies the comparison strategy. Default is "bulk".
%           - "bulk": Downloads all remote documents in a single batch for
%             comparison. This is generally faster, especially for datasets
%             with many documents.
%           - "serial": Downloads and compares each remote document one by one.
%             This can be slower but may be useful for very large individual
%             documents or for debugging.
%       'Verbose' (1,1) logical - If true, detailed progress messages are
%           printed to the console. Default is true.
%
%   Outputs:
%       comparison_report (struct) - A structure summarizing the comparison results:
%           .local_only_ids (string array): NDI IDs of documents found only in the local dataset.
%           .remote_only_ids (string array): NDI IDs of documents found only on the remote dataset.
%           .common_ids (string array): NDI IDs of documents found in both datasets.
%           .mismatched_ids (string array): NDI IDs of common documents whose content does not match.
%           .mismatch_details (struct array): An array of structures with details for each mismatch.
%       local_comparison_structs (cell array) - A cell array of the local document
%           property structures for each mismatched document, ready for inspection.
%       remote_comparison_structs (cell array) - A cell array of the remote document
%           property structures for each mismatched document, ready for inspection.
%
%   See also:
%       ndi.cloud.syncDataset, ndi.cloud.download.download_document_collection
    arguments
        ndiDataset (1,1) ndi.dataset
        options.Mode (1,1) string {mustBeMember(options.Mode, ["bulk", "serial"])} = "bulk"
        options.Verbose (1,1) logical = true
        options.cloudDatasetId (1,1) string = "";
    end
    if options.Verbose, fprintf('Starting validation for dataset: %s\n', ndiDataset.path); end
    % Initialize the report structure
    comparison_report = struct(...
        'local_only_ids', string([]), ...
        'remote_only_ids', string([]), ...
        'common_ids', string([]), ...
        'mismatched_ids', string([]), ...
        'mismatch_details', struct('ndiId',{},'apiId',{},'reason',{}) ...
    );
    % Initialize new outputs for debugging
    local_comparison_structs = {};
    remote_comparison_structs = {};
    % Step 1: Get the cloud dataset ID from the local dataset
    if isempty(options.cloudDatasetId)
        try
            cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
            if options.Verbose, fprintf('Cloud Dataset ID: %s\n', cloudDatasetId); end
        catch ME
            error('Could not retrieve cloud dataset ID. Ensure the local dataset is linked to a remote one. Original error: %s', ME.message);
        end
    else
        cloudDatasetId = options.cloudDatasetId;
    end
    % Step 2: Get lists of local and remote documents
    if options.Verbose, fprintf('Fetching local and remote document lists...\n'); end
    [local_docs, local_doc_ids] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
    remote_doc_id_map = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
    remote_doc_ids = remote_doc_id_map.ndiId;
    if options.Verbose, fprintf('Found %d local documents and %d remote documents.\n', numel(local_doc_ids), numel(remote_doc_ids)); end
    % Step 3: Identify differences in document presence
    comparison_report.local_only_ids = setdiff(local_doc_ids, remote_doc_ids);
    comparison_report.remote_only_ids = setdiff(remote_doc_ids, local_doc_ids);
    [comparison_report.common_ids, local_common_indices, remote_common_indices] = intersect(local_doc_ids, remote_doc_ids);
    
    if options.Verbose
        fprintf('%d documents are local only.\n', numel(comparison_report.local_only_ids));
        fprintf('%d documents are remote only.\n', numel(comparison_report.remote_only_ids));
        fprintf('%d documents are common and will be compared.\n', numel(comparison_report.common_ids));
    end
    if isempty(comparison_report.common_ids)
        if options.Verbose, fprintf('No common documents to compare. Validation complete.\n'); end
        return;
    end
    % Step 4: Compare common documents based on the selected mode
    common_local_docs = local_docs(local_common_indices);
    common_remote_api_ids = remote_doc_id_map.apiId(remote_common_indices);
    mismatched_ids_list = {};
    mismatch_details_list = {};
    switch options.Mode
        case "bulk"
            if options.Verbose, fprintf('Starting comparison in BULK mode...\n'); end
            
            % Download all common remote documents at once
            if options.Verbose, fprintf('Downloading %d remote documents for comparison...\n', numel(common_remote_api_ids)); end
            remote_docs_downloaded = ndi.cloud.download.download_document_collection(cloudDatasetId, common_remote_api_ids);
            
            % Create a map for easy lookup
            remote_docs_map = containers.Map();
            for i=1:numel(remote_docs_downloaded)
                remote_docs_map(remote_docs_downloaded{i}.id()) = remote_docs_downloaded{i};
            end
            for i=1:numel(common_local_docs)
                local_doc = common_local_docs{i};
                ndi_id = local_doc.id();
                
                if isKey(remote_docs_map, ndi_id)
                    remote_doc = remote_docs_map(ndi_id);
                    
                    % Prepare for comparison by removing 'files' and 'id' fields
                    local_props = local_doc.document_properties;
                    remote_props = remote_doc.document_properties;
                    if isfield(local_props,'files'), local_props = rmfield(local_props,'files'); end
                    if isfield(remote_props,'files'), remote_props = rmfield(remote_props,'files'); end
                    if isfield(remote_props,'id'), remote_props = rmfield(remote_props,'id'); end
                    
                    if ~isequaln(local_props, remote_props)
                        mismatched_ids_list{end+1} = ndi_id;
                        mismatch_details_list{end+1} = struct('ndiId',ndi_id,'apiId',common_remote_api_ids(i),'reason','Document properties do not match.');
                        % Capture structs for debugging
                        local_comparison_structs{end+1} = local_props;
                        remote_comparison_structs{end+1} = remote_props;
                    end
                else
                    mismatched_ids_list{end+1} = ndi_id;
                    mismatch_details_list{end+1} = struct('ndiId',ndi_id,'apiId',common_remote_api_ids(i),'reason','Remote document could not be found in bulk download.');
                end
            end
        case "serial"
            if options.Verbose, fprintf('Starting comparison in SERIAL mode...\n'); end
            
            for i=1:numel(comparison_report.common_ids)
                ndi_id = comparison_report.common_ids(i);
                api_id = common_remote_api_ids(i);
                
                if options.Verbose, fprintf('Comparing document %d/%d: %s\n', i, numel(comparison_report.common_ids), ndi_id); end
                
                % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.get_document with ndi.cloud.api.documents.getDocument
                [~, remote_doc_struct] = ndi.cloud.api.documents.get_document(cloudDatasetId, api_id);
                local_doc = common_local_docs{i};
                
                % Prepare for comparison
                local_props = local_doc.document_properties;
                remote_props = remote_doc_struct;
                if isfield(local_props,'files'), local_props = rmfield(local_props,'files'); end
                if isfield(remote_props,'files'), remote_props = rmfield(remote_props,'files'); end
                if isfield(remote_props,'id'), remote_props = rmfield(remote_props,'id'); end
                
                if ~isequaln(local_props, remote_props)
                    mismatched_ids_list{end+1} = ndi_id;
                    mismatch_details_list{end+1} = struct('ndiId',ndi_id,'apiId',api_id,'reason','Document properties do not match.');
                    % Capture structs for debugging
                    local_comparison_structs{end+1} = local_props;
                    remote_comparison_structs{end+1} = remote_props;
                end
            end
    end
    if ~isempty(mismatched_ids_list)
        comparison_report.mismatched_ids = string(mismatched_ids_list(:));
        comparison_report.mismatch_details = cat(1, mismatch_details_list{:});
    end
    if options.Verbose
        fprintf('%d mismatched documents found.\n', numel(comparison_report.mismatched_ids));
        fprintf('Validation complete.\n');
    end
end