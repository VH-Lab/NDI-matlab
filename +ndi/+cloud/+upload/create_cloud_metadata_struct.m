function [status, response,dataset_id] = create_cloud_metadata_struct(S)
    % CREATE_CLOUD_METADATA_STRUCT - upload metadata to the NDI Cloud
    %
    % [STATUS, DATASET] = ndi.cloud.upload.CREATE_CLOUD_METADATA_STRUCT(S)
    %
    % Applies the MetaDataEditorApp data structure to
    %   a) create a new dataset
    %   b) add metadata for the dataset to the cloud API
    %
    % Note: This function does not create any ndi.document representations
    % of the metadata, but only edits the metadata in the cloud API.
    %
    % Inputs:
    %   S - a struct with the metadata to create
    %
    % Outputs:
    %   STATUS - did the upload work? 0 for no, 1 for yes
    %   RESPONSE - The post request summary
    %   DATASET_ID - The created dataset id
    %

    clear dataset_update;

    % is_valid = ndi.cloud.fun.check_metadata_cloud_inputs(S);
    % if ~is_valid
    %     error('NDI:CLOUD:CREATE_CLOUD_METADATA_STRUCT', 'S is missing required fields');
    % end
    if isfield(S, 'DatasetFullName')
        dataset_update.name = S.DatasetFullName;
    end

    dataset_update.name = S.DatasetFullName;
    dataset_update.branchName = S.DatasetShortName;
    author_struct = struct();
    for i = 1:numel(S.Author)
        author_struct(i).firstName = S.Author(i).givenName;
        author_struct(i).lastName = S.Author(i).familyName;
        author_struct(i).orchid = S.Author(i).digitalIdentifier.identifier;
    end
    if isfield(S, 'Description')
        dataset_update.abstract = S.Description{1};
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
        if ~isempty(indices)
            dataset_update.correspondingAuthors = dataset_update.contributors(indices);
        end
    end

    dataset_update.doi = "https://doi.org://10.1000/123456789";
    if isfield(S, 'Funding')
        uniqueFunders = unique({S.Funding.funder});
        dataset_update.funding.source = strjoin(uniqueFunders, ', ');
    end

    % license = openminds.internal.getControlledInstance( S.License, 'License', 'core');
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
    % dataset_update.brainRegions = brainRegions;
    % dataset_update.totalSize = round(size);
    [response, dataset_id] = ndi.cloud.api.datasets.create_dataset(dataset_update);
    status = 0; % If previous statement did not fail, status is 0
end
