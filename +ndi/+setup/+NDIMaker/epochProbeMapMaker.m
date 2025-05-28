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
            %                           - If a char/string:
            %                               - If a variable name in variableTable, the
            %                                   value of that variable in the corresponding
            %                                   row is used.
            %                               - If not a variable name, this char/string is used.
            %                           - If a cell array: 
            %                               - If its length matches the total number of rows
            %                                   in the input `variableTable`, the value 
            %                                   in the corresponding row is used.
            %                               - If its length matches the total number of rows
            %                                   in the input `variableTable` and the second dimension
            %                                   matches the number of probes (i.e. height of probeTable),
            %                                   the value in the corresponding row is used for each probe.
            %                               - If values are variable names with length
            %                                   equal to the number of probes (i.e. height of
            %                                   probeTable, the value of the variable(s) 
            %                                   in the corresponding row are used. An empty
            %                                   char/str vector may be used to omit a postfix for
            %                                   certain variables (e.g. {'PostFix','','PostFix'})
            %                           
            %   Output Arguments:
            %       obj (epochProbeMapMaker)  - The constructed epochProbeMapMaker object.
            %
            %   See also: NDI.EPOCH.EPOCHPROBEMAP_DAQSYSTEM

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

            % Create progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label','Creating Epoch Probe Map(s)','Tag','epochprobemap');

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

            % Get valid epoch rows
            validInd = find(ndi.util.identifyValidRows(variableTable,options.NonNaNVariableNames));
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
                    
                    if ischar(options.ProbePostfix)
                        % Check if Postfix matches a variable name in variableTable
                        if any(strcmpi(variableTable.Properties.VariableNames,options.ProbePostfix))
                            probeName = strcat(probeName,variableTable.(options.ProbePostfix){validInd(e)});
                        
                        % If not, just append Postfix as is
                        else
                            probeName = strcat(probeName,options.ProbePostfix);
                        end
                    elseif iscell(options.ProbePostfix)
                        % Check if Postfix is the same length as the variableTable
                        if numel(options.ProbePostfix) == height(variableTable)
                            probeName = strcat(probeName,options.ProbePostfix{validInd(e)});

                        % Check if Postfix size matches the height(variableTable) x height(probeTable)
                        elseif size(options.ProbePostfix) == [height(variableTable),height(probeTable)]
                            probeName = strcat(probeName,options.ProbePostfix{validInd(e),p});

                        % Check if Postfix size matches the height(probeTable) x height(variableTable)
                        elseif size(options.ProbePostfix) == [height(probeTable),height(variableTable)]
                            probeName = strcat(probeName,options.ProbePostfix{p,validInd(e)});
                        
                        % Check if Postfix contains variable names in variableTable
                        elseif numel(options.ProbePostfix) == height(probeTable)
                            if isempty(options.ProbePostfix{p})
                                probeName = probeName;
                            elseif any(strcmpi(variableTable.Properties.VariableNames,options.ProbePostfix{p}))
                                probeName = strcat(probeName,variableTable.(options.ProbePostfix{p}){validInd(e)});
                            else
                                 warning('EPOCHPROBEMAPMAKER:InvalidPostfix',...
                                    'ProbePostfix %s is not valid.',options.ProbePostfix{p})
                            end
                        else
                            warning('EPOCHPROBEMAPMAKER:InvalidPostfix',...
                                'ProbePostfix is not valid.')
                        end
                    else
                        warning('EPOCHPROBEMAPMAKER:InvalidPostfix',...
                                'ProbePostfix is not valid.')
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

                % Update progress bar
                progressBar = progressBar.updateBar('epochprobemap',e/numel(epochstreams));
                if strcmpi(progressBar.getStatus('epochprobemap'),'Pause')
                    uiwait(progressBar.ProgressFigure);
                end
            end
        end
    end
end