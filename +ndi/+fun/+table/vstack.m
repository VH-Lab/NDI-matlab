function T_stacked = vstack(tablesCellArray)
%VSTACK Vertically concatenates tables with different variable names.
%   (Help text as before)

arguments
    tablesCellArray (1,:) cell {mustBeNonempty, localMustBeTablesInCell_vstack} % Standardized validator name
end

    if numel(tablesCellArray) == 1
        T_stacked = tablesCellArray{1};
        return;
    end

    allVarNames = {};
    for k_idx = 1:numel(tablesCellArray)
        allVarNames = union(allVarNames, tablesCellArray{k_idx}.Properties.VariableNames, 'stable');
    end

    if isempty(allVarNames) 
        T_stacked = table();
        for k_idx=1:numel(tablesCellArray)
            if height(tablesCellArray{k_idx}) > 0
                T_stacked = tablesCellArray{k_idx}; 
                break;
            end
        end
        return;
    end

    processedTables = cell(size(tablesCellArray));
    for k_idx = 1:numel(tablesCellArray) 
        T_current = tablesCellArray{k_idx};
        currentHeight = height(T_current);
        
        dataForNewTable = cell(1, numel(allVarNames));
        
        for i_var = 1:numel(allVarNames) 
            varName = allVarNames{i_var};
            if ismember(varName, T_current.Properties.VariableNames)
                dataForNewTable{i_var} = T_current.(varName);
            else
                fillData = []; 
                typeInferredAndSet = false;

                for j_typeinf = 1:numel(tablesCellArray) 
                    if ismember(varName, tablesCellArray{j_typeinf}.Properties.VariableNames)
                        exampleCol = tablesCellArray{j_typeinf}.(varName);
                        
                        actualSize = size(exampleCol);
                        numColsInVar = 1; 
                        if numel(actualSize) >= 2 && actualSize(2) > 0
                            numColsInVar = actualSize(2);
                        end
                        if isempty(exampleCol) && all(actualSize == 0)
                             numColsInVar = 1; 
                        elseif numColsInVar == 0 
                            numColsInVar = 1;
                        end
                        
                        h_fill = currentHeight;

                        if islogical(exampleCol)
                            fillData = NaN(h_fill, numColsInVar); typeInferredAndSet = true;
                        elseif isinteger(exampleCol) 
                            fillData = NaN(h_fill, numColsInVar); typeInferredAndSet = true; 
                        elseif isfloat(exampleCol) 
                            fillData = NaN(h_fill, numColsInVar, 'like', exampleCol); typeInferredAndSet = true;
                        elseif isdatetime(exampleCol)
                            tz = ''; 
                            if isprop(exampleCol, 'TimeZone') 
                                colTZ_value = exampleCol.TimeZone;
                                if (ischar(colTZ_value) && (isrow(colTZ_value) || isempty(colTZ_value))) || ...
                                   (isstring(colTZ_value) && isscalar(colTZ_value) && ~ismissing(colTZ_value))
                                    char_colTZ = char(colTZ_value); 
                                    if ~isempty(strtrim(char_colTZ)) 
                                        tz = char_colTZ;
                                    end
                                end
                            end
                            fillData = NaT(h_fill, numColsInVar, 'TimeZone', tz); typeInferredAndSet = true;
                        elseif isduration(exampleCol) 
                            if h_fill == 0
                                fillData = exampleCol(1:0); 
                                fillData = repmat(fillData, 0, numColsInVar); 
                            else
                                scalar_nan_dur = duration(NaN,NaN,NaN); 
                                fillData = repmat(scalar_nan_dur, h_fill, numColsInVar);
                            end
                            typeInferredAndSet = true;
                        elseif isstring(exampleCol)
                            fillData = repmat(missing, h_fill, numColsInVar); 
                            typeInferredAndSet = true;
                        elseif iscategorical(exampleCol)
                            emptyCatWithMetadata = exampleCol(1:0,:); 
                            fillData = repmat(emptyCatWithMetadata, h_fill, numColsInVar);
                            if ~isempty(fillData) || h_fill == 0 
                                fillData(:) = missing; 
                            else 
                                fillData = repmat(categorical(missing), h_fill, numColsInVar);
                            end
                            typeInferredAndSet = true;
                        elseif ischar(exampleCol)
                             if h_fill == 0
                                fillData = char.empty(0, numColsInVar);
                             else
                                fillData = repmat(' ', h_fill, numColsInVar); 
                             end
                             typeInferredAndSet = true;
                        elseif iscell(exampleCol) 
                            fillData = cell(h_fill, numColsInVar); 
                            typeInferredAndSet = true;
                        elseif isobject(exampleCol) 
                            className = class(exampleCol);
                            try
                                if h_fill == 0
                                    try % Standard way to create typed empty array
                                        fillData = feval(className).empty(0, numColsInVar);
                                    catch ME_empty % Fallback if .empty(0,N) isn't supported/simple
                                        % Create a scalar and repmat to 0xN
                                        emptyScalar = feval(className);
                                        fillData = repmat(emptyScalar, 0, numColsInVar);
                                    end
                                    % Ensure correct 0xN dimensions, especially if numColsInVar is 0 from exampleCol
                                    if numColsInVar > 0 && (size(fillData,1) ~= 0 || size(fillData,2) ~= numColsInVar)
                                        baseEmpty = feval(className); % Get scalar instance
                                        fillData = baseEmpty(zeros(0,numColsInVar,'logical')); % Force 0xN using logical indexing
                                    end
                                else % h_fill > 0
                                    fillData = repmat(feval(className), h_fill, numColsInVar);
                                end
                                typeInferredAndSet = true; 
                            catch ME_obj
                                warning('vstack:ObjectFillCreationWarning', ...
                                    'Could not create standard object array fill for column "%s" of type "%s" (Error: %s). Filling with empty cells as fallback. Verify results.', ...
                                    varName, className, ME_obj.message);
                                fillData = cell(h_fill, numColsInVar); 
                                typeInferredAndSet = true; % CRITICAL: Mark as handled (with cells)
                            end
                        elseif isnumeric(exampleCol) % Fallback for any other numeric types
                            try
                                temp_nan_val = NaN(1, 1, 'like', exampleCol);
                                if isnan(temp_nan_val) 
                                    fillData = NaN(h_fill, numColsInVar, 'like', exampleCol);
                                else
                                    fillData = NaN(h_fill, numColsInVar); 
                                end
                            catch
                                fillData = NaN(h_fill, numColsInVar); 
                            end
                            typeInferredAndSet = true;
                        end
                        
                        if typeInferredAndSet
                            break; 
                        end
                    end 
                end 

                if ~typeInferredAndSet 
                    if currentHeight > 0
                        warning('vstack:TypeInferenceFailed', 'VERY UNEXPECTED: Type for variable "%s" (source class %s) was not handled. Defaulting to double NaN.', varName, class(exampleCol));
                        fillData = NaN(currentHeight, 1); 
                    else
                        fillData = double.empty(0,1); 
                    end
                end
                dataForNewTable{i_var} = fillData;
            end
        end
        
        if isempty(allVarNames) && currentHeight > 0 
            processedTables{k_idx} = T_current; 
        elseif isempty(allVarNames) && currentHeight == 0 
            processedTables{k_idx} = table();
        else
            try
                processedTables{k_idx} = table(dataForNewTable{:}, 'VariableNames', allVarNames);
            catch ME_table_construct
                 error('vstack:TableConstructionError', 'Failed to construct intermediate table for input table %d for variable ''%s''. Error: %s', k_idx, varName, ME_table_construct.message);
            end
        end
    end
    
    if isempty(processedTables) 
        T_stacked = table();
        return;
    end

    try
        T_stacked = vertcat(processedTables{:});
    catch ME_vertcat
        newExc = MException('vstack:VertcatFailed', ...
            'Vertcat failed after attempting to align table schemas. Check for incompatible data types in common columns. Original error: %s', ME_vertcat.message);
        if ~isempty(ME_vertcat.cause) && isa(ME_vertcat.cause, 'cell') && ~isempty(ME_vertcat.cause{1})
            newExc = addCause(newExc, ME_vertcat.cause{1}); 
        elseif ~isempty(ME_vertcat.cause) && ~iscell(ME_vertcat.cause) 
             newExc = addCause(newExc, ME_vertcat.cause);
        end
        throw(newExc);
    end
end

% Local validation function, name must match usage in arguments block
function localMustBeTablesInCell_vstack(c) 
    if ~all(cellfun(@(x) isa(x, 'table'), c))
        error('vstack:InvalidCellContent', 'All elements in the cell array must be tables.');
    end
end