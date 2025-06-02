% Folder: +ndi/+setup/+NDIMaker/
classdef sessionMaker < handle % Using handle class for reference behavior (objects are passed by reference)
%SESSIONMAKER Manages session creation setup based on a variable table.
%   The SESSIONMAKER class facilitates the setup and creation of
%   ndi.session.dir objects. It identifies unique sessions, handles 
%   existing session directories (with an option to overwrite),
%   and provides mechanisms to associate DAQ systems with these sessions.
    properties (Access = public)
        path (1,:) char         % Base directory path where session folders are located or will be created.
        variableTable table     % Input table containing session definition information. Must contain 'SessionRef' and 'SessionPath' variables.
        sessions cell           % Cell array holding the created/loaded ndi.session.dir objects (unique sessions).
        tableInd (:,1) double   % Array mapping rows of the input 'variableTable' to session indices in 'sessions'. Invalid 'variableTable' rows will have NaN entries.
        daqSystems struct       % Struct array holding DAQ system information for each session. Contains fields 'filenavigator' and 'daqreader'.
    end
    methods
        function obj = sessionMaker(path,variableTable,options)
            %SESSIONMAKER Constructor for the sessionMaker class.
            %   OBJ = SESSIONMAKER(PATH, VARIABLETABLE) creates a sessionMaker object.
            %   It identifies unique sessions based on the 'SessionRef' column in
            %   VARIABLETABLE, validates corresponding 'SessionPath' entries, and
            %   either creates new NDI session directories or loads existing ones.
            %
            %   OBJ = SESSIONMAKER(..., 'Name', Value) allows specifying additional options:
            %
            %   Input Arguments:
            %       path            - The absolute path to the base directory containing
            %                           session folders. Must be an existing folder.
            %       variableTable   - A MATLAB table defining the sessions. Must contain
            %                           'SessionRef' and 'SessionPath' columns. Other 
            %                           columns can be included and potentially used for 
            %                           validation via the 'NonNaNVariableNames' option.
            %
            %   Optional Name-Value Arguments:
            %       Overwrite        - If false, existing sessions are loaded without 
            %                           modification. If true, existing NDI session 
            %                           databases found at the specified paths will be 
            %                           erased and recreated. Default: false.
            %       NonNaNVariableNames - Variable names in 'variableTable'.Values in 
            %                           these columns must not be NaN for a valid 
            %                           session to be created. Default: {}.
            %
            %   Output Arguments:
            %       obj (sessionMaker)  - The constructed sessionMaker object.
            % Input argument validation using the arguments block
            arguments
                path (1,:) char {mustBeFolder}
                variableTable table
                options.Overwrite (1,1) logical = false;
                options.NonNaNVariableNames {mustBeA(options.NonNaNVariableNames,{'char','str','cell'})} = {};
            end

            % Create progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label','Creating Session(s)','Tag','sessions');

            % Assign properties from inputs
            obj.path = path;
            obj.variableTable = variableTable;
            
            % Get valid epoch rows
            validInd = find(ndi.util.identifyValidRows(variableTable,options.NonNaNVariableNames));
            
            % --- Determine Unique Sessions ---
            % Extract SessionRef values from the valid rows
            validSessionRefs = variableTable.SessionRef(validInd);
            % Find unique session references among the valid ones
            [sessionRefs,sessionInd_unique,tableInd_map] = unique(validSessionRefs,'stable'); % 'stable' preserves order of first appearance
            % sessionInd_unique now points into 'validInd'. We need the original row index from 'variableTable'.
            firstOccurrenceInd = validInd(sessionInd_unique); % Indices in the original variableTable for the first occurrence of each unique session
            % --- Populate tableInd Property ---
            % Initialize tableInd with NaNs for all rows
            obj.tableInd = nan(height(variableTable),1);
            % For the valid rows, assign the index from tableInd_map, which maps to the unique session index
            obj.tableInd(validInd) = tableInd_map;
            % --- Create or Load NDI Session Objects ---
            obj.sessions = cell(size(sessionRefs)); % Preallocate cell array for ndi.session.dir objects
            for i = 1:numel(sessionRefs) % Iterate through unique sessions
                % Get the full path for the current session using the path from the *first occurrence* row
                sessionPath = fullfile(path, variableTable.SessionPath{firstOccurrenceInd(i)});
                sessionRef = sessionRefs{i}; % The unique session reference identifier
                % Check if the session directory and NDI database exist
                if ndi.session.dir.exists(sessionPath)
                    % Session exists: Load it
                    obj.sessions{i} = ndi.session.dir(sessionPath);
                    % Check if Overwrite option is enabled
                    if options.Overwrite
                        % Delete the existing session database
                        ndi.session.dir.database_erase(obj.sessions{i}, 'yes');
                        % Create a new session object with the reference and path
                        obj.sessions{i} = ndi.session.dir(sessionRef, sessionPath);
                    end
                else
                    % Session does not exist: Create it
                    obj.sessions{i} = ndi.session.dir(sessionRef, sessionPath); % Create with reference and path
                end

                % Update progress bar
                progressBar = progressBar.updateBar('sessions',i/numel(sessionRefs));
                
                % Close any open database connections
                % mksqlite('close');
            end
            % Initialize the daqSystems property as an empty struct with the specified fields
            obj.daqSystems = struct('filenavigator', {}, 'daqreader', {});
            % Ensure it has the correct size corresponding to the number of sessions
            if ~isempty(obj.sessions) % Check if sessions were created
                obj.daqSystems(numel(obj.sessions)).filenavigator = []; % Preallocate size
            end
        end % constructor sessionMaker

        function [sessions, ind, session_ids] = sessionIndices(obj)
            %SESSIONINDICES Returns unique session objects, their mapping to table rows, and session IDs per table row.
            %   [SESSIONS, IND, SESSION_IDS] = sessionIndices(OBJ)
            %   returns the cell array of unique ndi.session.dir objects, an array
            %   indicating which unique session corresponds to each row of the
            %   original variableTable, and a cell array of session ID strings for each
            %   row of the variableTable.
            %
            %   Output Arguments:
            %       sessions (cell)            - Cell array of unique ndi.session.dir objects, where
            %                                    sessions{k} is the k-th unique session.
            %       ind (:,1) double           - Array of the same height as the original
            %                                    variableTable. `ind(r)` gives the index `k` such
            %                                    that `sessions{k}` is the session associated
            %                                    with row `r` of the table. Rows not associated with a
            %                                    valid session will have NaN values.
            %       session_ids (cell)         - Cell array of strings, of the same height as the
            %                                    original variableTable. `session_ids{r}`
            %                                    is the session ID (from ndi.session.id())
            %                                    of the session associated with row `r` of variableTable.
            %                                    Entries for rows not associated with a valid session
            %                                    will be empty strings ''.

            sessions = obj.sessions; % These are the unique sessions
            ind = obj.tableInd;      % This maps each row of variableTable to an index in 'sessions'
            
            % First, get IDs for all unique sessions
            unique_session_ids_list = cell(size(sessions)); % Corresponds to 'sessions'
            for i=1:numel(sessions)
                if ~isempty(sessions{i}) && isvalid(sessions{i}) % Check if session object is valid and not empty
                    try
                        unique_session_ids_list{i} = sessions{i}.id();
                    catch ME
                        warning('sessionMaker:sessionIndices:FailedToGetId', ...
                            ['Failed to get ID for unique session index ' num2str(i) '. Error: ' ME.message]);
                        unique_session_ids_list{i} = 'ERROR_GETTING_ID'; % Placeholder for error
                    end
                else
                    unique_session_ids_list{i} = ''; % Placeholder for empty/invalid unique sessions
                end
            end

            % Now, map these unique session IDs to each row of the variableTable
            num_rows_in_table = height(obj.variableTable);
            session_ids_per_row = cell(num_rows_in_table, 1); % This will be the actual third output

            for k = 1:num_rows_in_table
                session_idx_for_this_row = ind(k); % Get the index into the 'sessions' (unique sessions) array
                
                % Check if the index is valid and points to an actual unique session
                if ~isnan(session_idx_for_this_row) && ...
                   session_idx_for_this_row > 0 && ...
                   session_idx_for_this_row <= numel(unique_session_ids_list)
                    
                    % Assign the ID of the corresponding unique session
                    session_ids_per_row{k} = unique_session_ids_list{session_idx_for_this_row};
                else
                    % This row in variableTable is not associated with a valid unique session
                    session_ids_per_row{k} = ''; 
                end
            end
            session_ids = session_ids_per_row; % Assign to the output variable
        end % sessionIndices

        function addDaqSystem(obj, labName, options)
            %ADDDAQSYSTEM Adds DAQ system definitions from a specified lab to all managed sessions.
            %   ADDDAQSYSTEM(OBJ, LABNAME) searches for DAQ system definitions
            %   associated with LABNAME (a folder name within the NDI DAQ
            %   system configuration directory) and adds them to each NDI session
            %   managed by the sessionMaker object (obj.sessions). It then loads
            %   the DAQ reader and file navigator objects for each session and stores
            %   them in the obj.daqSystems property.
            %
            %   ADDDAQSYSTEM(..., 'Overwrite', true) allows overwriting existing DAQ
            %   system definitions within the sessions if they already exist. The
            %   default is false (no overwrite).
            %
            %   Input Arguments:
            %       obj     - The sessionMaker instance.
            %       labName - The name of the lab configuration directory
            %                   containing the DAQ system definition files.
            %
            %   Name-Value Arguments:
            %       Overwrite - Whether to overwrite existing DAQ system 
            %                   entries in the sessions. Default: false.
            arguments
                obj
                labName (1,:) char
                options.Overwrite (1,1) logical = false;
            end
            % Check that the daq_system directory for the lab exists
            try
                ndi.setup.daq.system.listDaqSystemNames(labName);
            catch ME
                % If listDaqSystemNames errors, rethrow a more specific error
                importDir = fullfile(ndi.common.PathConstants.CommonFolder, 'daq_systems'); % Get expected base path for DAQ systems
                error('SESSIONMAKER:invalidDAQDirName','%s is not a valid subdirectory of %s',...
                    labName,importDir);
            end
            for i = 1:numel(obj.sessions)
                % Add DAQ systems to each session
                ndi.setup.daq.addDaqSystems(obj.sessions{i},labName,options.Overwrite);
                % Load the DAQ system information back from the session
                daq_info = obj.sessions{i}.daqsystem_load;
                obj.daqSystems(i).filenavigator = daq_info.filenavigator;
                obj.daqSystems(i).daqreader = daq_info.daqreader;
            end
        end
    end % methods
end % sessionMaker
