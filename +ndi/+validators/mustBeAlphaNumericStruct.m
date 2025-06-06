% mustBeAlphaNumericStruct.m (in +ndi/+validators/)
function mustBeAlphaNumericStruct(structInstance)
%MUSTBEALPHANUMERICSTRUCT Validates that a structure is an AlphaNumericStruct.
%   MUSTBEALPHANUMERICSTRUCT(STRUCTINSTANCE) checks if STRUCTINSTANCE conforms
%   to the AlphaNumericStruct definition by calling ndi.util.isAlphaNumericStruct.
%   An AlphaNumericStruct contains only numeric, character array, logical,
%   or other AlphaNumericStructs as values (recursively).
%
%   If STRUCTINSTANCE is not an AlphaNumericStruct, an error is thrown.
%
%   Inputs:
%       STRUCTINSTANCE (struct): The structure array to validate. Can be any size.
%
%   Throws:
%       MException with identifier 'ndi:validators:mustBeAlphaNumericStruct:InvalidFormat'
%       if STRUCTINSTANCE does not conform to the AlphaNumericStruct definition.
%
%   See also: ndi.util.isAlphaNumericStruct

arguments
    structInstance struct % Allow struct arrays of any size
end

try
    [isValid, validationErrors] = ndi.util.isAlphaNumericStruct(structInstance);
catch ME
    if strcmp(ME.identifier, 'MATLAB:UndefinedFunction') && contains(ME.message, 'ndi.util.isAlphaNumericStruct')
        error('ndi:validators:mustBeAlphaNumericStruct:UtilityNotFound', ...
              'The utility function ndi.util.isAlphaNumericStruct was not found. Please ensure it is on the MATLAB path.');
    else
        % If isAlphaNumericStruct itself errors for other reasons, rethrow with more context.
        newEx = MException('ndi:validators:mustBeAlphaNumericStruct:UtilityError', ...
            'Error calling ndi.util.isAlphaNumericStruct.');
        newEx = addCause(newEx, ME);
        throw(newEx);
    end
end

if ~isValid
    errMsg = 'Input struct does not conform to the AlphaNumericStruct definition.';
    if ~isempty(validationErrors) && isstruct(validationErrors) && isfield(validationErrors, 'name') && isfield(validationErrors, 'msg')
        firstError = validationErrors(1);
        errMsg = sprintf('%s First offending field: "%s" (%s).', errMsg, firstError.name, firstError.msg);
    end
    error('ndi:validators:mustBeAlphaNumericStruct:InvalidFormat', errMsg);
end

end