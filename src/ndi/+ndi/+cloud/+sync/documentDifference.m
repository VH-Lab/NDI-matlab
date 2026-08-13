function report = documentDifference(ndiDataset, options)
% DOCUMENTDIFFERENCE Compare local and remote document presence (ids only).
%
% Syntax:
%   REPORT = ndi.cloud.sync.documentDifference(NDIDATASET, Name, Value, ...)
%
%   Compares the set of documents in a local ndi.dataset with the set of
%   documents in its corresponding remote NDI Cloud dataset and reports which
%   documents exist only locally, only remotely, or in both.
%
%   Unlike ndi.cloud.sync.validate, this function compares document *ids*
%   only: it never downloads document contents, so it is cheap enough to back
%   an interactive "how many new documents are there?" status check. It does
%   not detect content mismatches between documents that exist on both sides.
%
%   No local or remote documents are added, deleted or modified.
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object. It must
%           be linked to a remote NDI Cloud dataset (see
%           ndi.cloud.internal.getCloudDatasetIdForLocalDataset) unless a
%           'cloudDatasetId' is supplied.
%
%   Name-Value Pair Arguments:
%       'cloudDatasetId' (1,:) char - The remote dataset id to compare
%           against. Default '' resolves the id from the local dataset's
%           'dataset_remote' document.
%       'Verbose' (1,1) logical - If true, prints progress. Default false.
%
%   Outputs:
%       report (struct) - A structure summarizing the comparison:
%           .local_only_ids (string array)  - NDI ids present only locally.
%           .remote_only_ids (string array) - NDI ids present only on the cloud.
%           .common_ids (string array)      - NDI ids present in both.
%           .num_local_only (double)        - numel(local_only_ids).
%           .num_remote_only (double)       - numel(remote_only_ids).
%           .num_common (double)            - numel(common_ids).
%
%   See also:
%       ndi.cloud.sync.validate,
%       ndi.cloud.internal.getCloudDatasetIdForLocalDataset

    arguments
        ndiDataset (1,1) ndi.dataset
        options.cloudDatasetId (1,:) char = ''
        options.Verbose (1,1) logical = false
    end

    % Step 1: Resolve the cloud dataset id from the local dataset if needed.
    if isempty(options.cloudDatasetId)
        try
            cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
        catch ME
            error('NDI:Cloud:Sync:NoCloudDatasetId', ...
                ['Could not retrieve the cloud dataset id. Ensure the local ' ...
                 'dataset is linked to a remote one. Original error: %s'], ME.message);
        end
        if isempty(cloudDatasetId)
            error('NDI:Cloud:Sync:NoCloudDatasetId', ...
                ['This dataset is not linked to a cloud dataset. Upload it to ' ...
                 'NDI Cloud first.']);
        end
    else
        cloudDatasetId = options.cloudDatasetId;
    end

    if options.Verbose
        fprintf('Comparing document presence for cloud dataset %s...\n', cloudDatasetId);
    end

    % Step 2: Gather the local and remote document id lists.
    [~, local_doc_ids] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
    remote_doc_id_map  = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
    remote_doc_ids     = remote_doc_id_map.ndiId;

    % Step 3: Compute the set differences.
    report = struct();
    report.local_only_ids  = setdiff(local_doc_ids, remote_doc_ids);
    report.remote_only_ids = setdiff(remote_doc_ids, local_doc_ids);
    report.common_ids      = intersect(local_doc_ids, remote_doc_ids);
    report.num_local_only  = numel(report.local_only_ids);
    report.num_remote_only = numel(report.remote_only_ids);
    report.num_common      = numel(report.common_ids);

    if options.Verbose
        fprintf(['%d local-only, %d remote-only, %d common document(s).\n'], ...
            report.num_local_only, report.num_remote_only, report.num_common);
    end
end
