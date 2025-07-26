function result = create_cloud_metadata_struct(metadata_struct)
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

    arguments
        metadata_struct (1,1) struct {ndi.cloud.utility.mustBeValidMetadata}
    end

    result = struct();

    if isfield(metadata_struct, 'DatasetFullName')
        result.name = metadata_struct.DatasetFullName;
    end
    if isfield(metadata_struct, 'Description')
        result.abstract = metadata_struct.Description{1};
    end

    result.branchName = metadata_struct.DatasetShortName;

    if isfield(metadata_struct, 'Author')
        author_struct = struct();
        for i = 1:numel(metadata_struct.Author)
            author_struct(i).firstName = metadata_struct.Author(i).givenName;
            author_struct(i).lastName = metadata_struct.Author(i).familyName;
            author_struct(i).orchid = metadata_struct.Author(i).digitalIdentifier.identifier;
        end
        result.contributors = author_struct;
        indices = [];
        for i = 1:numel(metadata_struct.Author)
            if strcmp(metadata_struct.Author(i).authorRole, 'Corresponding')
                indices = [indices; i];
            end
        end
        if ~isempty(indices)
            result.correspondingAuthors = result.contributors(indices);
        end
    end

    warning('NDICloud:UploadMetadata:PlaceholderDOI', ...
        'Filling in a placeholder DOI')
    result.doi = "https://doi.org://10.1000/123456789";

    if isfield(metadata_struct, 'Funding')
        uniqueFunders = unique({metadata_struct.Funding.funder});
        result.funding.source = strjoin(uniqueFunders, ', ');
    end

    if isfield(metadata_struct, 'License')
        result.license = metadata_struct.License;
    end
    
    if isfield(metadata_struct, 'Subjects')
        species_str = '';
        all_species = {};
        for i = 1:numel(metadata_struct.Subjects)
            all_species = [all_species, metadata_struct.Subjects(i).SpeciesList.Name];
        end
        all_species = unique(all_species);
        for i = 1:numel(all_species)
            species_str = [species_str, all_species{i}, ', '];
        end
        species_str = species_str(1:end-2);
        result.species = species_str;
        result.numberOfSubjects = numel(metadata_struct.Subjects);
    end

    if isfield(metadata_struct, 'RelatedPublication')
        associate_publications_struct = struct();
        for i = 1:numel(metadata_struct.RelatedPublication)
            associate_publications_struct(i).DOI = metadata_struct.RelatedPublication(i).DOI;
            associate_publications_struct(i).title = metadata_struct.RelatedPublication(i).Publication;
            associate_publications_struct(i).PMID = metadata_struct.RelatedPublication(i).PMID;
            associate_publications_struct(i).PMCID = metadata_struct.RelatedPublication(i).PMCID;
        end
        result.associatedPublications = associate_publications_struct;
    end
end
