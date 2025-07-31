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

    % --- Phase 1: Discovery (Single Pass) ---
    varInfoMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % Pre-allocate for performance, preventing array resizing in the loop
    maxPossibleVars = sum(cellfun(@(t) width(t), tablesCellArray));
    allVarNames = cell(1, maxPossibleVars);
    varCount = 0;

    for k = 1:numTables
        T = tablesCellArray{k};
        vars = T.Properties.VariableNames;
        for i = 1:numel(vars)
            varName = vars{i};
            if ~isKey(varInfoMap, varName)
                varCount = varCount + 1;
                allVarNames{varCount} = varName;
                
                exampleCol = T.(varName);
                prototype = get_fill_prototype(exampleCol);
                numCols = size(exampleCol, 2);
                if isempty(exampleCol) && numCols == 0, numCols = 1; end
                varInfoMap(varName) = {prototype, numCols};
            end
        end
    end
    
    allVarNames = allVarNames(1:varCount); % Trim excess pre-allocated cells
    if isempty(allVarNames)
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
            for i = 1:numel(allVarNames)
                varName = allVarNames{i};
                prototypeInfo = varInfoMap(varName);
                prototype = prototypeInfo{1};
                numCols = prototypeInfo{2};
                emptyCol = repmat(prototype, 0, numCols);
                emptyAligned.(varName) = emptyCol;
            end
            processedTables{k} = emptyAligned;
            continue;
        end
        
        missingVars = setdiff(allVarNames, T_current.Properties.VariableNames, 'stable');
        
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
        
        processedTables{k} = T_current(:, allVarNames);
    end

    T_stacked = vertcat(processedTables{:});
end

function prototype = get_fill_prototype(exampleCol)
    % This function creates a scalar prototype for filling missing data
    if islogical(exampleCol)
        prototype = NaN; % Promote logical to double to allow for NaN fill
    elseif isfloat(exampleCol) % For floating-point types
        prototype = nan('like', exampleCol);
    elseif isinteger(exampleCol) % For integer types
        prototype = NaN; % Promote integer to double to allow for NaN fill
    elseif isdatetime(exampleCol)
        tz = exampleCol.TimeZone;
        prototype = NaT('TimeZone', tz);
    elseif isduration(exampleCol)
        prototype = duration(NaN,NaN,NaN);
    elseif isstring(exampleCol)
        prototype = missing;
    elseif iscategorical(exampleCol)
        prototype = exampleCol(1:0);
        prototype(1,1) = missing;
    elseif ischar(exampleCol)
        prototype = ' ';
    elseif iscell(exampleCol)
        prototype = {get_fill_prototype(exampleCol{1})};
    else % Custom Objects
        try
            % Attempt to create an empty instance of the object class
            prototype = feval(class(exampleCol));
        catch
            % If object creation fails, fall back to empty
            prototype = [];
        end
    end
end