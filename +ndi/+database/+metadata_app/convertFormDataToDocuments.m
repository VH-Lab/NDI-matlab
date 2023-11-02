function documentList = convertFormDataToDocuments(formDataStruct)

    % Todo:
    %  [ ] Should values be arrays?

    arguments
        formDataStruct (1,1) struct % A struct with form data
    end

    % Organizations ("references") which are added in the app is saved to 
    % MATLAB's userpath. Load them here.
    loadPath = fullfile(userpath, 'NDIDatasetUpload', 'organization_instances.mat');
    if isfile(loadPath)
        S = load(loadPath);
        organizations = S.organizationInstances;
    end

    % Create organization instances:
    createOrganization = getFactoryFunction('openminds.core.Organization');
    organizationInstances = arrayfun( @(s) createOrganization(s), organizations);
    organizationNames = [organizationInstances.fullName];

    % Create author instances:
    authorStructArray = formDataStruct.Author;
    createAuthor = getFactoryFunction('openminds.core.Person');
    authorInstances = arrayfun( @(s) createAuthor(s), authorStructArray);

    % Update affiliations based on the reference organization list. This is
    % done because the organizations in the author's affiliation only
    % contains the fullName of an organizations, while the "reference"
    % organization will also contain the digitalIdentifier
    for i = 1:numel(authorInstances)
        thisAuthor = authorInstances(i);
        for j = 1:numel(thisAuthor.affiliation)
            thisAffiliation = thisAuthor.affiliation(j);
            thisOrganizationName = thisAffiliation.memberOf(1).fullName;
            % This statement does not work because of bug in
            % openminds_MATLAB (fix on the way):
            %thisOrganizationName = thisAuthor.affiliation(j).memberOf(1).fullName;
            isMatch = strcmp(thisOrganizationName, organizationNames);
            thisAuthor.affiliation(j).memberOf = organizationInstances(isMatch);
        end
    end

    % Create a dataset version instance:

    createDatasetVersion = getFactoryFunction('openminds.core.DatasetVersion');

    % Remove this field as it will be handled as special case
    formDataStruct.DatasetVersion = rmfield(formDataStruct.DatasetVersion, 'Author');
    datasetVersion = createDatasetVersion( formDataStruct.DatasetVersion );
    datasetVersion.author = authorInstances;

    % Create a dataset instance:
    createDataset = getFactoryFunction('openminds.core.Dataset');
       
    % Remove author field as it will be handled as special case
    formDataStruct.DatasetVersion = rmfield(formDataStruct.Dataset, 'author');
    formDataStruct.DatasetVersion = rmfield(formDataStruct.Dataset, 'Author');

    dataset = createDataset(formDataStruct.Dataset);
    dataset.author = authorInstances;
    dataset.hasVersion = datasetVersion;

    % Generate the ndi documents.
    documentList = ndi.database.fun.openMINDSobj2ndi_document(dataset);
end


function openMindsInstance = instanceFactory(dataStruct, openMindsType)

    try
        conversionFunctionMap = getConcreteConversionMap(openMindsType);
    catch
        conversionFunctionMap = struct;
    end

    openMindsInstance = feval( openMindsType );
    dataFields = fieldnames(dataStruct);

    for i = 1:numel(dataFields)
        [fieldName, propName] = deal( dataFields{i} );
        propName(1) = lower(propName(1));

        value = dataStruct.(fieldName);
        if isempty(value); continue; end % Skip conversion for empty values

        if isa(value, 'char'); value = string(value); end

        if isfield( conversionFunctionMap, propName )
               
            conversionFcn = conversionFunctionMap.(propName);
            
            if iscell(value)
                value = cellfun(@(s) conversionFcn(s), value);
            
            elseif numel(value) > 1 % array conversion
                value = arrayfun(@(s) conversionFcn(s), value);
            
            else
                value = conversionFcn(value);
            end
        else
            % Insert value directly
        end

        try
            openMindsInstance.(propName) = value;
        catch ME
            warning(ME.message)
        end
    end
end


function selectedConversionMap = getConcreteConversionMap(openMindsType)
% getConversionMap - Get a map with function handles for converting values
    
    persistent conversionMap

    if isempty(conversionMap)
        conversionMap = createConversionMap();
    end

    selectedConversionMap = conversionMap(openMindsType);
end

function conversionMap = createConversionMap()

    conversionMap = dictionary();
 
    conversionMap("openminds.core.Person") = ...
        struct(...
        'contactInformation', getFactoryFunction('openminds.core.ContactInformation'), ...
               'affiliation', getFactoryFunction('openminds.core.Affiliation'), ...
         'digitalIdentifier', @(value) openminds.core.ORCID('identifier', sprintf('https://orcid.org/%s', value.identifier)) ...
        );
        %'contactInformation', @(value) openminds.core.ContactInformation('email', value), ...
        % 'digitalIdentifier', @(value) openminds.core.ORCID('identifier', value) ...
        %'digitalIdentifier', getFactoryFunction('openminds.core.ORCID') ...

    conversionMap("openminds.core.Affiliation") = ...
        struct(...
                  'memberOf', getFactoryFunction('openminds.core.Organization') ...
        );

    conversionMap("openminds.core.Organization") = ...
        struct(...
            'digitalIdentifier', @(value) openminds.core.RORID('identifier', value) ...
        );

    conversionMap("openminds.core.Dataset") = ...
        struct();


    conversionMap("openminds.core.DatasetVersion") = ...
        struct(...
        'dataType', @(value) openminds.controlledterms.SemanticDataType(value), ...
        'experimentalApproach', @(value) openminds.controlledterms.ExperimentalApproach(value), ...
        'technique', @(value) createTechnique(value) );

end

function factoryFcn = getFactoryFunction(openMindsType)
    factoryFcn = @(data) instanceFactory(data, openMindsType);
end

function instance = createTechnique(value)

    splitStr = strsplit(value, '(');
    instanceName = strtrim(splitStr{1});
    schemaName = strtrim(splitStr{2});
    schemaName = strrep(schemaName, ')', '');

    fcn = sprintf('openminds.controlledterms.%s', schemaName);
    instance = feval(fcn, instanceName);


end