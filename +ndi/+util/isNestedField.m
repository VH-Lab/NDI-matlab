function tf = isNestedField(S_in, fieldString)
%isNestedField Check if a nested field, property, or array element exists.
%
%   TF = isNestedField(S_in, FIELDSTRING)
%
%   Checks for the existence of a nested path within a struct or object S_in.
%   This is a powerful alternative to chained calls of isfield/isprop that
%   supports array indexing and avoids "Index exceeds the number of array
%   elements" errors by simply returning false.
%
%   FIELDSTRING is a dot-delimited string that can include array indexing,
%   e.g., 'field1(2).subfield'.
%
%   Returns true (1) if the full path is valid and accessible, and false (0)
%   otherwise. This function does not error for invalid paths or syntax.
%
%   Examples:
%       s.a(1).b = struct('c', 10);
%       s.a(2).b = struct('c', 20);
%       s.a(3).b = struct('c', 30);
%
%       % --- Basic True/False Cases ---
%       isNestedField(s, 'a(1).b.c')       % returns true
%       isNestedField(s, 'a(1).b.d')       % returns false (field 'd' does not exist)
%       isNestedField(s, 'a(4).b.c')       % returns false (index 4 is out of bounds)
%       isNestedField(s, 'x.y.z')          % returns false (field 'x' does not exist)
%
%       % --- Using Colon Operators ---
%       % For paths with '(:)' or 'M:N', it returns true only if the rest of
%       % the path is valid for ALL elements in the specified range.
%       isNestedField(s, 'a(:).b.c')       % returns true (all elements have .b.c)
%       isNestedField(s, 'a(1:2).b.c')     % returns true
%
%       s.a(2).b = rmfield(s.a(2).b, 'c'); % Remove field from one element
%       isNestedField(s, 'a(:).b.c')       % returns false (element 2 is missing .b.c)
%
%       % --- Syntax and Input Validation ---
%       % The function robustly handles syntax errors, returning false.
%       isNestedField(s, 'a(1))')          % returns false (unbalanced parenthesis)
%       isNestedField(s, 'a..b')           % returns false (invalid field string)
%       isNestedField(5, 'a')              % returns false (input is not a struct/object)

    arguments
        S_in
        fieldString {mustBeTextScalar, mustBeNonempty}
    end
    try
        subs = ndi.util.private.stringToSubstruct(fieldString);

        % Find the first indexing operation that will produce multiple outputs.
        is_multi_index = @(s) strcmp(s.type, '()') && ...
            ( (ischar(s.subs{1}) && strcmp(s.subs{1}, ':')) || ...
              (isnumeric(s.subs{1}) && numel(s.subs{1}) > 1) );
        multi_op_idx = find(arrayfun(is_multi_index, subs), 1);
        
        if isempty(multi_op_idx) || multi_op_idx == numel(subs)
            % CASE 1: No multi-output operator, OR it's the last operation.
            subsref(S_in, subs);
        else
            % CASE 2: A multi-output operator is followed by more indexing.
            % We must manually loop to avoid the "intermediate CSL" error.
            
            % Get the array/object *before* the multi-op index is applied
            pre_subs = subs(1:multi_op_idx-1);
            base_array = subsref(S_in, pre_subs);

            % The rest of the path that needs to be applied to each element
            post_subs = subs(multi_op_idx+1:end);
            
            % Determine the numerical indices we need to loop over
            index_values = subs(multi_op_idx).subs{1};
            if ischar(index_values) && strcmp(index_values, ':')
                loop_indices = 1:numel(base_array);
            else
                loop_indices = index_values;
            end

            % Loop through each specified element of the base_array
            for i = loop_indices
                element = base_array(i);
                % Verify the rest of the path for this single element
                subsref(element, post_subs);
            end
        end
        
        tf = true;
    catch
        % Any error means the path is not fully valid.
        tf = false;
    end
end