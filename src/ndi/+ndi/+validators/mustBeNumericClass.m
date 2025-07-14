function mustBeNumericClass(className)
%mustBeNumericClass Validates that the input is a valid numeric or logical class name.
%   mustBeNumericClass(className) throws an error if className is not one
%   of the following character vectors or strings:
%   'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32',
%   'int64', 'single', 'double', or 'logical'.

% Ensure the input is a string or char for validation
if ~isstring(className) && ~ischar(className)
    error('validation:InvalidInputType', 'Input to validator must be a string or character vector.');
end

% Define the list of valid numeric and logical class names as a string array
validClasses = ["uint8", "uint16", "uint32", "uint64", ...
                "int8", "int16", "int32", "int64", ...
                "single", "double", "logical"];

% Check if the input class name is a member of the valid list
if ~ismember(className, validClasses)
    % If it's not a valid class, construct and throw an error.
    eid = 'validation:InvalidNumericClass';

    % Create a comma-separated list of the valid classes for the message
    validClassesStr = strjoin(validClasses, ', ');
    msg = sprintf('Value must be a valid numeric or logical class name. \nMust be one of: %s.', validClassesStr);

    error(eid, msg);
end

end
