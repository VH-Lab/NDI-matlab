% Folder: +ndi/+setup/+NDIMaker/
classdef stimulusDocMaker < handle
    %stimulusDocMaker Creates and manages stimulus bath documents for an NDI session.
    %   This class is responsible for generating 'stimulus_bath' documents
    %   based on experimental variables, mixture ontologies, and bath target
    %   ontologies. It links these documents to specific epochs and stimulators
    %   within an NDI session.

    properties (Access = public)
        session                         % The NDI session object (e.g., ndi.session.dir or ndi.database.dir) where stimulus documents will be added.
        mixtureFilename (1,:) char      % Filename (including path) where mixture ontologies are stored (JSON format).
        bathtargetsFilename (1,:) char  % Filename (including path) where bath target ontologies are stored (JSON format).
        mixtureStruct struct            % Structure loaded from 'mixtureFilename' containing mixture ontology definitions.
        bathtargetsStruct struct        % Structure loaded from 'bathtargetsFilename' containing bath target ontology definitions.
    end

    methods
        function obj = stimulusDocMaker(session,labName,options)
            %STIMULUSDOCMAKER Constructor for this class.
            %   Initializes the stimulusDocMaker by loading mixture and bath
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
            %       obj: An instance of the stimulusDocMaker class.
            %
            %   Example:
            %       session = ndi.session.dir('/path/to/my/session');
            %       labName = 'labName';
            %       stimulusMaker = ndi.setup.NDIMaker.stimulusDocMaker(session, labName);
            
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
                error('stimulusDocMaker:MixtureFileNotFound', 'Mixture file not found: %s', obj.mixtureFilename);
            end
            obj.mixtureStruct = jsondecode(fileread(obj.mixtureFilename));

            % Get bath targets structure
            obj.bathtargetsFilename = fullfile(labFolder,[labName,'_bathtargets.json']);
            if ~isfile(obj.bathtargetsFilename)
                error('stimulusDocMaker:BathTargetFileNotFound', 'Bath target file not found: %s', obj.bathtargetsFilename);
            end
            obj.bathtargetsStruct = jsondecode(fileread(obj.bathtargetsFilename));
        end % STIMULUSDOCMAKER

        function docs = createBathDoc(obj, stimulator_id, epoch_id, bathtargetStrings, mixtureStrings,options)
            %CREATEBATHDOC Creates and adds NDI 'stimulus_bath' documents to the session database.
            %   Constructs one or more 'stimulus_bath' NDI documents for a specific
            %   stimulator and epoch, based on provided bath target(s) and mixture(s).
            %   It looks up ontology details (location name, mixture components) using
            %   the loaded structures.
            %
            %   Inputs:
            %       obj: An instance of the stimulusDocMaker class.
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
                bathtargetStrings {mustBeText}
                mixtureStrings {mustBeText}
                options.Overwrite (1,1) logical = false;
            end

            % --- Process Mixture Strings ---
            mixtureNames = fieldnames(obj.mixtureStruct); % Get valid mixture names
            mixtureStrings = cellstr(mixtureStrings); % Ensure mixtureStrings is a cell array
            mixtureTable = table(); % Initialize mixture component table
            for i = 1:numel(mixtureStrings)
                % Validate mixture string
                if ~any(strcmpi(mixtureNames,mixtureStrings{i}))
                    error('STIMULUSDOCMAKER:InvalidMixtureString',...
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
            bathtargetStrings = cellstr(bathtargetStrings);  % Ensure bathtargetStrings is a cell array
            locList = struct('location',{}); % Initialize location list
            for i = 1:numel(bathtargetStrings)
                % Validate bath target string
                if ~any(strcmpi(bathtargetNames,bathtargetStrings{i}))
                    error('STIMULUSDOCMAKER:InvalidBathtargetString',...
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
            %       obj: An instance of the stimulusDocMaker class.
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
                options.NonNaNVariableNames {mustBeText} = {}
                options.MixtureDictionary struct = struct()
                options.MixtureDelimeter (1,:) char = ','
                options.Overwrite (1,1) logical = false
            end

            % Create progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label','Creating Stimulus Bath Document(s)','Tag','stimulusbath');

            % If no FilenameVariable specified, use 'RowNames' of VariableTable
            if isempty(options.FilenameVariable)
                variableTable.Filename = variableTable.Properties.RowNames;
                options.FilenameVariable = 'Filename';
            end

            % Get valid epoch rows
            epochInd = find(ndi.fun.table.identifyValidRows(variableTable,options.NonNaNVariableNames));

            % Get epoch ids from data file names
            filenames = variableTable.(options.FilenameVariable)(epochInd);
            epochids = ndi.fun.epoch.filename2epochid(obj.session,filenames);

            % Get stimulator elements associated with the epochids
            stims = ndi.fun.epoch.epochid2element(obj.session,epochids,'type','stimulator');

            docs = cell(size(epochInd)); % Initialize output cell array
            for e = 1:numel(epochInd)

                % Get stimulator id associated to the epochid
                stim = stims{e};
                if isempty(stim)
                    error('STIMULUSDOCMAKER:MissingStimulator',...
                        'No stimulator found in the session.')
                elseif iscell(stim) & numel(stim) > 1
                        error('STIMULUSDOCMAKER:SeveralStimulators',...
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
                        error('STIMULUSDOCMAKER:InvalidMixture',...
                            'Could not find the mixture named %s listed in the file %s.',...
                            mixtureStrings{i},obj.mixtureFilename)
                    end
                end

                % Create stimulus bath doc and add to database
                docs{e} = createBathDoc(obj, stimulatorid, epochids{e}, ...
                    bathtargetStrings, mixtureStrings,'Overwrite',options.Overwrite);
                
                % Update progress bar
                progressBar = progressBar.updateBar('stimulusbath',e/numel(epochInd));
            end
        end % TABLE2BATHDOCS

        function docs = createApproachDoc(obj, stimulator_id, epoch_id, approachStrings, options)
            %CREATEAPPROACHDOC Creates and adds NDI 'openminds' documents to the session database.
            %   Constructs one or more 'openminds' NDI documents for a specific
            %   stimulator and epoch, based on provided approach name(s).
            %
            %   Inputs:
            %       obj: An instance of the stimulusDocMaker class.
            %       stimulatorid: The NDI element ID of the stimulator device.
            %       epochid: The NDI epoch ID for which the document is being created.
            %       approachStrings: A character vector or a cell array of character
            %                          vectors specifying the approach name(s).
            %
            %   Optional Name-Value Arguments:
            %       Overwrite: A flag intended to control whether existing documents 
            %                       should be overwritten. Default: false.
            %
            %   Outputs:
            %       docs: A cell array containing the newly created 'openminds' NDI document
            %             object(s). A separate document is created for each distinct location
            %             associated with the provided 'approachStrings'.
            %
            %   See also: NDI.DATABASE.FUN.NDICLOUD_ONTOLOGY_LOOKUP,
            
            % Input argument validation
            arguments
                obj
                stimulator_id (1,:) char
                epoch_id (1,:) char
                approachStrings {mustBeText}
                options.Overwrite (1,1) logical = false;
            end

            % Ensure approach Strings is a cell array
            approachStrings = cellstr(approachStrings);

            % --- Create and Add Documents ---
            docs = cell(size(approachStrings)); % Initialize output cell array
            for a = 1:numel(approachStrings)

                % Get approach id and description
                [ontologyNode,ontologyLabel,NameOfOntology,OntologyDescription] = ndi.ontology.lookup(approachStrings{a});
                if isempty(ontologyNode)
                    error('STIMULUSDOCMAKER:InvalidApproachString',...
                        '%s is not a valid approach name.',approachStrings{a})
                end

                % Check if document already exists, if so, skip or remove
                % from database if overwriting
                q_e = ndi.query('epochid.epochid','exact_string',epoch_id);
                q_a = ndi.query('openminds.fields.name','exact_string',approachStrings{a});
                old_docs = obj.session.database_search(q_e & q_a);
                if options.Overwrite
                    % If overwriting, delete
                    for i = 1:numel(old_docs)
                        obj.session.database_rm(old_docs{i});
                    end
                else
                    % If not overwriting, grab doc (if available)
                    if ~isempty(old_docs)
                        docs{a} = old_docs;
                        continue
                    end
                end

                % Create stimulus approach document
                new_approach = openminds.controlledterms.StimulationApproach(...
                    'name',ontologyLabel,...
                    'preferredOntologyIdentifier',ontologyNode,...
                    'description',OntologyDescription);
                current_doc = ndi.database.fun.openMINDSobj2ndi_document(new_approach,...
                    obj.session.id,'stimulus',stimulator_id,'epochid.epochid', epoch_id);

                % Add document to list
                docs{a} = current_doc;

                % Add stimulus approach document to database
                obj.session.database_add(current_doc);
            end
        end % CREATEAPPROACHDOCS

        function docs = table2approachDocs(obj, variableTable, approachVariable, options)
            %TABLE2APPROACHDOCS Converts rows in a table into stimulus approach documents via CREATEAPPROACHDOCS.
            %   Processes a MATLAB table where rows represent experimental epochs.
            %   For each valid epoch row, it extracts filename and approach
            %   information, then calls `createApproachDoc` to generate and add
            %   the corresponding 'stimulus_approach' NDI document(s) to the database.
            %
            %   Inputs:
            %       obj: An instance of the stimulusDocMaker class.
            %       variableTable: A MATLAB table. Rows usually correspond to epochs.
            %                      Columns specified by `BathVariable`,
            %                      `MixtureVariable`, and `options.FilenameVariable`
            %                       are used if they exist.
            %       approachVariable: The name of the column in 'variableTable'
            %                      containing the bath target string(s).
            %                      If the column doesn't exist, this value is used as a fixed
            %                      approach name string for all processed epochs.
            %
            %   Optional Name-Value Arguments:
            %       FilenameVariable: The name of the column in 'variableTable'
            %                      containing the filename for each epoch, used to derive
            %                      the NDI 'epochid'. If empty or not provided, defaults 
            %                      to using the table's 'RowNames'.
            %       NonNaNVariableNames: Variable names in 'variableTable'. Values in 
            %                      these columns must not be NaN for a valid epoch.
            %                      Default: {} (assumes all rows are valid epochs).
            %       Overwrite: A flag intended to control whether existing documents 
            %                      should be overwritten. Default: false.
            %
            %   Outputs:
            %       docs: A cell array where each cell corresponds to an input epoch row
            %             processed. Each cell contains another cell array holding the
            %             'stimulus_approach' NDI document object(s) created for that epoch 
            %             by `createApproachDoc`.
            
            arguments
                obj
                variableTable table
                approachVariable (1,:) char
                options.FilenameVariable (1,:) char = ''
                options.NonNaNVariableNames {mustBeText} = {}
                options.Overwrite (1,1) logical = false
            end

            % Create progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label','Creating Stimulus Approach Document(s)','Tag','stimulusapproach');

            % If no FilenameVariable specified, use 'RowNames' of VariableTable
            if isempty(options.FilenameVariable)
                variableTable.Filename = variableTable.Properties.RowNames;
                options.FilenameVariable = 'Filename';
            end

            % Get valid epoch rows
            epochInd = find(ndi.fun.table.identifyValidRows(variableTable,options.NonNaNVariableNames));

            % Get epoch ids from data file names
            filenames = variableTable.(options.FilenameVariable)(epochInd);
            epochids = ndi.fun.epoch.filename2epochid(obj.session,filenames);

            % Get stimulator elements associated with the epochids
            stims = ndi.fun.epoch.epochid2element(obj.session,epochids,'type','stimulator');

            docs = cell(size(epochInd)); % Initialize output cell array
            for e = 1:numel(epochInd)

                % Get approach name string
                if any(strcmpi(fieldnames(variableTable),approachVariable))
                    approachStrings = variableTable.(approachVariable){epochInd(e)};
                else
                    approachStrings = approachVariable;
                end

                % Skip if no approach for this epoch
                if ~isempty(approachStrings) | isnan(approachStrings)

                    % Get stimulator id associated to the epochid
                    stim = stims{e};
                    if isempty(stim)
                        error('STIMULUSDOCMAKER:MissingStimulator',...
                            'No stimulator found in the session.')
                    elseif iscell(stim) & numel(stim) > 1
                        error('STIMULUSDOCMAKER:SeveralStimulators',...
                            'More than one stimulator found in the session.')
                    elseif iscell(stim) & isscalar(stim)
                        stim = stim{1};
                    end
                    stimulatorid = stim.id;

                    % Create stimulus approach doc and add to database
                    docs{e} = createApproachDoc(obj, stimulatorid, epochids{e}, ...
                        approachStrings, 'Overwrite',options.Overwrite);
                end

                % Update progress bar
                progressBar = progressBar.updateBar('stimulusapproach',e/numel(epochInd));
            end
        end % TABLE2APPROACHDOCS
    end
end