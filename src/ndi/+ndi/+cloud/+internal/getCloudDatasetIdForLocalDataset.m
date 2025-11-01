function [cloudDatasetId, cloudDatasetIdDocument] = getCloudDatasetIdForLocalDataset(ndiDataset)
% GETCLOUDDATASETIDFORLOCALDATASET - Retrieves the cloud dataset ID for a local dataset.
%
% [CLOUDDATASETID, CLOUDDATASETIDDOCUMENT] = ...
%   GETCLOUDDATASETIDFORLOCALDATASET(NDIDATASET)
%
% This function searches the database of a local NDI dataset for a unique
% 'dataset_remote' document. This document establishes a link between the
% local dataset and its remote counterpart in the NDI cloud.
%
% If a single 'dataset_remote' document is found, the function extracts and
% returns the cloud dataset's unique identifier.
%
% The function handles three cases:
%   1. No 'dataset_remote' document is found: It returns an empty string for
%      the ID and an empty cell for the document.
%   2. Exactly one 'dataset_remote' document is found: It returns the cloud
%      dataset ID and the corresponding ndi.document object.
%   3. More than one 'dataset_remote' document is found: It raises an error,
%      as this indicates a misconfiguration.
%
% Inputs:
%   ndiDataset (ndi.dataset) - The local NDI dataset object to search within.
%
% Outputs:
%   cloudDatasetId (string) - The unique identifier of the remote cloud
%     dataset. Returns an empty string if no 'dataset_remote' document is
%     found.
%   cloudDatasetIdDocument (cell of ndi.document) - A cell array containing
%     the 'dataset_remote' document object. Returns an empty cell array if
%     no document is found.
%
% Example:
%   % Assume my_dataset is a valid ndi.dataset object
%   [cloudId, cloudDoc] = ...
%     ndi.cloud.internal.getCloudDatasetIdForLocalDataset(my_dataset);
%   if isempty(cloudId)
%     disp('This local dataset is not linked to a cloud dataset.');
%   else
%     disp(['Cloud dataset ID: ' cloudId]);
%   end
%
% See also: ndi.cloud.internal.createRemoteDatasetDoc

    arguments
        ndiDataset (1,1) ndi.dataset
    end
    cloudDatasetIdQuery = ndi.query('','isa','dataset_remote');
    cloudDatasetIdDocument = ndiDataset.database_search(cloudDatasetIdQuery);
    if numel(cloudDatasetIdDocument) > 1
        error('NDICloud:Sync:MultipleCloudDatasetId', ...
            ['Found more than one remote cloudDatasetId for the local ', ...
            'dataset: %s.'], ndiDataset.path);
    elseif ~isempty(cloudDatasetIdDocument)
        cloudDatasetId = cloudDatasetIdDocument{1}.document_properties.dataset_remote.dataset_id;
    else
        cloudDatasetId = '';
    end
end
