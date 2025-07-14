function variableTable = processFileManifest(fileManifest, varStructArray, options)
% Processes a file manifest based on variable extraction rules and returns a table.
%
% VARIABLETABLE = PROCESSFILEMANIFEST(FILEMANIFEST, VARSTRUCTARRAY, ...)
%
% Validates inputs using an arguments block. Allows optional prefix removal.
% Handles 'ind' and 'regex' StringDetectModes.
% The 'regex' mode uses regexp with 'tokens' and expects the desired value
% to be in the first captured group if capturing groups are used in the pattern.
%
% Args:
%   fileManifest (cell vector): A cell array of strings (or char arrays),
%                               where each element is a relative file path
%                               (using '/' as separator). Must be a vector.
%   varStructArray (struct vector): A non-empty structure array derived
%                                   from the JSON configuration. Must be a
%                                   vector and contain the required fields.
%                                   See mustHaveRequiredVarStructFields.
%
% Optional Name-Value Args:
%   relativePathPrefix (char vector): A prefix to remove from the beginning
%                                     of each path in fileManifest before
%                                     processing. Defaults to ''.
%
% Returns:
%   variableTable (table): A table where each row corresponds to a file
%       in fileManifest and each column corresponds to a variable defined
%       in varStructArray. The table's RowNames are the processed file paths
%       (after potential prefix removal). Cell values contain the extracted
%       data (char arrays) or NaN for failed extractions.
%
% Example Usage:
%   varStruct = jsondecode(fileread('config.json')); % Assume config defines regex with capturing group
%   manifest = {'data/raw/exp1/subjA_IV_Curves/s1/t1.dat'; 'data/raw/exp1/subjB_Other_IV_Curves/s1/t2.dat'}; % Use column cell
%   resultsTable = processFileManifest_TableOutput(manifest, varStruct, relativePathPrefix='data/raw/');
%   % Access data like: subjectA_value = resultsTable{'exp1/subjA_IV_Curves/s1/t1.dat', 'SubjectID'};

    arguments
        % Positional Arguments
        fileManifest           (:,1) cell {mustBeVector, mustBeText} % Force column vector for consistency
        varStructArray         (1,:) struct {mustBeVector, mustBeNonempty, mustHaveRequiredVarStructFields} % Force row vector

        % Optional Name-Value Arguments
        options.relativePathPrefix (1,:) char = '' % Use char type, default empty.
    end

    numFiles = numel(fileManifest);
    numVars = numel(varStructArray);

    % --- Apply relativePathPrefix if provided (CHAR ARRAY VERSION) ---
    if ~isempty(options.relativePathPrefix)
        prefixChar = options.relativePathPrefix;
        prefixLen = length(prefixChar);
        processedManifest = cell(size(fileManifest)); % Preallocate output cell array

        for k = 1:numFiles
            originalPath = fileManifest{k};
            if ~ischar(originalPath)
                originalPath = char(originalPath) ;
            end
            processedManifest{k} = originalPath; % Default
            originalPathLen = length(originalPath);

            if originalPathLen >= prefixLen && strncmp(originalPath, prefixChar, prefixLen)
                if originalPathLen > prefixLen
                    processedManifest{k} = originalPath(prefixLen+1:end);
                else
                    processedManifest{k} = '';
                    warning('processFileManifest:PrefixIsFullPath', ...
                            'The prefix "%s" matches the entire path "%s". Resulting path is empty.', ...
                            prefixChar, originalPath);
                end
            end
        end
        currentFileManifest = processedManifest; % Use the processed manifest
    else
        currentFileManifest = fileManifest; % Use the original manifest
    end
    % --- End of prefix processing ---


    % Preallocate cell array to hold all extracted values directly for the table
    tableData = cell(numFiles, numVars);

    % Pre-extract variable names for table columns and pre-process 'ind' indices
    variableNames = cell(1, numVars);
    preprocessedIndices = cell(1, numVars);
    for k = 1:numVars
        variableNames{k} = varStructArray(k).VariableName; % Store name for table header
        % Pre-parse indices for 'ind' mode for efficiency
        if strcmpi(varStructArray(k).StringDetectMode, 'ind') && isfield(varStructArray(k),'StringDetectInput') && ~isempty(varStructArray(k).StringDetectInput)
            try
                indices = str2double(strsplit(varStructArray(k).StringDetectInput, ','));
                if any(isnan(indices)) || any(indices < 1) || any(mod(indices, 1) ~= 0)
                    warning('processFileManifest:InvalidIndices', ...
                            'Invalid indices in StringDetectInput for variable "%s": %s. Treating as empty.', ...
                            varStructArray(k).VariableName, varStructArray(k).StringDetectInput);
                    preprocessedIndices{k} = []; % Mark as invalid
                else
                    preprocessedIndices{k} = indices;
                end
            catch ME
                warning('processFileManifest:IndexParsingError', ...
                        'Error parsing StringDetectInput for variable "%s": %s. Error: %s. Treating as empty.', ...
                        varStructArray(k).VariableName, varStructArray(k).StringDetectInput, ME.message);
                preprocessedIndices{k} = []; % Mark as invalid
            end
        elseif strcmpi(varStructArray(k).StringDetectMode, 'ind')
             preprocessedIndices{k} = []; % Mark as invalid/empty if input missing for 'ind' mode
        end
         % No specific pre-processing needed for 'regex' mode here
    end


    % Process each file path from the potentially modified manifest
    for i = 1:numFiles
        filePath = currentFileManifest{i}; % Use the processed path (char array)

        % Split path into parts (folders/filename) using '/'
        pathParts = strsplit(filePath, '/');
        numPathParts = numel(pathParts);

        % Handle case where path might be empty
        if isempty(filePath)
             pathParts = {};
             numPathParts = 0;
        end

        % Extract each variable for the current file
        for j = 1:numVars
            varDef = varStructArray(j);
            extractedValue = NaN; % Default to NaN for failure

            try
                switch lower(varDef.StringDetectMode)
                    case 'ind'
                        % --- Index Mode ---
                        if ~isfield(varDef,'SubfolderLevel') || isempty(varDef.SubfolderLevel) || ~isnumeric(varDef.SubfolderLevel) || numel(varDef.SubfolderLevel) < 1
                            warning('processFileManifest:InvalidSubfolderLevel', ...
                                    'SubfolderLevel is missing, empty, or invalid for variable "%s". Assigning NaN.', varDef.VariableName);
                            extractedValue = NaN;
                        elseif varDef.SubfolderLevel(1) < 1 || varDef.SubfolderLevel(1) > numPathParts
                            extractedValue = NaN; % Level index out of bounds (normal)
                        elseif isempty(preprocessedIndices{j})
                            extractedValue = NaN; % Invalid indices found earlier
                        else
                           targetString = pathParts{varDef.SubfolderLevel(1)};
                           indicesToExtract = preprocessedIndices{j};
                           if any(indicesToExtract > length(targetString))
                               warning('processFileManifest:IndexOutOfBounds', ...
                                       'Index in "%s" exceeds length of target string "%s" for variable "%s". Assigning NaN.', ...
                                       varDef.StringDetectInput, targetString, varDef.VariableName);
                               extractedValue = NaN;
                           else
                               extractedValue = targetString(indicesToExtract); % Result is char
                           end
                        end

                    case 'regex'
                        % --- Regex Mode ---
                        if ~isfield(varDef,'StringFormat') || isempty(varDef.StringFormat) || (~ischar(varDef.StringFormat) && ~isstring(varDef.StringFormat))
                            warning('processFileManifest:InvalidRegexPattern', ...
                                    'StringFormat regex pattern is missing, empty, or invalid for variable "%s". Assigning NaN.', varDef.VariableName);
                            extractedValue = {NaN};
                        else
                            pattern = char(varDef.StringFormat);
                            tokenResult = regexp(filePath, pattern, 'tokens', 'once', 'forcecelloutput');

                            if isempty(tokenResult)
                                extractedValue = {NaN}; % No match (normal)
                            else
                                try
                                    % Check expected structure: {{token1}} where token1 is not empty char ''
                                    if iscell(tokenResult) && ~isempty(tokenResult) && ...
                                       iscell(tokenResult{1}) && ~isempty(tokenResult{1})

                                        extractedValue = tokenResult{1}; % Extract first token
                                        if ~ischar(extractedValue{1}) % Ensure char output
                                            extractedValue = {char(extractedValue{1})};
                                        end
                                    else
                                         % --- Optional: Keep detailed debugging if needed ---
                                         % fprintf('\n--- DETAILED DEBUG (Table Output) for Variable: %s ---\n', varDef.VariableName);
                                         % ... [rest of debug fprintf statements] ...
                                         % fprintf('--- END DETAILED DEBUG ---\n');
                                         % --- End Optional Debug ---

                                        %warning('processFileManifest:RegexNoTokens', ...
                                        %        'Regex matched for variable "%s", but no captured tokens found or format unexpected. Assigning NaN.', varDef.VariableName);
                                        extractedValue = {NaN};
                                    end
                                catch ME_Token
                                    warning('processFileManifest:TokenAccessError', ...
                                            'Error accessing regex token for variable "%s": %s. Assigning NaN.', varDef.VariableName, ME_Token.message);
                                    extractedValue = {NaN};
                                end
                            end
                        end % End check for valid StringFormat

                    otherwise
                        % --- Unknown Mode ---
                        warning('processFileManifest:UnknownMode', ...
                                'Unknown StringDetectMode "%s" for variable "%s". Assigning NaN.', ...
                                varDef.StringDetectMode, varDef.VariableName);
                        extractedValue = NaN;
                end % end switch
            catch ME
                warning('processFileManifest:ProcessingError', ...
                        'Error processing variable "%s" for file "%s" (original: "%s"): %s. Assigning NaN.', ...
                        varDef.VariableName, filePath, fileManifest{i}, ME.message);
                disp(ME.getReport);
                extractedValue = NaN;
            end

            % Store the extracted value directly into the table data cell array
            tableData{i, j} = extractedValue; % Store char array, numeric NaN

        end % end loop over variables
    end % end loop over files

    % Create the output table
    % Use the processed file manifest for RowNames as they correspond to the paths used in extraction
    variableTable = cell2table(tableData, ...
        'VariableNames', variableNames, ...
        'RowNames', currentFileManifest);

end % end function processFileManifest_TableOutput


% --- Custom Validation Function (Unchanged) ---
function mustHaveRequiredVarStructFields(s)
% Checks if the input structure array s has the required fields for processFileManifest

    if ~isstruct(s)
        error('Validation:InvalidInput', 'Input must be a structure array.');
    end
    if isempty(s)
         error('Validation:InvalidInput', 'Input structure array cannot be empty.');
    end

    requiredFields = {'VariableName', 'SubfolderLevel', 'StringDetectMode', ...
                      'StringDetectInput', 'StringFormat', 'FunctionName'};
    actualFields = fieldnames(s);
    missingFields = setdiff(requiredFields, actualFields);

    if ~isempty(missingFields)
        error('Validation:MissingFields', ...
              'Input structure array is missing required field(s): %s', ...
              strjoin(missingFields, ', '));
    end
end

% --- Helper Validation Functions (Unchanged, Assume they exist elsewhere or add if needed) ---
% function mustBeText(a)
% % Validate that input is char, string, or cell array of char/string
%     if ischar(a) || isstring(a) || iscellstr(a) %#ok<ISCLSTR>
%         return; % Okay
%     elseif iscell(a) % Check if cell array contains only char/string
%         isTextElement = cellfun(@(x) ischar(x) || isstring(x), a);
%         if all(isTextElement)
%             return; % Okay
%         end
%     end
%     error('Validation:InvalidType', 'Input must be text (char, string, or cell array of text).');
% end
%
% function mustBeVector(a)
% % Validate that input is a vector (row or column)
%  if ~isvector(a)
%     error('Validation:NotVector', 'Input must be a vector.');
%  end
% end
%
% function mustBeNonempty(a)
% % Validate that input is not empty
%  if isempty(a)
%      error('Validation:IsEmpty', 'Input cannot be empty.');
%  end
% end


