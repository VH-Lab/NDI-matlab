function documentList = convertFormDataToDocuments(appUserData, sessionId)

    % Todo:
    %  [ ] RelatedPublications
    %  [ ] Probes
    %  [ ] Link subjects to ndi subjects using dependency_type?
    %  [ ] Any other dependency_type?

    
    arguments
        appUserData (1,1) struct % A struct with form data
        sessionId = ''
    end

    import ndi.database.metadata_app.fun.loadUserInstances
    import ndi.database.metadata_app.fun.loadUserInstanceCatalog

    % Organizations ("references") which are added in the app is saved to 
    % MATLAB's userpath. Load them here.
    organizations = loadUserInstances('affiliation_organization');
    fundingOrganizations = loadUserInstances('funder_organization');

    strainCatalog = loadUserInstanceCatalog('Strain');

    % Todo: Adapt conversion to also convert custom species.
    strainInstanceMap = convertStrains(strainCatalog.getAll() );

    organizations = [organizations, fundingOrganizations];

    % Make sure we dont have any duplicates
    organizationIds = unique({organizations.digitalIdentifier});
    [~, keep] = unique(organizationIds);
    organizations = organizations(keep);

    % Create organization instances:
    createOrganization = getFactoryFunction('openminds.core.Organization');
    organizationInstances = arrayfun( @(s) createOrganization(s), organizations);
    organizationNames = [organizationInstances.fullName];

    % Create author instances:
    authorStructArray = appUserData.Author;
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

    % Create funding instances
    fundingStructArray = appUserData.Funding;
    createFunding = getFactoryFunction('openminds.core.Funding');
    fundingInstances = arrayfun( @(s) createFunding(s), fundingStructArray);
    
    % Update funder based on the reference funder organizations.
    for i = 1:numel(fundingInstances)
        thisFunding = fundingInstances(i);
        funderName = thisFunding.funder.fullName;
        isMatch = strcmp(funderName, organizationNames);
        thisFunding.funder = organizationInstances(isMatch);
    end

    % Create a dataset version instance:
    dataset = openminds.core.Dataset();
    dataset.fullName = appUserData.DatasetFullName;
    dataset.shortName = appUserData.DatasetShortName;
    dataset.description = appUserData.Description;
    dataset.author = authorInstances;

    % Resolve custodians:
    authorRoles = {authorStructArray.authorRole};
    isCustodian = cellfun(@(c) any(strcmp(c, 'Custodian')), authorRoles);
    dataset.custodian = authorInstances(isCustodian);

    % Resolve otherContributions:
    is1stAuthor = cellfun(@(c) any(strcmp(c, '1st Author')), authorRoles);
    firstAuthor = authorInstances(is1stAuthor);
    if ~iscell(firstAuthor)
        firstAuthor = {firstAuthor};
    end
    firstAuthorDoc = cellfun(@(p) openminds.core.Contribution('contributor', p, 'type', openminds.controlledterms.ContributionType('name', '1st Author')), firstAuthor);

    isCorresponding = cellfun(@(c) any(strcmp(c, 'Corresponding')), authorRoles);
    correspondingAuthor = authorInstances(isCorresponding);
    if ~iscell(correspondingAuthor)
        correspondingAuthor = {correspondingAuthor};
    end
    corresondingAuthorDoc = cellfun(@(p) openminds.core.Contribution('contributor', p, 'type', openminds.controlledterms.ContributionType('name', 'point of contact')), correspondingAuthor);

    datasetVersion = openminds.core.DatasetVersion();
    datasetVersion.fullName = appUserData.DatasetFullName;
    datasetVersion.shortName = appUserData.DatasetShortName;
    datasetVersion.description = appUserData.Description;
    datasetVersion.author = authorInstances;
    datasetVersion.custodian = authorInstances(isCustodian);
    datasetVersion.funding = fundingInstances;
    datasetVersion.otherContribution = [firstAuthorDoc, corresondingAuthorDoc];

    S = openminds.internal.getControlledInstance( appUserData.License, 'License', 'core');
    datasetVersion.license = openminds.core.License().fromStruct(S);

    % Try to create a DOI from the given value. If that fails, the value
    % should be a URL and we create a WebResource instead.
    try 
        doi = openminds.core.DOI('identifier', appUserData.FullDocumentation);
        datasetVersion.fullDocumentation = doi;
    catch
        webResource = openminds.core.WebResource('IRI', appUserData.FullDocumentation);
        datasetVersion.fullDocumentation = webResource;
    end

    datasetVersion.releaseDate = appUserData.ReleaseDate;
    datasetVersion.versionIdentifier = appUserData.VersionIdentifier;
    datasetVersion.versionInnovation = appUserData.VersionInnovation;

    % TODO: Related publication
    datasetVersion.relatedPublication = cellfun(@(value) ...
        openminds.core.DOI('identifier', addDoiPrefix(value)), ...
        {appUserData.RelatedPublication.DOI} );

    datasetVersion.dataType = cellfun(@(value) ...
        openminds.controlledterms.SemanticDataType(value), ...
        appUserData.DataType );

    datasetVersion.experimentalApproach = cellfun(@(value) ...
        openminds.controlledterms.ExperimentalApproach(value), ...
        appUserData.ExperimentalApproach );

    datasetVersion.technique = cellfun(@(value) convertTechnique(value), ...
        appUserData.TechniquesEmployed, 'UniformOutput', false );

    % Create subjects
    subjects = cell(1, numel(appUserData.Subjects));
    for i = 1:numel(subjects)
        subjectItem = appUserData.Subjects(i);
        
        subjects{i} = openminds.core.Subject();
        subjects{i}.biologicalSex = openminds.controlledterms.BiologicalSex(subjectItem.BiologicalSexList{1});
        
        speciesName = strrep(subjectItem.SpeciesList.Name, ' ', '');
        isMatchedInstance = strcmpi (openminds.controlledterms.Species.CONTROLLED_INSTANCES, speciesName);
        if any( isMatchedInstance )
            speciesName = openminds.controlledterms.Species.CONTROLLED_INSTANCES(isMatchedInstance);
            speciesInstance = openminds.controlledterms.Species(speciesName);
        else
            speciesInstance = subjectItem.SpeciesList.convertToOpenMinds();
        end

        if isempty( subjectItem.StrainList )
            subjects{i}.species = speciesInstance;
        else
            strainName = subjectItem.StrainList.Name;
            strainInstance = strainInstanceMap(strainName);
            subjects{i}.species = strainInstance;
        end

        % Add internal identifier and lookup label
        subjectName = subjectItem.SubjectName;
        subjectNameSplit = strsplit(subjectName, '@');
        subjects{i}.internalIdentifier = subjectNameSplit{1};
        subjects{i}.lookupLabel = subjectName;
    end
    datasetVersion.studiedSpecimen = [subjects{:}];

    dataset.hasVersion = datasetVersion;

    % Generate the ndi documents.
    documentList = ndi.database.fun.openMINDSobj2ndi_document(dataset, sessionId);
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
            %warning(ME.message)
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

    conversionMap("openminds.core.Funding") = ...
        struct(...
            'funder', @(value) openminds.core.Organization('fullName', value) ...
        );

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

function instance = convertTechnique(value)

    splitStr = strsplit(value, '(');
    instanceName = strtrim(splitStr{1});
    schemaName = strtrim(splitStr{2});
    schemaName = strrep(schemaName, ')', '');

    fcn = sprintf('openminds.controlledterms.%s', schemaName);
    instance = feval(fcn, instanceName);


end


function [strainInstanceMap] = convertStrains(items)
    
    strainInstanceMap = containers.Map;

    % Convert items without background strains
    for i = 1:numel(items)
        thisItem = items(i);
        thisItem = rmfield(thisItem, 'backgroundStrain');
        thisInstance = openminds.core.Strain().fromStruct(thisItem);
        strainInstanceMap(thisItem.name) = thisInstance;
    end

    % "Recursively" link together background strains
    for i = 1:numel(items)
        thisItem = items(i);
        thisInstance = strainInstanceMap(thisItem.name);
        addBackgroundStrain(thisInstance, thisItem, strainInstanceMap);
        
        for j = 1:numel(thisItem.backgroundStrain)
            bgStrainName = thisItem.backgroundStrain(j);
            bgInstance = strainInstanceMap(bgStrainName);
            thisInstance.backgroundStrain(j) = bgInstance;
        end
    end
end

function modifiedValue = addDoiPrefix(value)
    if ~startsWith(value, 'https://doi.org/')
        modifiedValue = ['https://doi.org/' value];
    else
        modifiedValue = value;
    end
end