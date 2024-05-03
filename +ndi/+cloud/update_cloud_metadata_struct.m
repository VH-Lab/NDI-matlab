function [status, dataset] = update_cloud_metadata_struct(dataset_id, auth_token, S, size)
% UPDATE_CLOUD_METADATA - upload metadata to the NDI Cloud
%
% [STATUS, DATASET] = ndi.cloud.UPDATE_CLOUD_METADATA_STRUCT(DATASETID, AUTH_TOKEN, S, SIZE)
%
% Inputs:
%   DATASETID - the dataset ID to update
%   AUTH_TOKEN - an upload token for NDI Cloud
%   S - a struct with the metadata to upload
%   SIZE - a float representing the size of this dataset in kilobytes
%
% Outputs:
%   STATUS - did the upload work? 0 for no, 1 for yes
%   DATASET - The updated dataset
%

% loops over all the metadata fields and posts an updated value to the cloud API

all_fields = {'name','branchName','contributors','doi','funding','abstract','license','species','numberOfSubjects','correspondingAuthors'};

clear dataset_update;

is_valid = ndi.cloud.fun.check_metadata_cloud_inputs(S);
if ~is_valid
    error('NDI:CLOUD:UPDATE_CLOUD_METADATA_STRUCT', ...
          'Metadata struct is missing required fields');
end
if isfield(S, 'DatasetFullName')
    dataset_update.name = S.DatasetFullName;
end
if isfield(S, 'DatasetShortName')
    dataset_update.branchName = S.DatasetShortName;
end
if isfield(S, 'Author')
    author_struct = struct();
    for i = 1:numel(S.Author)
        author_struct(i).firstName = S.Author(i).givenName;
        author_struct(i).lastName = S.Author(i).familyName;
        author_struct(i).orchid = S.Author(i).digitalIdentifier.identifier;
    end
    dataset_update.contributors = author_struct;
    indices = [];
    for i = 1:numel(S.Author)
        if strcmp(S.Author(i).authorRole, 'Corresponding')
            indices = [indices; i];
        end
    end

dataset_update.correspondingAuthors = dataset_update.contributors(indices);
end
dataset_update.doi = "https://doi.org://10.1000/123456789";
if isfield(S, 'Funding')
    uniqueFunders = unique({S.Funding.funder});
    dataset_update.funding.source = strjoin(uniqueFunders, ', ');
end
if isfield(S, 'Description')
    dataset_update.abstract = S.Description{1};
end
% license = openminds.internal.getControlledInstance( S.License, 'License', 'core');
% dataset_update.license = license.fullName;
if isfield(S, 'License')
    dataset_update.license = S.License;
end
if isfield(S, 'Subjects')
    species_str = '';
    all_species = {};
    for i = 1:numel(S.Subjects)
        all_species = [all_species, S.Subjects(i).SpeciesList.Name];
    end
    all_species = unique(all_species);
    for i = 1:numel(all_species)
        species_str = [species_str, all_species{i}, ', '];
    end
    species_str = species_str(1:end-2);
    dataset_update.species = species_str;
    dataset_update.numberOfSubjects = numel(S.Subjects);
end
if isfield(S, 'RelatedPublication')
    associate_publications_struct = struct();
    for i = 1:numel(S.RelatedPublication)
        associate_publications_struct(i).DOI = S.RelatedPublication(i).DOI;
        associate_publications_struct(i).title = S.RelatedPublication(i).Publication;
        associate_publications_struct(i).PMID = S.RelatedPublication(i).PMID;
        associate_publications_struct(i).PMCID = S.RelatedPublication(i).PMCID;
    end
    dataset_update.associatedPublications = associate_publications_struct;
end
% round up the bytes to the nearest kilobyte
dataset_update.totalSize = round(size);
% dataset_update.brainRegions = brainRegions;
[status,dataset] = ndi.cloud.datasets.post_datasetId(dataset_id,dataset_update,auth_token);
end

