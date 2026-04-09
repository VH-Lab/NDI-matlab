function variableTable = parseText(inputText, textParser, options)
    arguments
        inputText {mustBeText}
        textParser {mustBeFile}
        options.Clean (1,1) logical = true
    end

    % Load rules from JSON
    rules = jsondecode(fileread(textParser));
    [numFiles, ~] = size(inputText);
    numVars = numel(rules);
    data = cell(numFiles, numVars);
    varNames = {rules.VariableName};

    for v = 1:numVars
        pattern = rules(v).StringFormat;
        
        % 1. Detect if pattern wants a token (Capturing groups exist)
        % Using (?! \?) ensures we ignore (?i) and (?:...)
        hasToken = ~isempty(regexp(pattern, '\((?!\?)', 'once'));

        for f = 1:numFiles
            % Join all columns in the row (Path + Label) with a space
            rowText = strjoin(cellstr(inputText(f,:)), ' ');

            if hasToken
                res = regexp(rowText, pattern, 'tokens', 'once');
                
                if iscell(res) && ~isempty(res)
                    % Peel nested cells until we find the raw character data
                    temp = res;
                    while iscell(temp) && ~isempty(temp)
                        temp = temp{1};
                    end
                    
                    % 2. SMART NUMERIC CONVERSION
                    % If the result contains digits, treat it as a potential number
                    if any(isstrprop(temp, 'digit'))
                        % Standardize: replace underscore with dot (e.g., '3_5' -> '3.5')
                        cleanStr = replace(string(temp), '_', '.');
                        val = str2double(cleanStr);
                        
                        if ~isnan(val)
                            data{f,v} = val; % Store as Double (3.5)
                        else
                            data{f,v} = temp; % Fallback to String ('1B')
                        end
                    else
                        data{f,v} = temp; % Store as String ('IV')
                    end
                else
                    % If token requested but not found, use NaN or empty string
                    % Base this on whether the pattern looks for digits
                    if contains(pattern, '\d')
                        data{f,v} = NaN; 
                    else
                        data{f,v} = ''; 
                    end
                end
            else
                % Type 2: Logical match (True/False)
                match = regexp(rowText, pattern, 'once');
                data{f,v} = ~isempty(match); 
            end
        end
    end

    % Convert the preallocated cell array to a table
    variableTable = cell2table(data, 'VariableNames', varNames);

    % Final post-processing to flatten the table columns
    for v = 1:width(variableTable)
        colData = variableTable{:,v};
        if iscell(colData)
            % Convert Cell-Logicals to Logical Arrays
            if all(cellfun(@(x) islogical(x) || isempty(x), colData))
                idxEmpty = cellfun(@isempty, colData);
                colData(idxEmpty) = {false};
                variableTable.(varNames{v}) = cell2mat(colData);
                
            % Convert Cell-Numerics to Double Arrays
            elseif all(cellfun(@isnumeric, colData))
                variableTable.(varNames{v}) = cell2mat(colData);
            end
        end
    end

    % Optional Cleaning: Remove columns that are all False, all NaN, or all Empty
    if options.Clean
        isRemovable = false(1, width(variableTable));
        for v = 1:width(variableTable)
            col = variableTable.(varNames{v});
            if islogical(col)
                if ~any(col), isRemovable(v) = true; end
            elseif isnumeric(col)
                if all(isnan(col)), isRemovable(v) = true; end
            else
                % Check cell arrays of strings
                if all(cellfun(@(x) isempty(x) || strcmp(x, ''), col))
                    isRemovable(v) = true;
                end
            end
        end
        variableTable(:, isRemovable) = [];
    end
end