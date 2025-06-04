function [b, errorStruct] = isAlphaNumericStruct(S_in)
%ISALPHANUMERICSTRUCT Checks if a structure (and any substructures/struct arrays)
%only contain numbers, character arrays, or other structures/struct arrays as fields.
%
%   [b, errorStruct] = ndi.util.isAlphaNumericStruct(S_IN)
%
%   Inputs:
%       S_IN (1,1 struct): The input structure to validate.
%
%   Outputs:
%       b (logical): True if S_IN (and all its nested structures/struct arrays)
%                    contains only numeric, character array, or struct/struct
%                    array fields. False otherwise.
%       errorStruct (struct array): An array of structures, where each element
%                                   indicates a field that did not meet the
%                                   criteria. Each error structure has fields:
%                                   'name' (char): The full path to the
%                                                  offending field (e.g.,
%                                                  'parent.child.fieldName' or
%                                                  'parent.structArray(1).field').
%                                   'msg' (char): A message describing the
%                                                 error (e.g., 'type cell').
%                                   This is empty if b is true.
%
%   Description:
%       The function recursively traverses the input structure S_IN.
%       For each field, it checks if the value is numeric (ISNUMERIC),
%       a character array (ISCHAR), or another structure/struct array (ISSTRUCT).
%       If a field contains a structure or a struct array, the function
%       recurses into each element of that structure/struct array.
%       If any field contains a value of a different type (e.g.,
%       cell array, table, function handle, other objects), the validation
%       fails. Empty structs or empty struct arrays are considered valid.
%
%   Example:
%       a = struct();
%       a.level1_num = 10;
%       a.level1_char = 'hello';
%       a.level1_nest = struct('level2_num', 20, 'level2_char', 'world');
%       a.level1_struct_array(1).item = 'item1';
%       a.level1_struct_array(2).item = 2;
%       [isValid, errors] = ndi.util.isAlphaNumericStruct(a);
%       % isValid will be true, errors will be an empty struct array.
%
%       b_err = struct();
%       b_err.goodNum = 1;
%       b_err.goodStruct = struct('x',1);
%       b_err.badCell = {1, 2};
%       b_err.nested = struct('goodChar', 'ok', 'badTable', table(1));
%       b_err.structArrayWithProblem(1).good = 1;
%       b_err.structArrayWithProblem(2).bad = { 'cell in struct array' };
%       [isValid, errors] = ndi.util.isAlphaNumericStruct(b_err);
%       % isValid will be false.
%       % errors will be a struct array, for example:
%       %   errors(1).name = 'badCell'
%       %   errors(1).msg  = 'type cell'
%       %   errors(2).name = 'nested.badTable'
%       %   errors(2).msg  = 'type table'
%       %   errors(3).name = 'structArrayWithProblem(2).bad'
%       %   errors(3).msg  = 'type cell'

    arguments
        S_in (1,1) struct % Input must be a scalar structure at the top level
    end

    % Initialize outputs
    overallValidity = true;
    % Initialize as a 0x1 struct array with the specified fields
    errorAccumulator = struct('name', cell(0,1), 'msg', cell(0,1));

    % Start the recursive check
    [overallValidity, errorAccumulator] = checkFieldsRecursive(S_in, '', overallValidity, errorAccumulator);

    % Assign to output arguments
    b = overallValidity;
    errorStruct = errorAccumulator;

end

% --- Local Recursive Helper Function ---
function [isStillValid, currentErrors] = checkFieldsRecursive(currentStructOrArray, pathPrefix, validitySoFar, errorsSoFar)
%CHECKFIELDSRECURSIVE Helper function to recursively check structure fields.
%
%   Inputs:
%       currentStructOrArray (struct): The current structure or struct array being checked.
%       pathPrefix (char): The prefix for field names, representing the path
%                          from the root structure (e.g., 'parent.child.' or 'parent.array(1).').
%       validitySoFar (logical): The overall validity status from previous checks.
%       errorsSoFar (struct array): Accumulated errors from previous checks.
%
%   Outputs:
%       isStillValid (logical): Updated validity status after checking currentStructOrArray.
%       currentErrors (struct array): Updated accumulated errors.

    isStillValid = validitySoFar;
    currentErrors = errorsSoFar;

    % Iterate through each element if currentStructOrArray is an array of structs
    for k = 1:numel(currentStructOrArray)
        elementStruct = currentStructOrArray(k);
        elementPathPrefix = pathPrefix;

        % If we are iterating over an array of structs, and the pathPrefix
        % itself is not empty (meaning it's not the top-level call for an array),
        % append the index to the path.
        % The initial call to checkFieldsRecursive passes S_in (scalar) and '' pathPrefix.
        % If S_in.someField is a struct array, say SA, then when SA is passed to
        % checkFieldsRecursive, its pathPrefix will be 'someField'.
        % Then, for SA(1), the elementPathPrefix should become 'someField(1)'.
        % If pathPrefix is already 'someField(idx)', we don't want to double-index.
        % This logic is now handled by how fullFieldName is constructed before this
        % recursive call when a struct field is encountered. The pathPrefix passed
        % to this function for a struct array element already includes its index.

        fieldNames = fieldnames(elementStruct);

        if isempty(fieldNames) && isstruct(elementStruct)
            % An empty struct (e.g., struct()) is considered valid.
            continue; % Move to the next element in currentStructOrArray if any
        end

        for i = 1:numel(fieldNames)
            fieldName = fieldNames{i};
            fieldValue = elementStruct.(fieldName);

            % Construct the full path for the current field
            % If pathPrefix already has an index for an array, this just appends the field.
            if isempty(elementPathPrefix)
                fullFieldName = fieldName;
            else
                fullFieldName = [elementPathPrefix '.' fieldName];
            end

            % Check the type of the field value
            if isstruct(fieldValue)
                % If it's a struct (scalar or array), recurse.
                % Build the path for the fieldValue before recursing.
                % If fieldValue is an array, the recursion will handle iterating it.
                % The pathPrefix for the recursive call will be fullFieldName.
                % The recursive call itself will append (index) if fieldValue is an array.
                
                % If fieldValue is an array of structs, we iterate through its elements
                for structIdx = 1:numel(fieldValue)
                    singleStructElement = fieldValue(structIdx);
                    recursivePathPrefix = fullFieldName;
                    if ~isscalar(fieldValue) % If fieldValue is an array, add index to its path
                         recursivePathPrefix = sprintf('%s(%d)', fullFieldName, structIdx);
                    end
                    [isStillValid, currentErrors] = checkFieldsRecursive(singleStructElement, recursivePathPrefix, isStillValid, currentErrors);
                end

            elseif isnumeric(fieldValue) || ischar(fieldValue)
                % Valid types: numeric or character array.
                % Empty numeric ([]) and empty char ('') are also fine.
            else
                % Invalid type found
                isStillValid = false;
                newError.name = fullFieldName;
                newError.msg = sprintf('type %s', class(fieldValue));
                
                if isempty(currentErrors) % First error found
                    currentErrors = newError;
                else
                    currentErrors(end+1) = newError;
                end
            end
        end
    end
end
