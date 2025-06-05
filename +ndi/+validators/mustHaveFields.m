% mustHaveFields.m (to be placed in +ndi/+validators/)
function mustHaveFields(structInstance, requiredFieldNames)
%MUSTHAVEFIELDS Validates that a structure contains all specified fields.
%   MUSTHAVEFIELDS(STRUCTINSTANCE, REQUIREDFIELDNAMES) checks if STRUCTINSTANCE
%   contains all field names listed in the cell array REQUIREDFIELDNAMES.
%   If any field is missing, an error is thrown.
%
%   Inputs:
%       STRUCTINSTANCE (1,1 struct): The structure to validate.
%       REQUIREDFIELDNAMES (cell array of char/string): A cell array where each
%           element is a character vector or string scalar representing a field
%           name that must be present in STRUCTINSTANCE.
%
%   Throws:
%       MException with identifier 'ndi:validators:mustHaveFields:MissingFields'
%       if one or more required fields are not found in STRUCTINSTANCE.
%
%   Example:
%       myStruct.name = 'Test';
%       myStruct.value = 10;
%       required = {'name', 'value', 'type'};
%       try
%           ndi.validators.mustHaveFields(myStruct, required);
%       catch ME
%           disp(ME.message); % Displays: Input struct is missing the following required field(s): "type".
%       end

arguments
    structInstance (1,1) struct % Ensure it's a scalar struct
    requiredFieldNames (1,:) cell % Ensure it's a row cell array
end

% Validate contents of requiredFieldNames
if ~isempty(requiredFieldNames)
    isCharOrString = cellfun(@(x) (ischar(x) && isrow(x)) || (isstring(x) && isscalar(x)), requiredFieldNames);
    if ~all(isCharOrString)
        error('ndi:validators:mustHaveFields:InvalidFieldNamesInput', ...
              'REQUIREDFIELDNAMES must be a cell array of character row vectors or scalar strings.');
    end
end

missingFields = {};
for i = 1:numel(requiredFieldNames)
    fieldName = char(requiredFieldNames{i}); % Convert to char for isfield, handles strings
    if ~isfield(structInstance, fieldName)
        missingFields{end+1} = fieldName; %#ok<AGROW>
    end
end

if ~isempty(missingFields)
    if numel(missingFields) == 1
        error('ndi:validators:mustHaveFields:MissingField', ...
              'Input struct is missing the required field: "%s".', missingFields{1});
    else
        missingFieldsStr = strjoin(cellfun(@(x) ['"', x, '"'], missingFields, 'UniformOutput', false), ', ');
        error('ndi:validators:mustHaveFields:MissingFields', ...
              'Input struct is missing the following required field(s): %s.', missingFieldsStr);
    end
end

end

