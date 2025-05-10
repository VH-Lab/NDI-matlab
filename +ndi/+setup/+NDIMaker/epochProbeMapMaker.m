% Folder: +ndi/+setup/+NDIMaker/
classdef epochProbeMapMaker < handle
    %EPOCHPROBEMAPMAKER Creates or updates epoch probe map files for NDI sessions.
    %   The EPOCHPROBEMAPMAKER class automates the generation of '.epochprobemap.txt'
    %   files. These files map experimental epochs to data acquisition probes and devices.
    %   The class takes a base path (typically an NDI session directory), a table
    %   defining epoch-specific variables, and a table defining probe characteristics.
    %   It processes these inputs to create or update the epoch probe map files,
    %   associating subject information and device strings with each epoch and probe.
    %   The class includes options for validating input data and handling existing
    %   map files.

    properties (Access = public)
        path (1,:) char         % Base directory path where session folders are located or will be created.
        variableTable table     % Input table containing session definition information. Must contain 'SubjectString' and 'SessionPath' variables.
        probeTable table        % Input table containing session definition information. Must contain 'SubjectString' and 'SessionPath' variables.
    end

    methods
        function obj = epochProbeMapMaker(path,variableTable,probeTable,options)
            %EPOCHPROBEMAPMAKER Constructor for the epochProbeMapMaker class.
            %   OBJ = EPOCHPROBEMAPMAKER(PATH, VARIABLETABLE, PROBETABLE) creates an
            %   epochProbeMapMaker object and generates '.epochprobemap.txt' files.
            %   It uses the 'RowNames' from VARIABLETABLE as base filenames for the
            %   map files, which are saved in the directory specified by PATH.
            %   Each map file links probes defined in PROBETABLE to the corresponding
            %   epoch, using subject information from VARIABLETABLE.
            %
            %   OBJ = EPOCHPROBEMAPMAKER(..., 'Name', Value) allows specifying
            %   additional options to control the map creation process.
            %
            %   Input Arguments:
            %       path            - The absolute path to an NDI session directory
            %                           The generated '.epochprobemap.txt' files will 
            %                           be saved directly within this directory.
            %                           Must be an existing folder.
            %       variableTable   - A MATLAB table defining epoch-specific variables.
            %                           - Its `RowNames` must be unique epoch identifiers
            %                             which will serve as base filenames for the 
            %                             output '.epochprobemap.txt' files.
            %                           - Must contain a 'SubjectString' column (char or string).
            %                           - Other columns can be included and used for
            %                             validation via the 'NonNaNVariableNames' option.
            %       probeTable      - A MATLAB table defining probe characteristics. It 
            %                           must contain the following columns:
            %                           - 'name' (cellstr or string array): Name of the probe.
            %                           - 'reference' (numeric array): Reference number of the probe.
            %                           - 'type' (cellstr or string array): Type of the probe.
            %                           - 'deviceString' (cellstr or string array): Device string
            %                             associated with the probe.
            %
            %   Optional Name-Value Arguments:
            %       Overwrite        - If true, existing epoch probe maps found at the specified 
            %                           paths will be overwritten. Default: false.
            %       NonNaNVariableNames - Variable names in 'variableTable'.Values in 
            %                           these columns must not be NaN for a valid 
            %                           session to be created. Default: {}.
            %       ProbePostfix     - A postfix to be appended to probe names. Default: {} (no postfix).
            %                           - If a variable name in variableTable: The
            %                             value of that variable in the corresponding
            %                             row is used.
            %                           - If a char/string: This postfix is
            %                             appended to each probe name from `probeTable`.
            %                           - If a cell array: Its length must match the
            %                             total number of rows in the input `variableTable`
            %                             (before any filtering by `NonNaNVariableNames`).
            %                             The postfix corresponding to the original row
            %                             index of a valid epoch stream will be used.
            %                           
            %
            %   Output Arguments:
            %       obj (epochProbeMapMaker)  - The constructed epochProbeMapMaker object.

            arguments
                path (1,:) char
                variableTable table
                probeTable table
                options.Overwrite (1,1) logical = false;
                options.NonNaNVariableNames {mustBeA(options.NonNaNVariableNames,{'char','str','cell'})} = {};
                options.ProbePostfix {mustBeA(options.ProbePostfix,{'char','str','cell'})} = {};
            end

             % Assign properties from inputs
            obj.path = path;
            obj.variableTable = variableTable;
            obj.probeTable = probeTable;

            % Ensure NonNaNVariableNames is a cell array for consistent processing
            if ischar(options.NonNaNVariableNames)
                options.NonNaNVariableNames = {options.NonNaNVariableNames};
            elseif isstring(options.NonNaNVariableNames) && isscalar(options.NonNaNVariableNames)
                options.NonNaNVariableNames = {char(options.NonNaNVariableNames)};
            elseif isstring(options.NonNaNVariableNames) && ~isscalar(options.NonNaNVariableNames)
                 options.NonNaNVariableNames = cellstr(options.NonNaNVariableNames);
            end

            % Validate variableTable: check for required 'SubjectString' column
            if ~ismember('SubjectString', variableTable.Properties.VariableNames)
                error('epochProbeMapMaker:MissingSubjectString', ...
                    "The 'variableTable' must contain a 'SubjectString' column.");
            end

            % Validate probeTable: check for required columns
            requiredProbeCols = {'name', 'reference', 'type', 'deviceString'};
            missingProbeCols = setdiff(requiredProbeCols, probeTable.Properties.VariableNames);
            if ~isempty(missingProbeCols)
                error('epochProbeMapMaker:MissingProbeTableColumns', ...
                    "The 'probeTable' is missing the following required columns: %s.", strjoin(missingProbeCols, ', '));
            end

            % Check for NaN values based on NonNaNVariableNames option
            nanInd = true(height(variableTable),1);
            for i = 1:numel(options.NonNaNVariableNames)
                 % Check if the specified column exists
                 if ~ismember(options.NonNaNVariableNames{i}, variableTable.Properties.VariableNames)
                     warning('sessionMaker:NonNaNVariableNames', 'Variable "%s" provided in NonNaNVariableNames not found in variableTable. Skipping check.', options.NonNaNVariableNames{i});
                     continue; % Skip to the next variable name if the current one doesn't exist
                 end
                % Update nanInd: a row is valid only if it passes the previous checks AND the current variable check
                nanInd = nanInd & cellfun(@(sr) ~any(isnan(sr)), ...
                    variableTable.(options.NonNaNVariableNames{i}));
            end
            validInd = find(nanInd); % Get linear indices of valid rows

            if isempty(validInd)
                warning('epochProbeMapMaker:NoValidEpochs', ...
                    'No valid epochs found in variableTable after NaN checks. No epochprobemaps will be created.');
                return;
            end
            
            % Get epoch data filenames
            epochstreams = fullfile(path,variableTable.Properties.RowNames(validInd));
            
            for e = 1:numel(epochstreams)

                % Construct the full filename for the epoch probe map file
                [pathname,filename] = fileparts(epochstreams{e});
                probeFilename = fullfile(pathname,strcat(filename,'.epochprobemap.txt'));
                
                % Skip if not overwriting and file exists
                if ~options.Overwrite && exist(probeFilename, 'file')
                    continue
                end
                
                % Initialize an array of NDI epochprobemap_daqsystem objects for the current epoch
                probemap = ndi.epoch.epochprobemap_daqsystem.empty(0,height(probeTable));

                for p = 1:height(probeTable)

                    probeName = probeTable.name{p}; % Original probe name

                    % Apply ProbePostfix if specified
                    if numel(options.ProbePostfix) == height(variableTable)
                        probeName = strcat(probeName,options.ProbePostfix{validInd(e)});
                    elseif ischar(options.ProbePostfix)
                        if any(contains(variableTable.Properties.VariableNames,options.ProbePostfix))
                            probeName = strcat(probeName,variableTable.(options.ProbePostfix)(validInd(e)));
                        else
                            probeName = strcat(probeName,options.ProbePostfix);
                        end
                    end

                    % Create an epochprobemap_daqsystem object for the current probe
                    probemap(p) = ndi.epoch.epochprobemap_daqsystem(...
                        probeName,...
                        probeTable.reference{p},...
                        probeTable.type{p},...
                        probeTable.deviceString{p},...
                        variableTable.SubjectString{validInd(e)});
                end

                % Save the NDI epochprobemap objects to the file.
                probemap.savetofile(probeFilename);
            end
        end
    end
end