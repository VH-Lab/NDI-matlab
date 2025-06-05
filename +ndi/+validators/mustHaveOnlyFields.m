% mustHaveOnlyFields.m (to be placed in +ndi/+validators/)
function mustHaveOnlyFields(structInstance, allowedFieldNames)
%MUSTHAVEONLYFIELDS Validates that a structure only contains fields from a specified list.
%   MUSTHAVEONLYFIELDS(STRUCTINSTANCE, ALLOWEDFIELDNAMES) checks if all field
%   names in STRUCTINSTANCE are present in the cell array ALLOWEDFIELDNAMES.
%   If STRUCTINSTANCE contains any field not in ALLOWEDFIELDNAMES, an error is thrown.
%
%   Inputs:
%       STRUCTINSTANCE (1,1 struct): The structure to validate.
%       ALLOWEDFIELDNAMES (cell array of char/string): A cell array where each
%           element is a character vector or string scalar representing an
%           allowed field name.
%
%   Throws:
%       MException with identifier 'ndi:validators:mustHaveOnlyFields:ExtraFields'
%       if one or more fields in STRUCTINSTANCE are not found in ALLOWEDFIELDNAMES.
%
%   Example:
%       myStruct.name = 'Test';
%       myStruct.value = 10;
%       allowed = {'name', 'value', 'type'};
%       ndi.validators.mustHaveOnlyFields(myStruct, allowed); % Passes
%
%       myStruct.extraField = true;
%       try
%           ndi.validators.mustHaveOnlyFields(myStruct, allowed);
%       catch ME
%           disp(ME.message); % Displays: Input struct contains unexpected field(s) not in the allowed list: "extraField".
%       end

arguments
    structInstance (1,1) struct % Ensure it's a scalar struct
    allowedFieldNames (1,:) cell % Ensure it's a row cell array
end

% Validate contents of allowedFieldNames
if ~isempty(allowedFieldNames)
    isCharOrString = cellfun(@(x) (ischar(x) && isrow(x)) || (isstring(x) && isscalar(x)), allowedFieldNames);
    if ~all(isCharOrString)
        error('ndi:validators:mustHaveOnlyFields:InvalidAllowedNamesInput', ...
              'ALLOWEDFIELDNAMES must be a cell array of character row vectors or scalar strings.');
    end
end
% Convert allowedFieldNames to char cell array for setdiff if they might be strings
allowedFieldNamesChar = cellfun(@char, allowedFieldNames, 'UniformOutput', false);

actualFieldNames = fieldnames(structInstance);

% Use setdiff to find fields in actualFieldNames that are not in allowedFieldNamesChar
extraFields = setdiff(actualFieldNames, allowedFieldNamesChar);

if ~isempty(extraFields)
    if numel(extraFields) == 1
        error('ndi:validators:mustHaveOnlyFields:ExtraField', ...
              'Input struct contains an unexpected field not in the allowed list: "%s".', extraFields{1});
    else
        extraFieldsStr = strjoin(cellfun(@(x) ['"', x, '"'], extraFields, 'UniformOutput', false), ', ');
        error('ndi:validators:mustHaveOnlyFields:ExtraFields', ...
              'Input struct contains unexpected field(s) not in the allowed list: %s.', extraFieldsStr);
    end
end

end
