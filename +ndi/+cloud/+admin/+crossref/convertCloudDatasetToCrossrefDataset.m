function crossrefDataset = convertCloudDatasetToCrossrefDataset(cloudDataset)

    arguments
        cloudDataset (1,:) struct
    end


    % Todo:  Generate opaque doi suffix
    doiSuffix = matlab.lang.internal.uuid();
    doiStr = ndi.cloud.admin.createDOI(doiSuffix);
    
      % Extract the DOI from the URL format if needed
    doiStr = cloudDataset.doi;
    if startsWith(doiStr, 'https://doi.org://')
        doiStr = extractAfter(doiStr, 'https://doi.org://');
    elseif startsWith(doiStr, 'https://doi.org/')
        doiStr = extractAfter(doiStr, 'https://doi.org/');
    end
    
    % Create person_name objects for contributors
    personNames = [];
    for i = 1:length(cloudDataset.contributors)
        contributor = cloudDataset.contributors(i);
        
        % Determine sequence attribute (first or additional)
        if i == 1
            sequence = crossref.enum.Sequence.first;
        else
            sequence = crossref.enum.Sequence.additional;
        end
        
        % Create person_name object
        personName = crossref.model.PersonName(...
            'GivenName', contributor.firstName, ...
            'Surname', contributor.lastName, ...
            'Sequence', sequence, ...
            'ContributorRole', crossref.enum.ContributorRole.author ...
        );
        
        personNames = [personNames, personName]; %#ok<AGROW>
    end
    
    % Create contributors object
    contributors = crossref.model.Contributors(...
        'Items', num2cell(personNames) ...
    );
    
    % Create titles object
    title = crossref.model.Titles(...
        'Title', cloudDataset.name ...
    );
    
    % Parse dates from ISO format
    try
        createdDate = datetime(cloudDataset.createdAt, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
    catch
        % Fallback to current date if parsing fails
        createdDate = datetime('now');
    end
    
    yearStr = num2str(year(createdDate));
    monthStr = sprintf('%02d', month(createdDate));
    dayStr = sprintf('%02d', day(createdDate));
    
    % Create publication_date object TODO:
    publicationDate = crossref.model.PublicationDate(...
        'Year', yearStr, ...
        'Month', monthStr, ...
        'Day', dayStr, ...
        'MediaType', crossref.enum.MediaType.online ...
    );
    
    % Create doi_data object
    doiData = crossref.model.DoiData(...
        'Doi', doiStr, ...
        'Resource', cloudDataset.doi ... % Todo: URL
    );
    
    % Create dataset object
    crossrefDataset = crossref.model.Dataset(...
        'Contributors', contributors, ...
        'Titles', title, ...
        'Description', cloudDataset.abstract, ...
        'DoiData', doiData, ...
        'DatasetType', crossref.enum.DatasetType.record ...
    );
end
