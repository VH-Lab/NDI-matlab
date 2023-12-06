function [status, response,dataset_id] = create_cloud_metadata_struct(auth_token, organization_id, S, size)
% CREATE_CLOUD_METADATA - upload metadata to the NDI Cloud
%
% [STATUS, DATASET] = ndi.cloud.CREATE_CLOUD_METADATA_STRUCT(AUTH_TOKEN, ORGANIZATION_ID, S, SIZE)
%
% Inputs:
%   ORGANIZATION_ID - the organization ID for NDI Cloud
%   AUTH_TOKEN - an upload token for NDI Cloud
%   S - a struct with the metadata to create
%   SIZE - the size of the dataset in kilobytes
%
% Outputs:
%   STATUS - did the upload work? 0 for no, 1 for yes
%   DATASET - The created dataset
%

% loops over all the metadata fields and posts a value to the cloud API

all_fields = {'name','branchName','contributors','doi','funding','abstract','license','species','numberOfSubjects','correspondingAuthors', 'totalSize'};

clear dataset_update;

is_valid = ndi.cloud.fun.check_metadata_cloud_inputs(S);
if ~is_valid
    error('NDI:CLOUD:CREATE_CLOUD_METADATA_STRUCT', 'S is missing required fields');
end

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
uniqueFunders = unique({S.Funding.funder});
dataset_update.funding.source = strjoin(uniqueFunders, ', ');
dataset_update.abstract = S.Description{1};
% license = openminds.internal.getControlledInstance( S.License, 'License', 'core');
dataset_update.license = S.License;
species_str = '';
for i = 1:numel(S.Subjects)
    species_str = [species_str, S.Subjects(i).SpeciesList.Name, ', '];
end
species_str = species_str(1:end-2);
dataset_update.species = species_str;
dataset_update.numberOfSubjects = numel(S.Subjects);
indices = [];
for i = 1:numel(S.Author)
    if strcmp(S.Author(i).authorRole, 'Corresponding')
        indices = [indices; i];
    end
end

dataset_update.correspondingAuthors = dataset_update.contributors(indices);
% dataset_update.brainRegions = brainRegions;
dataset_update.totalSize = round(size);
[status, response, dataset_id] = ndi.cloud.datasets.post_organization(organization_id, dataset_update, auth_token);
end

