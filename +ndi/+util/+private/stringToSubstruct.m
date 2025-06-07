function subs = stringToSubstruct(fieldString)
%stringToSubstruct Convert a complex field string to a substruct array.
%
%   Parses a string like 'field1(2).field2' into a substruct array. It performs
%   syntax checking to ensure the string is well-formed.

    if ~ischar(fieldString) && ~isstring(fieldString) || isempty(fieldString)
        error('stringToSubstruct:invalidInput','Input must be a non-empty string or character vector.');
    end
    
    fieldString = convertStringsToChars(strtrim(fieldString));

    if count(fieldString, '(') ~= count(fieldString, ')')
        error('stringToSubstruct:syntaxError', 'Unbalanced parentheses in field string.');
    end

    % --- THE FIX IS HERE ---
    % 'CollapseDelimiters', false is essential to catch 'a..b' style errors.
    parts = strsplit(fieldString, '.', 'CollapseDelimiters', false);
    
    if any(cellfun('isempty', parts))
         error('stringToSubstruct:invalidFieldString', 'Field string cannot contain empty parts (e.g., "a..b" or leading/trailing dots).');
    end

    subs = struct('type',{},'subs',{});
    pattern = '([a-zA-Z_]\w*)\s*\((.*)\)'; % Stricter field name, captures content

    for i = 1:numel(parts)
        part = strtrim(parts{i});
        tok = regexp(part, pattern, 'tokens');
        
        if isempty(tok)
            if ~isvarname(part)
                error('stringToSubstruct:syntaxError', 'Invalid field name "%s".', part);
            end
            subs(end+1) = struct('type', '.', 'subs', part);
        else
            fieldName = tok{1}{1};
            indices_str = tok{1}{2};
            
            reconstructed_part = [fieldName '(' indices_str ')'];
            if ~strcmp(part, reconstructed_part)
                error('stringToSubstruct:syntaxError', 'Invalid syntax in segment "%s".', part);
            end
            
            subs(end+1) = struct('type', '.', 'subs', fieldName);
            
            index_parts = strsplit(indices_str, ',');
            indices_cell = cell(1, numel(index_parts));
            for k = 1:numel(index_parts)
                idx_str = strtrim(index_parts{k});
                if strcmp(idx_str, ':')
                    indices_cell{k} = ':';
                else
                    idx_val = str2num(idx_str); %#ok<ST2NM>
                    if isempty(idx_val)
                        error('stringToSubstruct:invalidIndex', 'Could not parse index "%s".', idx_str);
                    end
                    indices_cell{k} = idx_val;
                end
            end
            subs(end+1) = struct('type', '()', 'subs', {indices_cell});
        end
    end
end
