% Folder: +ndi/+setup/+NDIMaker/
classdef stimulusBathMaker < handle
    %stimulusBathMaker Creates and manages stimulus bath documents for an NDI session.
    %   This class is responsible for generating 'stimulus_bath' documents
    %   based on experimental variables, mixture ontologies, and bath target
    %   ontologies. It links these documents to specific epochs and stimulators
    %   within an NDI session.

    properties (Access = public)
        session                         % The NDI session object (e.g., ndi.session.dir or ndi.database.dir) where stimulus bath documents will be added.
        mixtureFilename (1,:) char      % Filename (including path) where mixture ontologies are stored (JSON format).
        bathtargetsFilename (1,:) char  % Filename (including path) where bath target ontologies are stored (JSON format).
        mixtureStruct struct            % Structure loaded from 'mixtureFilename' containing mixture ontology definitions.
        bathtargetsStruct struct        % Structure loaded from 'bathtargetsFilename' containing bath target ontology definitions.
    end

    methods
        function obj = stimulusBathMaker(session,labName,options)
            %STIMULUSBATHMAKER Constructor for this class.
            %   Initializes the stimulusBathMaker by loading mixture and bath
            %   target ontology files specific to the given labName and associating
            %   it with the provided NDI session.
            %
            %   Inputs:
            %       session: An NDI session object (e.g., an instance of
            %                ndi.session.dir or ndi.database.dir).
            %       labName: A character vector specifying the name of the lab.
            %                This is used to locate the appropriate ontology files
            %                (e.g., 'labName_mixtures.json','labName_bathtargets.json')
            %                in the 'NDI-MATLAB/+ndi/+setup/+conv/+labName' folder.
            %
            %   Optional Name-Value Arguments:
            %       GetProbes: Runs session.getprobes. Depeneding on the
            %                size of the session, this can add significant
            %                processing time.
            %
            %   Outputs:
            %       obj: An instance of the stimulusBathMaker class.
            %
            %   Example:
            %       session = ndi.session.dir('/path/to/my/session');
            %       labName = 'labName';
            %       bathMaker = ndi.setup.NDIMaker.stimulusBathMaker(session, labName);
            
            % Input argument validation
            arguments
                session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
                labName (1,:) char
                options.GetProbes (1,1) logical = false
            end

            % Store the session object
            obj.session = session;

            % Get probes
            if options.GetProbes
                obj.session.getprobes;
            end

            % Construct the path to the lab-specific ontology files
            labFolder = fullfile(ndi.common.PathConstants.RootFolder,...
                '+ndi','+setup','+conv',['+',labName]);

            % Get mixture structure
            obj.mixtureFilename = fullfile(labFolder,[labName,'_mixtures.json']);
            if ~isfile(obj.mixtureFilename)
                error('stimulusBathMaker:MixtureFileNotFound', 'Mixture file not found: %s', obj.mixtureFilename);
            end
            obj.mixtureStruct = jsondecode(fileread(obj.mixtureFilename));

            % Get bath targets structure
            obj.bathtargetsFilename = fullfile(labFolder,[labName,'_bathtargets.json']);
            if ~isfile(obj.bathtargetsFilename)
                error('stimulusBathMaker:BathTargetFileNotFound', 'Bath target file not found: %s', obj.bathtargetsFilename);
            end
            obj.bathtargetsStruct = jsondecode(fileread(obj.bathtargetsFilename));
        end % STIMULUSBATHMAKER

        function docs = createBathDoc(obj, stimulator_id, epoch_id, bathtargetStrings, mixtureStrings,options)
            %CREATEBATHDOC Creates and adds NDI 'stimulus_bath' documents to the session database.
            %   Constructs one or more 'stimulus_bath' NDI documents for a specific
            %   stimulator and epoch, based on provided bath target(s) and mixture(s).
            %   It looks up ontology details (location name, mixture components) using
            %   the loaded structures.
            %
            %   Inputs:
            %       obj: An instance of the stimulusBathMaker class.
            %       stimulatorid: The NDI element ID of the stimulator device.
            %       epochid: The NDI epoch ID for which the document is being created.
            %       bathtargetStrings: A character vector or a cell array of character
            %                          vectors specifying the bath target(s) by name. These names
            %                          must match keys (case-sensitively) in 'obj.bathtargetsStruct'.
            %       mixtureStrings: A character vector or a cell array of character
            %                       vectors specifying the mixture(s) by name. These names
            %                       must match keys (case-sensitively) in 'obj.mixtureStruct'.
            %
            %   Optional Name-Value Arguments:
            %       Overwrite: A flag intended to control whether existing documents 
            %                       should be overwritten. Default: false.
            %
            %   Outputs:
            %       docs: A cell array containing the newly created 'stimulus_bath' NDI document
            %             object(s). A separate document is created for each distinct location
            %             associated with the provided 'bathtargetStrings'.
            %
            %   See also: NDI.SETUP.CONV.MARDER.MIXTURESTR2MIXTURETABLE,
            %       NDI.DATABASE.FUN.FINDDOCS_ELEMNTEPOCHTYPE,
            %       NDI.DATABASE.FUN.UBERON_ONTOLOGY_LOOKUP,
            %       NDI.DATABASE.FUN.WRITETABLECHAR
            
            % Input argument validation
            arguments
                obj
                stimulator_id (1,:) char
                epoch_id (1,:) char
                bathtargetStrings {mustBeA(bathtargetStrings,{'char','str','cell'})}
                mixtureStrings {mustBeA(mixtureStrings,{'char','str','cell'})}
                options.Overwrite (1,1) logical = false;
            end

            % --- Process Mixture Strings ---
            mixtureNames = fieldnames(obj.mixtureStruct); % Get valid mixture names
            if ischar(mixtureStrings) % Ensure mixtureStrings is a cell array
                mixtureStrings = {mixtureStrings};
            end
            mixtureTable = table(); % Initialize mixture component table
            for i = 1:numel(mixtureStrings)
                % Validate mixture string
                if ~any(strcmpi(mixtureNames,mixtureStrings{i}))
                    error('STIMULUSBATHMAKER:InvalidMixtureString',...
                        '%s is not a valid mixture name in the mixtures file: %s.',...
                        mixtureStrings{i},obj.mixtureFilename)
                elseif ~any(strcmp(mixtureNames,mixtureStrings{i}))
                    mixtureStrings(i) = mixtureNames(strcmpi(mixtureNames,mixtureStrings{i}));
                end
                
                % Convert mixture string to table format
                mixtureTable = cat(1,mixtureTable,ndi.setup.conv.marder.mixtureStr2mixtureTable(...
                    mixtureStrings{i},obj.mixtureStruct));
            end

            % --- Process Bath Target Strings ---
            bathtargetNames = fieldnames(obj.bathtargetsStruct); % Get valid bath target names
            if ischar(bathtargetStrings) % Ensure bathtargetStrings is a cell array
                bathtargetStrings = {bathtargetStrings};
            end
            locList = struct('location',{}); % Initialize location list
            for i = 1:numel(bathtargetStrings)
                % Validate bath target string
                if ~any(strcmpi(bathtargetNames,bathtargetStrings{i}))
                    error('STIMULUSBATHMAKER:InvalidBathtargetString',...
                        '%s is not a valid bath target name in the bath targets file: %s.',...
                        bathtargetStrings{i},obj.bathtargetsFilename)
                end

                % Append location structure(s) for the current target name
                locList = cat(1,locList,obj.bathtargetsStruct.(bathtargetStrings{i}));
            end

            % Initialize output cell array
            docs = cell(size(locList));

            % Check if document already exists, if so, skip or remove
            % from database if overwriting
            old_docs = ndi.database.fun.finddocs_elementEpochType(obj.session,...
                stimulator_id,epoch_id,'stimulus_bath');
            
            % Find locations that need to be processed
            locNum = 1:numel(locList);
            for i = 1:numel(old_docs)

                % Find location ontology node(s) that match the doc
                locMatch = strcmpi({locList.location},...
                    old_docs{i}.document_properties.stimulus_bath.location.ontologyNode);
                
                if any(locMatch)
                    if options.Overwrite
                        % If overwriting, delete
                        obj.session.database_rm(old_docs{i});
                    else
                        % If not overwriting, grab doc and remove locNum from list
                        docs{locMatch} = old_docs{i};
                        locNum(locMatch) = NaN;
                    end
                end
            end
            locNum(isnan(locNum)) = [];

            % --- Create and Add Documents ---
            for l = locNum

                % Define stimulus bath structure
                stimulus_bath.location.ontologyNode = locList(l).location;
                [~,stimulus_bath.location.name] = ndi.ontology.lookup(locList(l).location);
                stimulus_bath.mixture_table = ndi.database.fun.writetablechar(mixtureTable);

                % Create stimulus bath document
                epochid.epochid = epoch_id;
                current_doc = ndi.document('stimulus_bath',...      % Document type
                    'stimulus_bath', stimulus_bath,...              % Data payload
                    'epochid', epochid) + ...                       % Associate with epoch
                    obj.session.newdocument();                      % Merge with session defaults

                % Set dependency link to the stimulator
                current_doc = current_doc.set_dependency_value(...
                    'stimulus_element_id', stimulator_id);

                % Add document to list
                docs{l} = current_doc;

                % Add stimulus bath document to database
                obj.session.database_add(current_doc);
            end
        end % CREATEBATHDOCS
        
        function docs = table2bathDocs(obj, variableTable, bathVariable, mixtureVariable, options)
            %TABLE2BATHDOCS Converts rows in a table into stimulus bath documents via CREATEBATHDOCS.
            %   Processes a MATLAB table where rows represent experimental epochs.
            %   For each valid epoch row, it extracts filename,bath target, and 
            %   mixture information, then calls `createBathDoc` to generate
            %   and add the corresponding 'stimulus_bath' NDI document(s) to the database.
            %
            %   Inputs:
            %       obj: An instance of the stimulusBathMaker class.
            %       variableTable: A MATLAB table. Rows usually correspond to epochs.
            %                      Columns specified by `BathVariable`,
            %                      `MixtureVariable`, and `options.FilenameVariable`
            %                       are used if they exist.
            %       bathVariable: The name of the column in 'variableTable'
            %                      containing the bath target string(s).
            %                      If the column doesn't exist, this value is used as a fixed
            %                      bath target string for all processed epochs.
            %       mixtureVariable: The name of the column in 'variableTable'
            %                      containing the mixture string(s). If the column doesn't exist,
            %                      this value is used as a fixed mixture string for all epochs.
            %
            %   Optional Name-Value Arguments:
            %       FilenameVariable: The name of the column in 'variableTable'
            %                      containing the filename for each epoch, used to derive
            %                      the NDI 'epochid'. If empty or not provided, defaults 
            %                      to using the table's 'RowNames'.
            %       NonNaNVariableNames: Variable names in 'variableTable'. Values in 
            %                      these columns must not be NaN for a valid epoch.
            %                      Default: {} (assumes all rows are valid epochs).
            %       MixtureDictionary: Struct to map mixture names to keys
            %                      in 'mixtureStruct'. Dictionary keys are names from data (spaces->'_'),
            %                      values are the corresponding 'mixtureStruct' key names.
            %                      Defaults to empty (no mapping). (e.g. 'Pre' -> 'aCSF')
            %       MixtureDelimeter: Character(s) seperating mixture names
            %                      (e.g. ',' or ' + '). Default: ','.
            %       Overwrite: A flag intended to control whether existing documents 
            %                      should be overwritten. Default: false.
            %
            %   Outputs:
            %       docs: A cell array where each cell corresponds to an input epoch row
            %             processed. Each cell contains another cell array holding the
            %             'stimulus_bath' NDI document object(s) created for that epoch 
            %             by `createBathDoc`.
            
            arguments
                obj
                variableTable table
                bathVariable (1,:) char
                mixtureVariable (1,:) char
                options.FilenameVariable (1,:) char = ''
                options.NonNaNVariableNames {mustBeA(options.NonNaNVariableNames,{'char','str','cell'})} = {}
                options.MixtureDictionary struct = struct()
                options.MixtureDelimeter (1,:) char = ','
                options.Overwrite (1,1) logical = false
            end

            % If no FilenameVariable specified, use 'RowNames' of VariableTable
            if isempty(options.FilenameVariable)
                variableTable.Filename = variableTable.Properties.RowNames;
                options.FilenameVariable = 'Filename';
            end

            % Ensure NonNaNVariableNames is a cell array for consistent processing
            if ~iscell(options.NonNaNVariableNames)
                options.NonNaNVariableNames = {options.NonNaNVariableNames};
            end
            
            % --- Identify Valid Rows ---
            % Check for NaN values based on NonNaNVariableNames option
            nanInd = true(height(variableTable),1);
            for i = 1:numel(options.NonNaNVariableNames)
                % Check if the specified column exists
                if ~ismember(options.NonNaNVariableNames{i}, variableTable.Properties.VariableNames)
                    warning('sessionMaker:NonNaNVariableNames', 'Variable "%s" provided in NonNaNVariableNames not found in variableTable. Skipping check.', options.NonNaNVariableNames{i});
                    continue; % Skip to the next variable name if the current one doesn't exist
                end
                % Update nanInd: a row is valid only if it passes the previous checks AND the current variable check
                nanVariable = variableTable.(options.NonNaNVariableNames{i});
                if iscell(nanVariable)
                    nanInd = nanInd & cellfun(@(sr) ~any(isnan(sr)),nanVariable);
                else
                    nanInd = nanInd & ~isnan(nanVariable);
                end
            end
            epochInd = find(nanInd); % Get linear indices of valid rows

            % Get epoch ids from data file names
            filenames = variableTable.(options.FilenameVariable)(epochInd);
            epochids = ndi.fun.epoch.filename2epochid(obj.session,filenames);

            docs = cell(size(epochInd)); % Initialize output cell array
            for e = 1:numel(epochInd)

                % Get stimulator id associated to the epochid
                stim = ndi.fun.epoch.epochid2element(obj.session,epochids{e},'type','stimulator');
                if isempty(stim)
                    error('STIMULUSBATHMAKER:MissingStimulator',...
                        'No stimulator found in the session.')
                elseif iscell(stim) & numel(stim) > 1
                        error('STIMULUSBATHMAKER:SeveralStimulators',...
                            'More than one stimulator found in the session.')
                elseif iscell(stim) & isscalar(stim)
                    stim = stim{1};
                end
                stimulatorid = stim.id;

                % Get bath target string
                if any(strcmpi(fieldnames(variableTable),bathVariable))
                    bathtargetStrings = variableTable.(bathVariable){epochInd(e)};
                else
                    bathtargetStrings = bathVariable;
                end

                % Get mixture strings
                if any(strcmpi(fieldnames(variableTable),mixtureVariable))
                    mixtureStrings = variableTable.(mixtureVariable){epochInd(e)};
                else
                    mixtureStrings = mixtureVariable;
                end

                % Convert mixture strings using key in mixture dictionary then confirm match to mixtureStruct
                mixtureStrings = strsplit(mixtureStrings,options.MixtureDelimeter);
                mixtureStrings = strtrim(mixtureStrings);
                mixtureStrings = replace(mixtureStrings,' ','_');
                for i = 1:numel(mixtureStrings)
                    if any(strcmpi(fieldnames(options.MixtureDictionary),mixtureStrings{i}))
                        mixtureStrings{i} = options.MixtureDictionary.(replace(mixtureStrings{i},' ','_'));
                    end
                    if ~any(strcmpi(fieldnames(obj.mixtureStruct),mixtureStrings{i}))
                        error('STIMULUSBATHMAKER:InvalidMixture',...
                            'Could not find the mixture named %s listed in the file %s.',...
                            mixtureStrings{i},obj.mixtureFilename)
                    end
                end

                % Create stimulus bath doc and add to database
                docs{e} = createBathDoc(obj, stimulatorid, epochids{e}, ...
                    bathtargetStrings, mixtureStrings,'Overwrite',options.Overwrite);
            end
        end % TABLE2BATHDOCS
    end
end