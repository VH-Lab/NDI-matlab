function documentList = convertFormDataToDocuments(formDataStruct)
​
    % Todo:
    %  [ ] Should values be arrays?
​
    arguments
        formDataStruct (1,1) struct % A struct with form data
    end
​
    % Create authors:
    authorStructArray = formDataStruct.Author;
    createAuthor = getFactoryFunction('openminds.core.Person');
    authorInstances = arrayfun( @(s) createAuthor(s), authorStructArray);
​
​
    % Create a dataset document:
    createDataset = getFactoryFunction('openminds.core.Dataset');
    dataset = createDataset(struct);
    
    % Create a dataset version document:
    datasetVersion = openminds.core.DatasetVersion();
​
end
​
​
​
function selectedConversionMap = getConcreteConversionMap(openMindsType)
% getConversionMap - Get a map with function handles for converting values
    
    persistent conversionMap
​
    if isempty(conversionMap)
        conversionMap = createConversionMap();
    end
​
    selectedConversionMap = conversionMap(openMindsType);
end
​
function conversionMap = createConversionMap()
​
    conversionMap = dictionary();
 
    conversionMap("openminds.core.Person") = ...
        struct(...
        'contactInformation', @(value) openminds.core.ContactInformation('email', value), ...
               'affiliation', getFactoryFunction('openminds.core.Affiliation'), ...
         'digitalIdentifier', @(value) openminds.core.ORCID('identifier', value) ...
        );
​
    conversionMap("openminds.core.Affiliation") = ...
        struct(...
                  'memberOf', getFactoryFunction('openminds.core.Organization') ...
        );
​
    conversionMap("openminds.core.Organization") = ...
        struct(...
            'digitalIdentifier', @(value) openminds.core.RORID('identifier', value) ...
        );
​
    conversionMap("openminds.core.Dataset") = ...
        struct();
​
end
​
function factoryFcn = getFactoryFunction(openMindsType)
    factoryFcn = @(data) instanceFactory(data, openMindsType);
end