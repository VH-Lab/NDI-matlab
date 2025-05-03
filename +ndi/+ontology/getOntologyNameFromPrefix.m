function [ontologyName, remainder] = getOntologyNameFromPrefix(ontologyString)
% GETONTOLOGYNAMEFROMPREFIX - Extracts ontology prefix and maps it to an ontology name.
%
%   [ONTOLOGYNAME, REMAINDER] = GETONTOLOGYNAMEFROMPREFIX(ONTOLOGYSTRING)
%
%   Takes a character array or string ONTOLOGYSTRING as input. ONTOLOGYSTRING
%   can be either just an ontology prefix (e.g., 'NCBITaxon') or a full
%   ontology identifier (e.g., 'NCBITaxon:9606'). The input is validated to
%   ensure it is non-empty text and convertible to a character array.
%   Inside the function, ONTOLOGYSTRING is guaranteed to be a char row vector.
%
%   The function determines the prefix part of the string (the part before the
%   first ':') and looks up the corresponding ontology name based on mappings
%   defined in a JSON file. This file is expected at the location:
%   fullfile(ndi.common.PathConstants.CommonFolder,'ontology','ontology_list.json')
%
%   Outputs:
%     ONTOLOGYNAME - The character array representing the name of the ontology
%                    associated with the found prefix.
%     REMAINDER    - The character array representing the portion of the
%                    ONTOLOGYSTRING after the first ':'. Returns empty ('')
%                    if no ':' is present in the ONTOLOGYSTRING.
%
%   Error Conditions:
%     - Throws an error if the input ONTOLOGYSTRING is empty, not text, or not
%       convertible to a char row vector (e.g., a string array).
%     - Throws an error if the input string does not contain a valid prefix
%       (e.g., starts with ':').
%     - Throws an error if the JSON mapping file is not found.
%     - Throws an error if the JSON file cannot be read or parsed correctly.
%     - Throws an error if the JSON file does not contain a valid, non-empty
%       structure array field named 'prefix_ontology_mappings'.
%     - Throws an error if the extracted prefix from ONTOLOGYSTRING is not found
%       within the 'prefix_ontology_mappings' in the JSON file.
%
%   Example:
%     % Example 1: Full identifier (char input)
%     ontologyString1 = 'NCBITaxon:9606';
%     [ontName1, rem1] = getOntologyNameFromPrefix(ontologyString1);
%     % Expected: ontName1 = 'NCBITaxon', rem1 = '9606'
%
%     % Example 2: Prefix only (string input)
%     ontologyString2 = "Uberon"; % Input is string scalar
%     [ontName2, rem2] = getOntologyNameFromPrefix(ontologyString2);
%     % Expected: ontName2 = 'Uberon', rem2 = ''
%
%     % Example 3: Input causing an error due to unknown prefix
%     try
%         ontologyString3 = 'UnknownPrefix:123';
%         [ontName3, rem3] = getOntologyNameFromPrefix(ontologyString3);
%     catch ME
%         disp('Caught expected error:');
%         disp(ME.message);
%     end
%
%   Requires:
%     - MATLAB R2019b or later (for the arguments block validation features used).
%     - The JSON file 'ontology_list.json' located at the specified path,
%       containing the prefix-to-ontology mappings.
%     - The NDI path constants setup, specifically
%       'ndi.common.PathConstants.CommonFolder' must be defined and accessible
%       on the MATLAB path. (If running standalone without NDI, the file path
%       definition within this function must be modified).

arguments
    % Input ontology string, must be convertible to a non-empty char row vector.
    % If a string scalar is passed, it will be converted to char.
    ontologyString (1,:) char {mustBeNonempty}
end
% --- ontologyString is now guaranteed to be a non-empty char row vector ---

% --- Initialize output variables ---
% ontologyName is initialized later, only if found.
remainder = '';
prefix = '';

% --- Extract Prefix and Remainder ---
colonPos = strfind(ontologyString, ':');

if isempty(colonPos)
    % No colon found, the whole string is the prefix
    prefix = strtrim(ontologyString);
    remainder = '';
else
    % Colon found, split the string
    firstColonPos = colonPos(1); % Use only the first colon
    prefix = strtrim(ontologyString(1:firstColonPos-1));
    % Handle case like 'prefix:' -> remainder should be empty, not error
    if firstColonPos == length(ontologyString)
        remainder = '';
    else
        remainder = strtrim(ontologyString(firstColonPos+1:end));
    end
end

% Check if prefix extraction resulted in an empty string (e.g., input was just ':123')
if isempty(prefix)
     error('GETONTOLOGYNAMEFROMPREFIX:InvalidInputFormat', ...
           'Could not extract a valid prefix from the input string: "%s"', ontologyString);
end

% --- Load Ontology Mappings from JSON ---
% Construct the file path (Ensure ndi.common.PathConstants is available)
% If running standalone, replace this line with the actual path:
% jsonFilePath = '/path/to/your/common/folder/ontology/ontology_list.json';
try
    % Assumes ndi.common.PathConstants.CommonFolder is available on the path
    jsonFilePath = fullfile(ndi.common.PathConstants.CommonFolder, 'ontology', 'ontology_list.json');
catch ME
    if strcmp(ME.identifier, 'MATLAB:UndefinedFunction') || contains(ME.message, 'ndi.common.PathConstants')
         error('GETONTOLOGYNAMEFROMPREFIX:NDIPathError', ...
               'NDI path constants (ndi.common.PathConstants.CommonFolder) not found. Please ensure NDI is set up or modify the file path definition within the function.');
    else
        rethrow(ME); % Rethrow other unexpected errors
    end
end

if ~exist(jsonFilePath, 'file')
    error('GETONTOLOGYNAMEFROMPREFIX:FileNotFound', ...
          'Ontology mapping file not found at: %s', jsonFilePath);
end

try
    jsonData = fileread(jsonFilePath);
    ontologyData = jsondecode(jsonData);
catch ME
    error('GETONTOLOGYNAMEFROMPREFIX:JSONError', ...
          'Error reading or decoding JSON file "%s": %s', jsonFilePath, ME.message);
end

% --- Find Ontology Name from Prefix ---
ontologyName = ''; % Initialize as empty before searching

if isfield(ontologyData, 'prefix_ontology_mappings') && isa(ontologyData.prefix_ontology_mappings, 'struct') && ~isempty(ontologyData.prefix_ontology_mappings)
    mappings = ontologyData.prefix_ontology_mappings;

    % Iterate through the mappings array
    for i = 1:numel(mappings)
        % Check if current mapping has the 'prefix' field before comparing
        if isfield(mappings(i), 'prefix') && strcmpi(mappings(i).prefix, prefix)
            if isfield(mappings(i), 'ontology_name') && ~isempty(mappings(i).ontology_name)
                 % Assign and ensure it's char (though input mapping should ideally be char/string)
                ontologyName = char(mappings(i).ontology_name);
            else
                % Prefix found, but ontology_name field is missing or empty
                 warning('GETONTOLOGYNAMEFROMPREFIX:MappingIncomplete', ...
                        'Prefix "%s" found in "%s", but its "ontology_name" is missing or empty. Treating as not found.', ...
                        prefix, jsonFilePath);
                 ontologyName = ''; % Treat as not found if name is empty
            end
            break; % Found the prefix mapping (even if name was empty), exit loop
        end
    end

    % Check if a mapping was actually found *after* the loop
    % (ontologyName would be non-empty only if break occurred AND name was valid)
    if isempty(ontologyName)
         error('GETONTOLOGYNAMEFROMPREFIX:PrefixNotFound', ...
               'Prefix "%s" not found in the ontology mappings file: %s', ...
               prefix, jsonFilePath);
    end

else
    % The required field is missing or not the expected structure/type
    error('GETONTOLOGYNAMEFROMPREFIX:InvalidJSONStructure', ...
          'JSON file "%s" does not contain a valid, non-empty structure array field named "prefix_ontology_mappings".', ...
          jsonFilePath);
end

% Ensure remainder is char (should be already, but belt-and-suspenders)
remainder = char(remainder);

end

