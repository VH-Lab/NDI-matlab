function S_out = setNestedField(S_in, fieldString, value, options)
%setNestedField Assign a value to a nested field, property, or array element.
%
%   S_out = setNestedField(S_in, FIELDSTRING, VALUE, ...)
%
%   Assigns VALUE to a path specified by FIELDSTRING, which can include
%   array indexing, e.g., 'field1(2).subfield'. It returns a modified copy.
%
%   Options:
%   'ErrIfDoesNotExist'   (logical, default false) If true, the function will
%                         error if the nested path does not already exist.
%   'SetRange'            (logical, default false) If true, allows assigning
%                         multiple values to a range. VALUE must be a cell
%                         array with the same number of elements as the
%                         indexed range.
%
%   Examples:
%       s.a(1).b = 10; s.a(2).b = 20;
%
%       % --- Assign a single value ---
%       s_new = ndi.util.setNestedField(s, 'a(1).b', 99);
%       % s_new.a(1).b is 99
%
%       % --- Create a new field ---
%       s_new = ndi.util.setNestedField(s, 'a(1).c.d', 'new value');
%       % s_new.a(1).c is now struct('d', 'new value')
%
%       % --- Assign a single value TO a range ---
%       s_new = ndi.util.setNestedField(s, 'a(1:2).b', 99);
%       % s_new.a(1).b is 99, and s_new.a(2).b is 99.
%
%       % --- Distribute a cell array of values across a range ---
%       vals = {'hello', 'world'};
%       s_new = ndi.util.setNestedField(s, 'a(1:2).b', vals, 'SetRange', true);
%       % s_new.a(1).b is 'hello', and s_new.a(2).b is 'world'.
%
%       % --- Use 'ErrIfDoesNotExist' ---
%       try
%           ndi.util.setNestedField(s, 'x.y', 1, 'ErrIfDoesNotExist', true);
%       catch e
%           disp(e.message); % "The field path "x.y" does not exist..."
%       end

    arguments
        S_in
        fieldString {mustBeTextScalar, mustBeNonempty}
        value
        options.ErrIfDoesNotExist (1,1) logical = false;
        options.SetRange (1,1) logical = false;
    end

    if ~isstruct(S_in) && ~isobject(S_in)
        error('setNestedField:invalidInputType', 'First input must be a struct or an object.');
    end
    
    subs = ndi.util.private.stringToSubstruct(fieldString);

    if options.ErrIfDoesNotExist
        if ~ndi.util.isNestedField(S_in, fieldString)
            error('setNestedField:fieldNotFound', ...
                'The field path "%s" does not exist and ''ErrIfDoesNotExist'' is true.', fieldString);
        end
    end
    
    if options.SetRange
        % --- Logic path for distributing multiple values ---
        
        paren_indices = find(strcmp({subs.type}, '()'));
        if isempty(paren_indices)
            error('setNestedField:SetRangeNoIndex', '''SetRange'' is true, but the field string does not contain any array indexing.');
        end
        
        loop_target_idx_in_subs = paren_indices(end);
        
        pre_loop_subs = subs(1:loop_target_idx_in_subs-1);
        post_loop_subs = subs(loop_target_idx_in_subs+1:end);

        base_array = S_in;
        if ~isempty(pre_loop_subs)
             base_array = subsref(S_in, pre_loop_subs);
        end

        index_values = subs(loop_target_idx_in_subs).subs{1};
        if ischar(index_values) && strcmp(index_values, ':')
            loop_indices = 1:numel(base_array);
        else
            loop_indices = index_values;
        end
        
        if ~iscell(value)
            error('setNestedField:SetRangeValueNotCell', '''SetRange'' is true, but the provided value is not a cell array.');
        end
        if numel(value) ~= numel(loop_indices)
            error('setNestedField:SetRangeSizeMismatch', 'The number of values (%d) does not match the number of indexed elements (%d).', numel(value), numel(loop_indices));
        end
        
        S_out = S_in;
        for i = 1:numel(loop_indices)
            current_index = loop_indices(i);
            iter_subs = [pre_loop_subs, struct('type','()','subs',{{current_index}}), post_loop_subs];
            S_out = subsasgn(S_out, iter_subs, value{i});
        end
    else
        % --- Default logic path for assigning a single value ---
        
        is_multi_index = @(s) strcmp(s.type, '()') && ...
            ( (ischar(s.subs{1}) && strcmp(s.subs{1}, ':')) || ...
              (isnumeric(s.subs{1}) && numel(s.subs{1}) > 1) );
        multi_op_idx = find(arrayfun(is_multi_index, subs), 1);
        
        loop_is_needed = ~isempty(multi_op_idx) && multi_op_idx < numel(subs);

        if ~loop_is_needed
            % Simple case: no multi-output index or it's the last operation.
            S_out = subsasgn(S_in, subs, value);
        else
            % Looping needed to assign a SINGLE value to a range
            pre_loop_subs = subs(1:multi_op_idx-1);
            post_loop_subs = subs(multi_op_idx+1:end);
            
            if isempty(pre_loop_subs)
                base_array = S_in;
            else
                base_array = subsref(S_in, pre_loop_subs);
            end

            index_values = subs(multi_op_idx).subs{1};
            if ischar(index_values) && strcmp(index_values, ':')
                loop_indices = 1:numel(base_array);
            else
                loop_indices = index_values;
            end
            
            S_out = S_in;
            for i = 1:numel(loop_indices)
                current_index = loop_indices(i);
                iter_subs = [pre_loop_subs, struct('type','()','subs',{{current_index}}), post_loop_subs];
                S_out = subsasgn(S_out, iter_subs, value);
            end
        end
    end
end