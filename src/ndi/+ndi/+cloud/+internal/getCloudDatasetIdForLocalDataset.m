function [cloudDatasetId, cloudDatasetIdDocument] = getCloudDatasetIdForLocalDataset(ndiDataset)
% GETCLOUDDATASETIDFORLOCALDATASET - a companion to ndi.cloud.internal.createRemoteDatasetDoc
%
% [CLOUDDATASETID, CLOUDDATASETIDDOCUMENT] = GETCLOUDDATASETIDFORLOCALDATASET(NDIDATASET)
%
% Reads the remotedataset doc and returns the remote cloud id.
% If there is no cloudDatasetId, it returns an empty string.
% If there is more than one dataset_remote document, it errors.
%
% The second output argument returns the cloudDatasetIdDocument itself.
%
    arguments
        ndiDataset ndi.dataset
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
