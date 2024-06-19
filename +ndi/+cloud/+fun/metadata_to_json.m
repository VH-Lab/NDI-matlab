function dataset_update = metadata_to_json(S)
%METADATA_TO_JSON - Convert metadata structure to json
% DATASET_UPDATE = ndi.cloud.fun.METADATA_TO_JSON(S)
%
% Inputs:
%   S - the metadata structure to convert
%
% Outputs:
%   DATASET_UPDATE - the json structure to update the dataset

clear dataset_update;

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
        author_struct(i).orcid = S.Author(i).digitalIdentifier.identifier;
        author_struct(i).contact = S.Author(i).contactInformation.email;
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
end

