function variableTable = parseText(inputText, textParser, options)
arguments
    inputText {mustBeText}
    textParser {mustBeFile}
    options.Clean (1,1) logical = true
end

rules = jsondecode(fileread(textParser));
[numFiles, ~] = size(inputText);
numVars = numel(rules);
data = cell(numFiles, numVars);
varNames = {rules.VariableName};

for v = 1:numVars
    pattern = rules(v).StringFormat;
    
    % Strict Token Check: Look for ( NOT followed by ?
    % This correctly ignores (?i) and (?:...)
    hasToken = ~isempty(regexp(pattern, '\((?!\?)', 'once'));

    for f = 1:numFiles
        rowText = strjoin(cellstr(inputText(f,:)), ' ');
        
        if hasToken
            res = regexp(rowText, pattern, 'tokens', 'once');
            if iscell(res) && ~isempty(res)
                % "Peel" the nested cells until we find the string
                temp = res;
                while iscell(temp) && ~isempty(temp)
                    temp = temp{1};
                end
                data{f,v} = temp; 
            else
                data{f,v} = ''; 
            end
        else
            % Logical: returns true/false
            match = regexp(rowText, pattern, 'once');
            data{f,v} = ~isempty(match); 
        end
    end
end

variableTable = cell2table(data, 'VariableNames', varNames);

% Convert Cell-Logicals to Logical Arrays
for v = 1:width(variableTable)
    colData = variableTable{:,v};
    if iscell(colData) && all(cellfun(@(x) islogical(x) || isempty(x), colData))
        % Handle potential empty cells in logical columns
        idxEmpty = cellfun(@isempty, colData);
        colData(idxEmpty) = {false};
        variableTable.(varNames{v}) = cell2mat(colData);
    end
end

if options.Clean
    isRemovable = false(1, width(variableTable));
    for v = 1:width(variableTable)
        col = variableTable.(varNames{v});
        if islogical(col)
            if ~any(col), isRemovable(v) = true; end
        else
            if all(cellfun(@(x) isempty(x) || strcmp(x, ''), col))
                isRemovable(v) = true;
            end
        end
    end
    variableTable(:, isRemovable) = [];
end
end