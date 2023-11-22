function [status, response,dataset_id] = create_cloud_metadata_struct(organization_id, auth_token, S, brainRegions)
% UPDATE_CLOUD_METADATA - upload metadata to the NDI Cloud
%
% [STATUS, DATASET] = ndi.cloud.UPDATE_CLOUD_METADATA_STRUCT(DATASETID, AUTH_TOKEN, S)
%
% Inputs:
%   DATASETID - the dataset ID to update
%   AUTH_TOKEN - an upload token for NDI Cloud
%   S - a struct with the metadata to upload
%
% Outputs:
%   STATUS - did the upload work? 0 for no, 1 for yes
%   DATASET - The updated dataset
%

% loops over all the metadata fields and posts an updated value to the cloud API

all_fields = {'name','branchName','contributors','doi','funding','abstract','license','species','numberOfSubjects','correspondingAuthors'};

clear dataset_update;

dataset_update.name = S.DatasetFullName;
dataset_update.branchName = S.DatasetShortName;
author_struct = struct();
for i = 1:numel(S.Author)
    author_struct(i).firstName = S.Author(i).givenName;
    author_struct(i).lastName = S.Author(i).familyName;
    author_struct(i).orchid = S.Author(i).digitalIdentifier.identifier;
end
dataset_update.contributors = author_struct;
dataset_update.doi = "https://doi.org://10.1000/123456789";
% uniqueFunders = unique({S.Funding.funder});
% dataset_update.funding.source = strjoin(uniqueFunders, ', ');
dataset_update.abstract = S.Description{1};
% license = openminds.internal.getControlledInstance( S.License, 'License', 'core');
% dataset_update.license = license.fullName;
dataset_update.species = S.Subjects.SpeciesList.Name;
dataset_update.numberOfSubjects = numel(S.Subjects);
indices = [];
for i = 1:numel(S.Author)
    if strcmp(S.Author(i).authorRole, 'Corresponding')
        indices = [indices; i];
    end
end

dataset_update.correspondingAuthors = dataset_update.contributors(indices);
dataset_update.brainRegions = brainRegions;
[status, response, dataset_id] = ndi.cloud.datasets.post_organization(organization_id, dataset_update, auth_token);
end

