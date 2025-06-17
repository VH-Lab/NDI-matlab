function matchingNames = findMixtureName(mixtureDictionaryPath,mixture)

% Input argument validation
arguments
    mixtureDictionaryPath {mustBeFile}
    mixture {mustBeA(mixture,{'struct','table'})}
end

% Get mixture dictionary
mixtureDictionary = jsondecode(fileread(mixtureDictionaryPath));
mixtureNames = fieldnames(mixtureDictionary);

% Convert to struct if table
if istable(mixture)
    mixture = table2struct(mixture);
end

% Convert to cell array of structs
if isstruct(mixture) && isscalar(mixture)
    mixtureArray = {mixture}; % Wrap single struct in a cell for uniform iteration
else
    mixtureArray = num2cell(mixture); % Convert struct array to cell array of structs
end

dictionaryMatch = false(size(mixtureNames));
for i = 1:numel(mixtureNames)
    currentFieldName = mixtureNames{i};
    currentDictEntryStruct = mixtureDictionary.(currentFieldName);

    % Convert to cell array of structs
    if isstruct(currentDictEntryStruct) && isscalar(currentDictEntryStruct)
        currentDictEntryArray = {currentDictEntryStruct}; % Wrap single struct in a cell for uniform iteration
    else
        currentDictEntryArray = num2cell(currentDictEntryStruct); % Convert struct array to cell array of structs
    end

    % Iterate through each element of the dictionary entry array
    entryMatch = false(size(currentDictEntryArray));
    for j = 1:numel(currentDictEntryArray)
        currentDictEntry = currentDictEntryArray{j};

        % Iterate through each element of the mixture array
        mixtureMatch = false(size(currentDictEntryArray));
        for k = 1:numel(mixtureArray)
            currentMixtureElement = mixtureArray{k};

            % Compare fields
            ontologyNameMatch = strcmp(currentDictEntry.ontologyName, currentMixtureElement.ontologyName);
            nameMatch = strcmp(currentDictEntry.name, currentMixtureElement.name);
            valueMatch = eq(currentDictEntry.value, currentMixtureElement.value);
            ontologyUnitMatch = strcmp(currentDictEntry.ontologyUnit, currentMixtureElement.ontologyUnit);
            unitNameMatch = strcmp(currentDictEntry.unitName, currentMixtureElement.unitName);

            mixtureMatch(k) = ontologyNameMatch && nameMatch && valueMatch && ontologyUnitMatch && unitNameMatch;
        end
        entryMatch(j) = any(mixtureMatch);
    end
    dictionaryMatch(i) = all(entryMatch);
end

matchingNames = mixtureNames(dictionaryMatch);
end