function matchingNames = findMixtureName(mixtureDictionaryPath,mixture)
% FINDMIXTURENAME Identifies matching mixture names from a dictionary.
%
%   matchingNames = FINDMIXTURENAME(mixtureDictionaryPath, mixture)
%   compares input 'mixture' structure(s) or table against a dictionary
%   of mixtures loaded from a JSON file specified by 'mixtureDictionaryPath'.
%   It returns a cell array of field names from the mixture dictionary
%   that completely match the provided 'mixture' based on specific fields.
%
%   The function assumes both the 'mixture' input and the individual
%   mixture entries within the 'mixtureDictionary' have the following
%   fields for comparison:
%       - 'ontologyName' (string)
%       - 'name' (string)
%       - 'value' (numeric)
%       - 'ontologyUnit' (string)
%       - 'unitName' (string)
%
%   Input Arguments:
%   - mixtureDictionaryPath: A string scalar or character vector specifying the
%     full path to a JSON file containing the mixture dictionary. This file
%     is expected to be a flat structure where each field name represents a
%     mixture name, and its value is either a single struct or a struct array
%     containing the mixture's properties.
%     (e.g., 'path/to/dabrowska_mixtures.json')
%   - mixture: A scalar struct, a struct array, or a table. Each row/element
%     of 'mixture' should contain the fields required for comparison.
%
%   Output Arguments:
%   - matchingNames: A cell array of strings containing the field names from
%     the 'mixtureDictionary' that fully match the provided 'mixture' input.
%     A dictionary entry is considered a match if ALL of its constituent
%     elements (if it's a struct array) can find a corresponding exact match
%     within the 'mixture' input.
%
% See also JSONDECODE, FILEREAD, STRCMPI, EQ, TABLE2STRUCT.

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