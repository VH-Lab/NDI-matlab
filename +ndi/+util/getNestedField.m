function value = getNestedField(S_in, fieldString)
%getNestedField Get a value from a nested field, property, or array element.
%
%   VALUE = getNestedField(S_in, FIELDSTRING)
%
%   Retrieves a value from a nested path within a struct or object S_in.
%   FIELDSTRING is a dot-delimited string that can include array indexing.
%
%   If the path includes an index like '(:)' or 'M:N' that would normally
%   produce multiple values, this function returns a SINGLE CELL ARRAY
%   containing all the results.
%
%   If the full path does not exist, the function will throw an error.
%
%   Examples:
%       s.a(1).b = struct('c', 10);
%       s.a(2).b = struct('c', 20);
%       s.a(3).b = struct('c', 30);
%
%       % --- Get a single value (returns the value itself) ---
%       val = ndi.util.getNestedField(s, 'a(1).b.c'); % val is 10
%
%       % --- Get multiple values (returns a single cell array) ---
%       vals_cell_all = ndi.util.getNestedField(s, 'a(:).b.c');
%       % vals_cell_all is {[10], [20], [30]}
%
%       vals_cell_range = ndi.util.getNestedField(s, 'a(1:2).b.c');
%       % vals_cell_range is {[10], [20]}
%
%       % --- Get complex data types ---
%       struct_val = ndi.util.getNestedField(s, 'a(2).b');
%       % struct_val is struct('c', 20)
%
%       array_val = ndi.util.getNestedField(s, 'a');
%       % array_val is the 1x3 struct array s.a
%
%       % --- Error Handling ---
%       try
%           ndi.util.getNestedField(s, 'a(4).b.c');
%       catch e
%           disp(e.message); % Displays "The path "a(4).b.c" does not exist..."
%       end

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
            value = subsref(S_in, subs);
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

            % Pre-allocate the output cell array
            value = cell(1, numel(loop_indices));
            
            % Loop through each specified element of the base_array
            for i = 1:numel(loop_indices)
                current_index = loop_indices(i);
                % Access one element at a time
                element = base_array(current_index);
                % Apply the rest of the path to that single element
                value{i} = subsref(element, post_subs);
            end
        end
        
    catch ME
        % If the error is TooManyOutputs (from the simple case), wrap it.
        if strcmp(ME.identifier, 'MATLAB:TooManyOutputs')
             newME = MException('getNestedField:tooManyOutputs', ...
                'The path "%s" returned multiple values. Use the (:) or M:N syntax to capture them in a cell array.', fieldString);
             newME = newME.addCause(ME);
             throw(newME);
        end
        newME = MException('getNestedField:pathNotFound', ...
            'The path "%s" does not exist or is invalid.', fieldString);
        newME = newME.addCause(ME);
        throw(newME);
    end
end