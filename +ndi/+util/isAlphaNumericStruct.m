% isAlphaNumericStruct.m (in +ndi/+util/)
function [b, errorStruct] = isAlphaNumericStruct(S_in)
%ISALPHANUMERICSTRUCT Checks if a structure array (and any substructures)
%only contain numbers, character arrays, or other structures as fields.
% ... (documentation from before) ...

    arguments
        S_in struct % Allow any size struct array
    end

    % Initialize outputs
    overallValidity = true;
    errorAccumulator = struct('name', cell(0,1), 'msg', cell(0,1));

    if isempty(S_in)
        b = true;
        errorStruct = errorAccumulator;
        return;
    end

    % Loop through each element of the input struct array S_in
    for i = 1:numel(S_in)
        current_struct_element = S_in(i);
        
        % Determine the path prefix for logging errors
        if isscalar(S_in)
            pathPrefix = '';
        else
            if isvector(S_in)
                % Use linear index for vectors
                pathPrefix = sprintf('(%d)', i);
            else
                % Use ind2sub for multi-dimensional arrays
                siz = size(S_in);
                sub_indices = cell(1, numel(siz));
                [sub_indices{:}] = ind2sub(siz, i);
                pathPrefix = sprintf('(%s)', strjoin(cellfun(@num2str, sub_indices, 'UniformOutput', false), ','));
            end
        end
        
        % Call the recursive helper on the current scalar struct element
        [overallValidity, errorAccumulator] = checkFieldsRecursive(current_struct_element, pathPrefix, overallValidity, errorAccumulator);
    end

    b = overallValidity;
    errorStruct = errorAccumulator;

end

% --- Local Recursive Helper Function ---
function [isStillValid, currentErrors] = checkFieldsRecursive(currentStruct, pathPrefix, validitySoFar, errorsSoFar)
%CHECKFIELDSRECURSIVE Helper function to recursively check fields of a SCALAR struct.

    isStillValid = validitySoFar;
    currentErrors = errorsSoFar;
    
    fieldNames = fieldnames(currentStruct);

    if isempty(fieldNames) && isstruct(currentStruct)
        return;
    end

    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        fieldValue = currentStruct.(fieldName);

        % Construct the full path for the current field
        if isempty(pathPrefix)
             fullFieldName = fieldName;
        else
             if endsWith(pathPrefix, ')')
                fullFieldName = [pathPrefix '.' fieldName];
             else
                fullFieldName = [pathPrefix '.' fieldName];
             end
        end

        % Check the type of the field value
        if isstruct(fieldValue)
            for structIdx = 1:numel(fieldValue)
                singleStructElement = fieldValue(structIdx);
                recursivePathPrefix = fullFieldName;
                if ~isscalar(fieldValue)
                     if isvector(fieldValue)
                         % Use linear index for vectors
                         recursivePathPrefix = sprintf('%s(%d)', fullFieldName, structIdx);
                     else
                         % Use ind2sub for multi-dimensional nested arrays
                         fieldValueSize = size(fieldValue);
                         sub_indices = cell(1, numel(fieldValueSize));
                         [sub_indices{:}] = ind2sub(fieldValueSize, structIdx);
                         recursivePathPrefix = sprintf('%s(%s)', fullFieldName, strjoin(cellfun(@num2str, sub_indices, 'UniformOutput', false), ','));
                     end
                end
                [isStillValid, currentErrors] = checkFieldsRecursive(singleStructElement, recursivePathPrefix, isStillValid, currentErrors);
            end

        elseif isnumeric(fieldValue) || ischar(fieldValue) || islogical(fieldValue)
            % Valid types
        else
            % Invalid type found
            isStillValid = false;
            newError.name = fullFieldName;
            newError.msg = sprintf('type %s', class(fieldValue));
            
            if isempty(currentErrors)
                currentErrors = newError;
            else
                currentErrors(end+1) = newError;
            end
        end
    end
end