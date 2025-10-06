function T_stacked = vstack(tablesCellArray)
%VSTACK Vertically concatenates tables with dissimilar columns.
%   T_stacked = VSTACK(TABLESCELLARRAY) vertically concatenates a cell
%   array of tables into a single table. This function is designed to handle
%   tables that do not share the same set of variables (columns).
%
%   DESCRIPTION:
%   The function first determines the union of all variable names across all
%   tables. For each table, it then adds any missing columns, filling them
%   with an appropriate typed empty value (e.g., NaN for numeric, <missing>
%   for string/categorical, NaT for datetime). The function correctly
%   handles multi-column variables (e.g., a 10x3 position variable) and is
%   optimized for performance with large numbers of tables.
%
%   INPUTS:
%   tablesCellArray - A 1xN cell array where each element is a MATLAB table.
%
%   OUTPUTS:
%   T_stacked - A single table containing all rows from the input tables,
%               with a complete, unified set of columns.
%
%   EXAMPLES:
%   % Example 1: Basic concatenation of two tables with different columns.
%   T1 = table([1; 2], {'a'; 'b'}, 'VariableNames', {'ID', 'Data'});
%   T2 = table([3; 4], [10.5; 20.6], 'VariableNames', {'ID', 'Value'});
%   T_stacked = vstack({T1, T2})
%   % T_stacked will be a 4x3 table with columns: 'ID', 'Data', 'Value'
%
%   % Example 2: Handling logicals and multi-column variables.
%   T3 = table(true, 'VariableNames', {'LogicVar'});
%   T4 = table([1 1; 2 2], 'VariableNames', {'Position'});
%   T_stacked_2 = vstack({T3, T4})
%   % T_stacked_2 will be a 2x2 table. Note LogicVar is now double.
%
%   SEE ALSO:
%   vertcat, table, join, outerjoin
arguments
    tablesCellArray (1,:) cell {mustBeNonempty}
end
    % --- Initial Setup & Validation ---
    if ~all(cellfun(@(x) isa(x, 'table'), tablesCellArray))
        error('vstack:InvalidCellContent', 'All elements in the cell array must be tables.');
    end
    isNotEmpty = ~cellfun(@(x) isempty(x.Properties.VariableNames) && height(x)==0, tablesCellArray);
    tablesCellArray = tablesCellArray(isNotEmpty);
    if isempty(tablesCellArray)
        T_stacked = table();
        return;
    end
    if isscalar(tablesCellArray)
        T_stacked = tablesCellArray{1};
        return;
    end
    numTables = numel(tablesCellArray);

    % --- Phase 1: Discovery (Best Prototype Selection) ---
    % varInfoMap stores {prototype, numCols}
    varInfoMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    allVarNamesOrdered = {}; % Maintains insertion order of variable names

    for k = 1:numTables
        T = tablesCellArray{k};
        vars = T.Properties.VariableNames;
        for i = 1:numel(vars)
            varName = vars{i};
            
            if ~isKey(varInfoMap, varName) % Processes a variable name upon its first encounter
                allVarNamesOrdered{end+1} = varName; % Adds to ordered list

                % Finds the most informative example column for this variable across all tables.
                % Prioritizes non-empty columns to get the most accurate prototype.
                bestExampleCol = []; 
                bestNumCols = 1;     % Assumes 1 column if no specific size information is found
                declaredTypeForEmpty = ''; % Stores declared type if only empty schemas are found

                foundNonEmpty = false;
                
                for j = 1:numTables % Iterates through all tables to find an optimal example
                    T_candidate = tablesCellArray{j};
                    if ismember(varName, T_candidate.Properties.VariableNames)
                        candidateCol = T_candidate.(varName);
                        
                        if ~isempty(candidateCol) % Uses a non-empty example if available
                            bestExampleCol = candidateCol;
                            bestNumCols = size(candidateCol, 2);
                            foundNonEmpty = true;
                            break; 
                        else % Processes an empty column
                            % Captures the declared type from an empty table's schema for more accurate inference
                            if isempty(declaredTypeForEmpty)
                                declaredTypeForEmpty = class(candidateCol);
                                
                                % Preserves multi-column definition from schema if present
                                if size(candidateCol, 2) > 0
                                    bestNumCols = size(candidateCol, 2);
                                end
                            end
                        end
                    end
                end

                if ~foundNonEmpty % If all instances of this variable across all tables are empty
                    % Creates an empty instance of the declared type if available, otherwise defaults to double.
                    if ~isempty(declaredTypeForEmpty)
                        try
                            if strcmp(declaredTypeForEmpty, 'datetime')
                                bestExampleCol = NaT(0); % Use 0 instead of [] for compatibility with MATLAB <= R2021b
                            elseif strcmp(declaredTypeForEmpty, 'string')
                                bestExampleCol = string([]);
                            elseif strcmp(declaredTypeForEmpty, 'categorical')
                                bestExampleCol = categorical([]);
                            elseif strcmp(declaredTypeForEmpty, 'cell')
                                bestExampleCol = {};
                            else
                                bestExampleCol = feval(declaredTypeForEmpty, []);
                            end
                             % Ensures column count is 1 for 0x0 empty arrays if no other size is implied
                             if isempty(bestExampleCol) && size(bestExampleCol,2) == 0 && bestNumCols == 1
                                % No change needed, bestNumCols is already 1
                             end
                        catch
                            % Defaults to double if creating the declared empty type fails
                            bestExampleCol = double([]);
                            bestNumCols = 1;
                            warning('vstack:UnknownDataType','Data type could not be detected. Filling empty cells with [].')
                        end
                    else
                        % Defaults to double if no declared type is found and all columns are empty
                        bestExampleCol = double([]);
                        bestNumCols = 1;
                    end
                end
                
                % Determines the prototype for filling using the selected example column.
                prototype = get_fill_prototype(bestExampleCol);
                
                % Stores the determined prototype and inferred number of columns.
                varInfoMap(varName) = {prototype, bestNumCols};
            end
        end
    end
    
    if isempty(allVarNamesOrdered)
        T_stacked = table();
        return;
    end
    
    % --- Phase 2: Alignment & Concatenation ---
    processedTables = cell(1, numTables);
    for k = 1:numTables
        T_current = tablesCellArray{k};
        currentHeight = height(T_current);
        
        if currentHeight == 0
            emptyAligned = table();
            for i = 1:numel(allVarNamesOrdered)
                varName = allVarNamesOrdered{i};
                prototypeInfo = varInfoMap(varName);
                prototype = prototypeInfo{1};
                numCols = prototypeInfo{2};
                
                emptyCol = repmat(prototype, 0, numCols);
                
                if iscategorical(prototype)
                    emptyCol(:) = missing; % Explicitly sets missing for categorical fills
                end
                
                emptyAligned.(varName) = emptyCol;
            end
            processedTables{k} = emptyAligned;
            continue;
        end
        
        missingVars = setdiff(allVarNamesOrdered, T_current.Properties.VariableNames, 'stable');
        
        for i = 1:numel(missingVars)
            varName = missingVars{i};
            prototypeInfo = varInfoMap(varName);
            prototype = prototypeInfo{1};
            numCols = prototypeInfo{2};
            
            fillColumn = repmat(prototype, currentHeight, numCols);
            
            if iscategorical(prototype)
                fillColumn(:) = missing;
            end
            
            T_current.(varName) = fillColumn;
        end
        
        processedTables{k} = T_current(:, allVarNamesOrdered);
    end
    T_stacked = vertcat(processedTables{:});
end

% --- Helper function to create a scalar prototype for filling missing data ---
function prototype = get_fill_prototype(exampleCol)
    if islogical(exampleCol)
        prototype = NaN; % Promotes logical to double to allow for NaN fill
    elseif isfloat(exampleCol) % For floating-point types
        prototype = nan('like', exampleCol);
    elseif isinteger(exampleCol) % For integer types
        prototype = NaN; % Promotes integer to double to allow for NaN fill
    elseif isdatetime(exampleCol)
        tz = exampleCol.TimeZone;
        prototype = NaT('TimeZone', tz);
    elseif isduration(exampleCol)
        prototype = duration(NaN,NaN,NaN);
    elseif isstring(exampleCol)
        prototype = missing;
    elseif iscategorical(exampleCol)
        prototype = exampleCol(1:0); % Creates an empty categorical array
        % Preserves categories from the original exampleCol if possible
        if isempty(categories(prototype)) && ~isempty(categories(exampleCol)) 
            prototype = categorical(prototype, categories(exampleCol));
        end
        prototype(1,1) = missing; % Sets its single value to missing
    elseif ischar(exampleCol)
        prototype = ' ';
    elseif iscell(exampleCol)
        % Handles empty cell array inputs to prevent errors
        if ~isempty(exampleCol) 
            prototype = {get_fill_prototype(exampleCol{1})}; % Recursively determines content prototype
        else 
            prototype = {[]}; % Defaults to an empty double array within a cell for empty cell arrays
        end
    else % Custom Objects
        try
            % Attempts to create an empty instance of the object class
            prototype = feval(class(exampleCol));
        catch
            % If object creation fails, falls back to an empty double array
            prototype = []; 
        end
    end
end