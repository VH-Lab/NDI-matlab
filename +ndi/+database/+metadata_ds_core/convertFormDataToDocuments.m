function documentList = convertFormDataToDocuments(appUserData, sessionId)

    % Todo:
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
    [~, keep] = unique({organizations.digitalIdentifier});
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
    if isfield( appUserData, 'Funding' )
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
    else
        fundingInstances = openminds.core.Funding.empty;
    end

    % Create a dataset version instance:
    dataset = openminds.core.Dataset();
    dataset.fullName = appUserData.DatasetFullName;
    dataset.shortName = appUserData.DatasetShortName;
    dataset.description = strjoin(appUserData.Description, newline);
    dataset.author = authorInstances;

    % Resolve custodians:
    authorRoles = {authorStructArray.authorRole};
    isCustodian = cellfun(@(c) any(strcmp(c, 'Custodian')), authorRoles);
    dataset.custodian = authorInstances(isCustodian);

    % Resolve otherContributions:
    is1stAuthor = cellfun(@(c) any(strcmp(c, '1st Author')), authorRoles);
    firstAuthor = authorInstances(is1stAuthor);
    if ~iscell(firstAuthor)
        firstAuthor = mat2cell(firstAuthor,repmat(1,size(firstAuthor,1),1));
    end
    firstAuthorDoc = cellfun(@(p) openminds.core.Contribution('contributor', p, 'type', openminds.controlledterms.ContributionType('name', '1st Author')), firstAuthor);

    isCorresponding = cellfun(@(c) any(strcmp(c, 'Corresponding')), authorRoles);
    correspondingAuthor = authorInstances(isCorresponding);
    if ~iscell(correspondingAuthor)
        correspondingAuthor = mat2cell(correspondingAuthor,repmat(1,size(correspondingAuthor,1),1));
    end
    corresondingAuthorDoc = cellfun(@(p) openminds.core.Contribution('contributor', p, 'type', openminds.controlledterms.ContributionType('name', 'point of contact')), correspondingAuthor);

    datasetVersion = openminds.core.DatasetVersion();
    datasetVersion.fullName = appUserData.DatasetFullName;
    datasetVersion.shortName = appUserData.DatasetShortName;
    datasetVersion.description = strjoin(appUserData.Description, newline);
    datasetVersion.author = authorInstances;
    datasetVersion.custodian = authorInstances(isCustodian);
    datasetVersion.funding = fundingInstances;
    datasetVersion.otherContribution = [firstAuthorDoc(:); corresondingAuthorDoc(:)];

    if isfield( appUserData, 'License')
        if appUserData.License ~= ""
            S = openminds.internal.getControlledInstance( appUserData.License, 'License', 'core');
            datasetVersion.license = openminds.core.License().fromStruct(S);
        end
    end

    % Try to create a DOI from the given value. If that fails, the value
    % should be a URL and we create a WebResource instead.
    if isfield( appUserData, 'FullDocumentation')
        try 
            doi = openminds.core.DOI('identifier', appUserData.FullDocumentation);
            datasetVersion.fullDocumentation = doi;
            catch
            webResource = openminds.core.WebResource('IRI', appUserData.FullDocumentation);
            datasetVersion.fullDocumentation = webResource;
        end
    end

    datasetVersion.releaseDate = appUserData.ReleaseDate;
    datasetVersion.versionIdentifier = appUserData.VersionIdentifier;
    datasetVersion.versionInnovation = appUserData.VersionInnovation;

    % Related publication
    if isfield(appUserData, 'RelatedPublication')
        datasetVersion.relatedPublication = cellfun(@(value) ...
            openminds.core.DOI('identifier', addDoiPrefix(value)), ...
            {appUserData.RelatedPublication.DOI} );
    end
    
    datasetVersion.dataType = cellfun(@(value) ...
        openminds.controlledterms.SemanticDataType(value), ...
        appUserData.DataType );

    datasetVersion.experimentalApproach = cellfun(@(value) ...
        openminds.controlledterms.ExperimentalApproach(value), ...
        appUserData.ExperimentalApproach );

    datasetVersion.technique = cellfun(@(value) convertTechnique(value), ...
        appUserData.TechniquesEmployed, 'UniformOutput', false );

    subjectMap = containers.Map;

    % Create subjects
    subjects = cell(1, numel(appUserData.Subjects));
    for i = 1:numel(subjects)
        subjectItem = appUserData.Subjects(i);
        
        subjects{i} = openminds.core.Subject();
        if ~isempty(subjectItem.BiologicalSexList)
            if ~iscell(subjectItem.BiologicalSexList),
                subjectItem.BiologicalSexList = {subjectItem.BiologicalSexList};
            end;
            subjects{i}.biologicalSex = openminds.controlledterms.BiologicalSex(subjectItem.BiologicalSexList{1});
        end

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
        subjectMap(subjects{i}.lookupLabel) = subjectItem.sessionIdentifier;
    end
    datasetVersion.studiedSpecimen = [subjects{:}];

    dataset.hasVersion = datasetVersion;

    % Generate the ndi documents.
    documentList = ndi.database.fun.openMINDSobj2ndi_document(dataset, sessionId);
    documentList = checkSessionIds(subjectMap, documentList);
end

function documentList = checkSessionIds(subjectMap, documentList)
    dv_f = {};
    studiedSpecimen_id_map = containers.Map;
    studiedSpecimen_id = '';
    for i = 1:numel(documentList)
        if strcmp(documentList{i}.document_properties.openminds.matlab_type, 'openminds.core.products.DatasetVersion')
            dataset_version_doc{1} = documentList{i};
            dv_f = dataset_version_doc{1, 1}.document_properties.openminds.fields;
            break
        end
    end
    if numel(dataset_version_doc) > 0 
        studiedSpecimen_id = dv_f.studiedSpecimen;
    end
    
    for i = 1:numel(studiedSpecimen_id)
        [studiedSpecimen_doc, idx] = ndi.document.find_doc_by_id(studiedSpecimen_id{i},documentList);
        session_id = subjectMap(studiedSpecimen_doc.document_properties.openminds.fields.lookupLabel);
        documentList{idx} = studiedSpecimen_doc.set_session_id(char(session_id));
        doc = studiedSpecimen_doc;
        for j = 1:numel(doc.document_properties.depends_on) 
            if (~isempty(doc.document_properties.depends_on(j).value))
                documentList = changeDependenciesDoc(documentList, session_id, doc.document_properties.depends_on(j).value);
            end
        end
    end
end

function documentList = changeDependenciesDoc(documentList, session_id, doc_id)
    [doc, idx] = ndi.document.find_doc_by_id(doc_id,documentList);
    documentList{idx} = doc.set_session_id(char(session_id));
    if numel(doc.document_properties.depends_on) > 0 
        for i = 1: numel(doc.document_properties.depends_on)
            if (~isempty(doc.document_properties.depends_on(i).value))
                documentList = changeDependenciesDoc(documentList, session_id, doc.document_properties.depends_on(i).value);
            end
        end
    end
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
         'digitalIdentifier', @(value) openminds.core.ORCID('identifier', addOrcidUriPrefix(value.identifier)) ...
        );
        %'contactInformation', @(value) openminds.core.ContactInformation('email', value), ...
        % 'digitalIdentifier', @(value) openminds.core.ORCID('identifier', value) ...
        %'digitalIdentifier', getFactoryFunction('openminds.core.ORCID') ...

    conversionMap("openminds.core.Strain") = ...
        struct( ...
         'digitalIdentifier', @(value) openminds.core.RRID('identifier', value), ...
               'stockNumber', @(value) openminds.core.StockNumber('identifier', value) ...
        );
 
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
        
        createStrain = getFactoryFunction('openminds.core.Strain');
        thisInstance = createStrain(thisItem);

        strainInstanceMap(thisItem.name) = thisInstance;
    end

    % "Recursively" link together background strains
    for i = 1:numel(items)
        thisItem = items(i);
        thisInstance = strainInstanceMap(thisItem.name);
        
        for j = 1:numel(thisItem.backgroundStrain)
            bgStrainName = thisItem.backgroundStrain(j);
            bgInstance = strainInstanceMap(bgStrainName);
            thisInstance.backgroundStrain(j) = bgInstance;
        end
    end
end

function modifiedValue = addDoiPrefix(value)
    if ~startsWith(value, 'https://doi.org/') && value ~= ""
        modifiedValue = ['https://doi.org/' value];
    else
        modifiedValue = value;
    end
end


function modifiedValue = addOrcidUriPrefix(value)
    if ~startsWith(value, 'https://orcid.org/') && value ~= ""
        modifiedValue = ['https://orcid.org/' value];
    else
        modifiedValue = value;
    end
end
