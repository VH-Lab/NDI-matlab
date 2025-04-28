function variableValues = processFileManifest(fileManifest, varStructArray, options)
% Processes a file manifest based on variable extraction rules.
%
% Validates inputs using an arguments block. Allows optional prefix removal.
% Handles 'ind' and 'regex' StringDetectModes.
% The 'regex' mode uses regexp with 'tokens' and expects the desired value
% to be in the first captured group if capturing groups are used in the pattern.
%
% Args:
%   fileManifest (cell vector): A cell array of strings (or char arrays),
%                                where each element is a relative file path
%                                (using '/' as separator). Must be a vector.
%   varStructArray (struct vector): A non-empty structure array derived
%                                   from the JSON configuration. Must be a
%                                   vector and contain the required fields.
%                                   See mustHaveRequiredVarStructFields.
%
% Optional Name-Value Args:
%   relativePathPrefix (char vector): A prefix to remove from the beginning
%                                       of each path in fileManifest before
%                                       processing. Defaults to ''.
%
% Returns:
%   variableValues (struct): A structure with two fields:
%                             - names: A cell array of variable names.
%                             - values: A cell array where each cell corresponds
%                                       to a file path in fileManifest. Each
%                                       of these cells contains another cell
%                                       array holding the extracted values
%                                       for that file path, in the order
%                                       specified by 'names'. Failed extractions
%                                       result in NaN.
%
% Example Usage:
%   varStruct = jsondecode(fileread('config.json')); % Assume config defines regex with capturing group
%   manifest = {'data/raw/exp1/subjA_IV_Curves/s1/t1.dat', 'data/raw/exp1/subjB_Other_IV_Curves/s1/t2.dat'};
%   results = processFileManifest(manifest, varStruct, relativePathPrefix='data/raw/'); % Note: Use char for prefix now: 'data/raw/'

    arguments
        % Positional Arguments
        fileManifest           (:,1) cell {mustBeVector, mustBeText} % Force column vector for consistency
        varStructArray         (1,:) struct {mustBeVector, mustBeNonempty, mustHaveRequiredVarStructFields} % Force row vector

        % Optional Name-Value Arguments
        options.relativePathPrefix (1,:) char = '' % Use char type, default empty. (1,:) allows row vector char array
    end

    numFiles = numel(fileManifest);
    numVars = numel(varStructArray);

    % --- Apply relativePathPrefix if provided (CHAR ARRAY VERSION) ---
    if ~isempty(options.relativePathPrefix) % Check if prefix option was provided
        prefixChar = options.relativePathPrefix; % Already char from args block
        prefixLen = length(prefixChar); % Use length for char array
        processedManifest = cell(size(fileManifest)); % Preallocate output cell array

        for k = 1:numFiles
            originalPath = fileManifest{k}; % Get the original path (likely char)
            % Ensure it's char if the input cell had mixed types (unlikely given validation)
            if ~ischar(originalPath)
               originalPath = char(originalPath) ;
            end
            % Default: keep original path in the output cell
            processedManifest{k} = originalPath;

            originalPathLen = length(originalPath);

            % Check if path is long enough AND starts with the prefix (using char functions)
            if originalPathLen >= prefixLen && strncmp(originalPath, prefixChar, prefixLen)
                % It starts with the prefix
                if originalPathLen > prefixLen
                    % Prefix is shorter than the path, extract the rest using char indexing
                    processedManifest{k} = originalPath(prefixLen+1:end);
                else
                    % Prefix matches the entire path -> Result is empty char array
                    processedManifest{k} = ''; % Assign empty char
                    warning('processFileManifest:PrefixIsFullPath', ...
                            'The prefix "%s" matches the entire path "%s". Resulting path is empty.', ...
                            prefixChar, originalPath);
                end
            % else: Path doesn't start with prefix or is shorter, keep original (default already set)
            end
        end
        currentFileManifest = processedManifest; % Use the processed manifest (now cell array of chars)
    else
        % Use the original manifest if no prefix provided (also cell array of chars likely)
        currentFileManifest = fileManifest;
    end
    % --- End of prefix processing ---


    % Initialize output structure
    variableValues = struct();
    variableValues.names = cell(1, numVars);
    variableValues.values = cell(numFiles, 1); % Cell array to hold results for each file

    % Pre-extract variable names and pre-process 'ind' indices
    preprocessedIndices = cell(1, numVars);
    for k = 1:numVars
        variableValues.names{k} = varStructArray(k).VariableName;
        % Pre-parse indices for 'ind' mode for efficiency
        if strcmpi(varStructArray(k).StringDetectMode, 'ind') && isfield(varStructArray(k),'StringDetectInput') && ~isempty(varStructArray(k).StringDetectInput)
            try
                indices = str2double(strsplit(varStructArray(k).StringDetectInput, ','));
                % Ensure indices are positive integers
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
        else
            % Handle case where StringDetectInput might be missing or empty for 'ind' mode
             if strcmpi(varStructArray(k).StringDetectMode, 'ind')
                 preprocessedIndices{k} = []; % Mark as invalid/empty if input missing for 'ind' mode
             end
        end
    end


    % Process each file path from the potentially modified manifest
    for i = 1:numFiles
        filePath = currentFileManifest{i}; % Use the processed path (char array)
        currentFileValues = cell(1, numVars); % Results for the current file

        % Split path into parts (folders/filename) using '/'
        pathParts = strsplit(filePath, '/');
        numPathParts = numel(pathParts);

         % Handle case where path might be empty after prefix removal or originally
         % strsplit('', '/') gives {''}, numPathParts = 1, pathParts{1} = ''
        if isempty(filePath)
             pathParts = {}; % Ensure pathParts is empty cell if path was empty
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
                        % Assumes SubfolderLevel(1) specifies the 1-based path part index.
                        % Assumes StringDetectInput contains comma-separated 1-based char indices.

                        % Check if SubfolderLevel field exists, is numeric, and has at least one element
                        if ~isfield(varDef,'SubfolderLevel') || isempty(varDef.SubfolderLevel) || ~isnumeric(varDef.SubfolderLevel) || numel(varDef.SubfolderLevel) < 1
                             warning('processFileManifest:InvalidSubfolderLevel', ...
                                     'SubfolderLevel is missing, empty, or invalid for variable "%s". Assigning NaN.', varDef.VariableName);
                             extractedValue = NaN; % SubfolderLevel invalid or empty
                        % Check if the specified level index is within the bounds of actual path parts found
                        elseif varDef.SubfolderLevel(1) < 1 || varDef.SubfolderLevel(1) > numPathParts
                             % This case is expected if path is too short, usually not a warning.
                             extractedValue = NaN; % Level index out of bounds (path too short or empty)
                        % Check if the preprocessed indices for this variable are valid
                        elseif isempty(preprocessedIndices{j})
                             % Warning issued during pre-processing if indices were invalid/empty
                             extractedValue = NaN;
                        else
                           % All checks passed, attempt extraction
                           targetString = pathParts{varDef.SubfolderLevel(1)}; % This is a char array
                           indicesToExtract = preprocessedIndices{j};

                           % Check if character indices are within bounds of the target string
                           if any(indicesToExtract > length(targetString))
                               warning('processFileManifest:IndexOutOfBounds', ...
                                       'Index in "%s" exceeds length of target string "%s" for variable "%s". Assigning NaN.', ...
                                       varDef.StringDetectInput, targetString, varDef.VariableName);
                               extractedValue = NaN; % Character index out of bounds
                           else
                               extractedValue = targetString(indicesToExtract); % Extract characters (result is char array)
                           end
                        end

                    case 'regex'
                        % --- Regex Mode ---
                        % Uses the pattern stored in StringFormat.
                        % Applies to the whole filePath (which is a char array).
                        % Assumes if capturing groups are used, the first token is desired.

                        % Check if StringFormat field exists and is valid text
                        if ~isfield(varDef,'StringFormat') || isempty(varDef.StringFormat) || (~ischar(varDef.StringFormat) && ~isstring(varDef.StringFormat))
                             warning('processFileManifest:InvalidRegexPattern', ...
                                     'StringFormat regex pattern is missing, empty, or invalid for variable "%s". Assigning NaN.', varDef.VariableName);
                             extractedValue = NaN; % No valid pattern provided
                        else
                            pattern = char(varDef.StringFormat); % Ensure pattern is char for regexp

                            % --- Optional: Add debug line here if needed ---
                            % fprintf('DEBUG: Var="%s", FilePath="%s", Pattern="%s"\n', ...
                            %         varDef.VariableName, filePath, pattern);
                            % --- End Optional Debug ---

                            % *** Use 'tokens' instead of 'match' ***
                            tokenResult = regexp(filePath, pattern, 'tokens', 'once','forcecelloutput');

                            if isempty(tokenResult)
                                % No match found is normal, not usually a warning
                                extractedValue = NaN; % No match
                            else
                                % A match was found, tokenResult is NOT empty.
                                try
                                    % Check expected structure: {{token1}} where token1 is not empty char ''
                                    if iscell(tokenResult) && ~isempty(tokenResult) && ...
                                       iscell(tokenResult{1}) && ~isempty(tokenResult{1}) % Checks outer cell is not empty AND inner cell is not empty

                                         extractedValue = tokenResult{1}{1}; % Extract first token's content
                                         % Ensure output is char, not potentially other types from regexp
                                         if ~ischar(extractedValue)
                                             extractedValue = char(extractedValue);
                                         end
                                    else
                                         % --- DETAILED DEBUGGING for Unexpected Format ---
                                         % This block executes if tokenResult has an unexpected structure
                                         fprintf('\n--- DETAILED DEBUG for Variable: %s ---\n', varDef.VariableName);
                                         fprintf('FilePath: "%s"\n', filePath);
                                         fprintf('Pattern: "%s"\n', pattern);
                                         try % Wrap debug checks in try-catch in case tokenResult is weird
                                             fprintf('tokenResult type: %s\n', class(tokenResult));
                                             fprintf('tokenResult size: %s\n', mat2str(size(tokenResult)));
                                             if iscell(tokenResult) && ~isempty(tokenResult)
                                                 fprintf('tokenResult{1} type: %s\n', class(tokenResult{1}));
                                                 fprintf('tokenResult{1} size: %s\n', mat2str(size(tokenResult{1})));
                                                 if iscell(tokenResult{1}) && ~isempty(tokenResult{1})
                                                     fprintf('tokenResult{1}{1} type: %s\n', class(tokenResult{1}{1}));
                                                     fprintf('tokenResult{1}{1} size: %s\n', mat2str(size(tokenResult{1}{1})));
                                                     fprintf('tokenResult{1}{1} isempty?: %d\n', isempty(tokenResult{1}{1}));
                                                 else
                                                    fprintf('tokenResult{1} failed check: iscell()=%d, ~isempty()=%d.\n', iscell(tokenResult{1}), ~isempty(tokenResult{1}));
                                                 end
                                             else
                                                fprintf('tokenResult failed check: iscell()=%d, ~isempty()=%d.\n', iscell(tokenResult), ~isempty(tokenResult));
                                             end
                                             fprintf('Displaying tokenResult directly:\n');
                                             disp(tokenResult);
                                         catch ME_Debug
                                            fprintf('ERROR during detailed debug: %s\n', ME_Debug.message);
                                         end
                                         fprintf('--- END DETAILED DEBUG ---\n');
                                         % --- END DETAILED DEBUGGING ---

                                         warning('processFileManifest:RegexNoTokens', ...
                                                 'Regex matched for variable "%s", but no captured tokens found or format unexpected. Assigning NaN.', varDef.VariableName);
                                         extractedValue = NaN;
                                    end
                                catch ME_Token
                                     warning('processFileManifest:TokenAccessError', ...
                                             'Error accessing regex token for variable "%s": %s. Assigning NaN.', varDef.VariableName, ME_Token.message);
                                     extractedValue = NaN;
                                end
                            end
                        end % End check for valid StringFormat

                    otherwise
                        % --- Unknown Mode ---
                        warning('processFileManifest:UnknownMode', ...
                                'Unknown StringDetectMode "%s" for variable "%s". Assigning NaN.', ...
                                varDef.StringDetectMode, varDef.VariableName);
                        extractedValue = NaN; % Mode not implemented/recognized
                end % end switch
            catch ME
                warning('processFileManifest:ProcessingError', ...
                        'Error processing variable "%s" for file "%s" (original: "%s"): %s. Assigning NaN.', ...
                        varDef.VariableName, filePath, fileManifest{i}, ME.message);
                % Display stack trace for debugging complex errors
                disp(ME.getReport);
                extractedValue = NaN; % Set to NaN on any processing error
            end

            currentFileValues{j} = extractedValue; % Store char array, numeric NaN, or potentially other types later

        end % end loop over variables

        variableValues.values{i} = currentFileValues; % Store results for this file (cell array of mixed types)

    end % end loop over files

end % end function processFileManifest


% --- Custom Validation Function ---
function mustHaveRequiredVarStructFields(s)
% Checks if the input structure array s has the required fields for processFileManifest

    % Check basic type (already done by `struct` in arguments block, but good practice)
    if ~isstruct(s)
        error('Validation:InvalidInput', 'Input must be a structure array.');
    end
    % Check if empty (already done by mustBeNonempty, but good practice)
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

    % Optional: Further checks for field *types* within the struct could be added here
    % e.g., for k=1:numel(s)
    %          if ~ischar(s(k).VariableName) && ~isstring(s(k).VariableName) ... error ... end
    %          if ~isnumeric(s(k).SubfolderLevel) ... error ... end
    %       end
    % However, these type checks are often implicitly handled or better placed
    % within the main processing logic where the fields are used.

end