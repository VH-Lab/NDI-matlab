% Folder: +ndi/+setup/+NDIMaker/
classdef sessionMaker < handle % Using handle class for reference behavior (objects are passed by reference)
    % SESSIONMAKER Class to manage session creation setup based on file manifests.
    % Facilitates extracting metadata from file paths and organizing information
    % needed to potentially create NDI session objects.

    properties (Access = public)
        sessions                    % Cell array intended to hold ndi.session.dir objects created later. Initialized empty.
        fileManifest                % Cell array of file paths being examined. Set via setManifest.
        dataLocationVariableRules   % Struct array defining rules for extracting variables from paths using processFileManifest. Must be set externally.
        dataLocationVariables       % Struct containing extracted variable names and values, populated by computeDataLocationVariables.
        DaqSystems                  % Struct array describing DAQ systems. Expected fields: 'daqReader', 'fileNavigator'. Must be set externally.
    end

    methods
        function obj = sessionMaker()
            % SESSIONMAKER Constructor for the sessionMaker class
            % Initializes properties to default empty values suitable for their types.

            obj.sessions = {}; % Initialize as empty cell array, ready to hold session objects
            obj.fileManifest = {}; % Initialize as empty cell array
            obj.dataLocationVariableRules = struct([]); % Initialize as empty struct array
            % Initialize matching the expected output structure of processFileManifest
            obj.dataLocationVariables = struct('names',{{}},'values',{{}});
            % Initialize empty struct array with the specified fields
            obj.DaqSystems = struct('daqReader', {}, 'fileNavigator', {});
        end

        function setManifest(obj, fileManifest, options)
            % SETMANIFEST Sets the file manifest property and optionally trims a relative path prefix.
            %
            % Args:
            %   obj (ndi.setup.NDIMaker.sessionMaker): The object instance.
            %   fileManifest (cell vector): A cell array of strings (or char arrays),
            %                                where each element is a relative file path.
            %
            % Optional Name-Value Args:
            %   relativePathTrim (char vector | string): A prefix string to remove from the beginning
            %                                            of each path in fileManifest. Defaults to ''.

            arguments
                obj                       (1,1) ndi.setup.NDIMaker.sessionMaker % Ensure it's operating on a valid object instance
                fileManifest              (:,1) cell {mustBeVector, mustBeText} % Column cell vector of text
                options.relativePathTrim  (1,:) {mustBeTextScalarOrCharVector} = '' % Allow char row vector or string scalar, default empty
            end

            originalManifest = fileManifest; % Keep a copy of the input

            % --- Apply relativePathTrim if provided ---
            prefixToTrim = options.relativePathTrim;
            % Ensure prefix is a char vector for consistent processing
            if isstring(prefixToTrim)
                prefixChar = char(prefixToTrim);
            else
                prefixChar = prefixToTrim; % Assume it's already char
            end

            if ~isempty(prefixChar)
                prefixLen = length(prefixChar);
                processedManifest = cell(size(originalManifest)); % Preallocate output
                for k = 1:numel(originalManifest)
                    originalPath = originalManifest{k};
                    % Ensure path is char for comparison/indexing
                    if ~ischar(originalPath)
                       originalPath = char(originalPath);
                    end

                    processedManifest{k} = originalPath; % Default: keep original path
                    originalPathLen = length(originalPath);

                    % Check if path is long enough AND starts with the prefix
                    if originalPathLen >= prefixLen && strncmp(originalPath, prefixChar, prefixLen)
                        % It starts with the prefix
                        if originalPathLen > prefixLen
                            % Extract the rest of the path
                            processedManifest{k} = originalPath(prefixLen+1:end);
                        else
                            % Prefix matches the entire path -> Result is empty char
                            processedManifest{k} = '';
                            warning('sessionMaker:setManifest:PrefixIsFullPath', ...
                                    'The prefix "%s" matches the entire path "%s". Resulting path is empty.', ...
                                    prefixChar, originalPath);
                        end
                    % else: Path doesn't start with prefix or is shorter, keep original (default already set)
                    end
                end
                obj.fileManifest = processedManifest; % Store the processed manifest
            else
                obj.fileManifest = originalManifest; % Store the original manifest if no prefix provided
            end
             % --- End of prefix processing ---
        end

        function computeDataLocationVariables(obj)
            % COMPUTEDATALOCATIONVARIABLES Extracts variables from file paths.
            %   Runs the external function 'processFileManifest' using the object's
            %   'fileManifest' and 'dataLocationVariableRules' properties.
            %   Stores the resulting structure in the 'dataLocationVariables' property.
            %   Requires 'processFileManifest.m' to be on the MATLAB path.

            % --- Input Validation ---
            if isempty(obj.fileManifest)
                error('sessionMaker:computeDataLocationVariables:NoManifest', ...
                      'The ''fileManifest'' property is empty. Call setManifest() first.');
            end
            if isempty(obj.dataLocationVariableRules) || ~isstruct(obj.dataLocationVariableRules)
                error('sessionMaker:computeDataLocationVariables:NoRules', ...
                      'The ''dataLocationVariableRules'' property is empty or not a struct array. Ensure it is set correctly before calling this method.');
            end

            % --- Check for external function dependency ---
            if isempty(which('processFileManifest'))
                error('sessionMaker:computeDataLocationVariables:MissingFunction',...
                      'The required function ''processFileManifest.m'' was not found on the MATLAB path.');
            end

            % --- Execute processing ---
            try
                % Call the external function using the object's properties
                fprintf('Computing data location variables...\n'); % Optional progress message
                extractedData = processFileManifest(obj.fileManifest, obj.dataLocationVariableRules);

                % Store the results in the object's property
                obj.dataLocationVariables = extractedData;
                fprintf('... Computation complete. Results stored in dataLocationVariables.\n'); % Optional completion message

            catch ME
                warning('sessionMaker:computeDataLocationVariables:ExecutionError', ...
                        'An error occurred while running processFileManifest: %s', ME.message);
                % Display stack trace for debugging
                disp(ME.getReport);
                % Rethrow the error to halt execution and indicate failure clearly
                rethrow(ME);
            end
        end

        % --- Placeholder for other potential methods ---
        % function addDaqSystem(obj, reader, navigator)
        %   % Method to populate the DaqSystems property
        % end
        %
        % function setRules(obj, rulesStruct)
        %   % Method to explicitly set the dataLocationVariableRules
        %   % Could include validation specific to the rules structure
        %   obj.dataLocationVariableRules = rulesStruct;
        % end
        %
        % function sessionObjects = createSessions(obj, varargin)
        %    % Method that would use fileManifest, dataLocationVariables, DaqSystems, etc.
        %    % to instantiate ndi.session.dir objects and store them in obj.sessions
        %    error('Not yet implemented');
        % end
        % -------------------------------------------------

    end % methods block
end % classdef

% --- Custom Validator (Helper Function) ---
% Place this outside the classdef block if needed, or define locally within methods if preferred.
% This validator is used in the 'arguments' block of setManifest.
function mustBeTextScalarOrCharVector(input)
    if ~(ischar(input) && (isrow(input) || isempty(input))) && ~(isstring(input) && isscalar(input))
        error('Value must be a character row vector or a scalar string.');
    end
end