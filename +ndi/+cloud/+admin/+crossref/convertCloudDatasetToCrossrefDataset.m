function crossrefDataset = convertCloudDatasetToCrossrefDataset(cloudDataset)

% Todos (crossref best practice recommendations):
% - include all relevant
%   [ish] funding
%   [v] license
%   [ ] relationship metadata
% - include all contributors
%   [v] names
%   [v] ORCID
% - include relevant dates (supported date types are creation, publication, and update dates)
% - provide
%   [v] description
%   [ ] format
%   [ ] citation metadata

    arguments
        cloudDataset (1,:) struct
    end

    if isempty(cloudDataset)
        crossrefDataset = crossref.model.Dataset.empty; return
    end

    % Create titles object
    title = crossref.model.Titles(...
        'Title', cloudDataset.name ...
    );

    contributors = ndi.cloud.admin.crossref.conversion.convertContributors(cloudDataset);
    datasetDate = ndi.cloud.admin.crossref.conversion.convertDatasetDate(cloudDataset);
    aiProgram = ndi.cloud.admin.crossref.conversion.convertLicense(cloudDataset);
    fundingProgram = ndi.cloud.admin.crossref.conversion.convertFunding(cloudDataset);
    % relatedPublications = ndi.cloud.admin.crossref.conversion.convertRelatedPublications(cloudDataset);

    % Ensure no DOI is present on the dataset already. Todo: If a DOI is
    % present, the metadata record for that DOI should be updated.
    assert(~isfield(cloudDataset, 'doi') || isempty(cloudDataset.doi), ...
        'Expected dataset to have no DOI from before.')

    % Create doi_data object
    doiStr = ndi.cloud.admin.createNewDOI();
    datasetURL = ndi.cloud.admin.crossref.Constants.NDIDatasetBaseURL + cloudDataset.x_id;
    doiData = crossref.model.DoiData(...
        'Doi', doiStr, ...
        'Resource', datasetURL ...
    );
    
    % Create dataset object
    crossrefDataset = crossref.model.Dataset(...
        'Contributors', contributors, ...
        'Titles', title, ...
        'Description', cloudDataset.abstract, ...
        'DoiData', doiData, ...
        'DatasetType', crossref.enum.DatasetType.record, ...
        'DatabaseDate', datasetDate, ...
        'AiProgram', aiProgram, ...
        'FrProgram', fundingProgram ...
    );
end
