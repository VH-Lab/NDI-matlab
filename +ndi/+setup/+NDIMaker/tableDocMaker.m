% Folder: +ndi/+setup/+NDIMaker/
classdef tableDocMaker < handle
    %tableDocMaker Creates and manages NDI documents linking table row data to ontology terms.
    %   This class is responsible for generating NDI documents that associate
    %   data from rows of a table with specific ontology terms. It uses a
    %   mapping file (dictionary) to connect table variable names to ontology
    %   term identifiers (including their prefix).

    properties (Access = public)
        session                         % The NDI session object (e.g., ndi.session.dir or ndi.database.dir) where documents will be added.
        variableMapFilename (1,:) char  % Filename (including path) for the JSON dictionary file mapping table variable names to ontology term IDs (e.g., "PREFIX:TermNameOrID").
        variableMapStruct struct        % Structure loaded from 'variableMapFilename'.
    end

    methods
        function obj = tableDocMaker(session, labName, options)
            %TABLEDOCMAKER Constructor for this class.
            %   Initializes the tableDocMaker by loading a variable-to-ontology
            %   mapping dictionary file specific to the given labName and associating
            %   it with the provided NDI session.
            %
            %   Inputs:
            %       session: An NDI session object (e.g., an instance of
            %                ndi.session.dir or ndi.database.dir).
            %       labName: A character vector specifying the name of the lab.
            %                This is used to locate the ontology mapping dictionary file
            %                (e.g., 'labName_tableDoc_dictionary.json')
            %                in the 'NDI-MATLAB/+ndi/+setup/+conv/+labName' folder.
            %
            %   Outputs:
            %       obj: An instance of the tableDocMaker class.
            %
            %   Example:
            %       session = ndi.session.dir('/path/to/my/session');
            %       labName = 'myLab';
            %       docMaker = ndi.setup.NDIMaker.tableDocMaker(session, labName);

            arguments
                session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
                labName (1,:) char
            end

            obj.session = session;

            % Construct the path to the lab-specific variable mapping dictionary file
            labFolder = fullfile(ndi.common.PathConstants.RootFolder,...
                '+ndi','+setup','+conv',['+',labName]);
            
            obj.variableMapFilename = fullfile(labFolder,[labName,'_tableDoc_dictionary.json']); % UPDATED FILENAME
            if ~isfile(obj.variableMapFilename)
                error('tableDocMaker:VariableMapFileNotFound', 'Variable map dictionary file not found: %s', obj.variableMapFilename);
            end
            try
                obj.variableMapStruct = jsondecode(fileread(obj.variableMapFilename));
            catch ME
                error('tableDocMaker:VariableMapFileInvalidJSON', 'Failed to decode JSON from variable map dictionary file: %s. Error: %s', obj.variableMapFilename, ME.message);
            end
        end % constructor tableDocMaker

        function doc = createOntologyTableRowDoc(obj, tableRow, dependencies, options)
            %CREATEONTOLOGYTABLEROWDOC Creates a single NDI 'ontologyTableRow' document for a row of table data.
            %   DOC = CREATEONTOLOGYTABLEROWDOC(OBJ, TABLEROW, DEPENDENCIES, OPTIONS)
            %
            %   This method constructs an NDI document that links the data fields
            %   from a single table row to ontology terms. The mapping from the
            %   table's variable names (column headers) to ontology term identifiers
            %   (e.g., "PREFIX:TermNameOrID") is performed using the 'obj.variableMapStruct'
            %   loaded during the tableDocMaker's construction. Full ontology term
            %   details (ID, name, prefix, shortName/codeName) are retrieved using
            %   ndi.ontology.lookup.
            %
            %   The created NDI document is of type 'ontologyTableRow' and contains:
            %     - 'names': A comma-separated string of full ontology term names.
            %     - 'variableNames': A comma-separated string, intended for short/code names,
            %                        but currently populated with full ontology term names
            %                        based on the existing code logic.
            %     - 'ontologyNodes': A comma-separated string of full ontology IDs (e.g., "PREFIX:ID").
            %     - 'data': A struct where field names are the 'shortName' (codeName)
            %               obtained from the ontology lookup, and values are the
            %               corresponding data from the input 'tableRow'.
            %   The document is associated with NDI dependencies specified in the
            %   'dependencies' argument.
            %
            %   Inputs:
            %       obj: An instance of the tableDocMaker class.
            %       tableRow: A 1xN MATLAB table representing a single row of data.
            %                 The variable names (column headers) of this table are used
            %                 for mapping to ontology terms via 'obj.variableMapStruct'.
            %       dependencies: (Optional) A scalar struct specifying NDI dependencies.
            %                     Field names of this struct are the dependency names
            %                     (e.g., 'epochid', 'stimulator_element_id'), and the
            %                     values are the corresponding NDI IDs (char arrays).
            %                     Default: empty struct (no explicit dependencies added
            %                     beyond session defaults, though the document structure
            %                     itself might imply an epoch if 'epochid' is a dependency).
            %       options.Overwrite: (logical) Flag to control whether existing documents
            %                          that match the specified dependencies (currently a simplified
            %                          match based on the first dependency) should be overwritten.
            %                          Default: false.
            %
            %   Outputs:
            %       doc: The newly created (or existing, if not overwriting and found)
            %            NDI document object of type 'ontologyTableRow'.
            %
            %   See also: ndi.ontology.lookup, jsondecode, table2struct

            arguments
                obj
                tableRow (1,:) table % Input is a single table row
                dependencies (1,1) struct
                options.Overwrite (1,1) logical = false
            end

            % Get dependency names
            dependencyNames = fieldnames(dependencies);

            % Search for existing document(s)
            query = ndi.query('','isa','ontologyTableRow'); % Document type
            for i = 1:numel(dependencyNames)
                query = query & ndi.query('','depends_on',dependencyNames{i},...
                    dependencies.(dependencyNames{i}));
            end
            doc_old = obj.session.database_search(query);

            % Remove old document(s) if overwriting
            if ~isempty(doc_old)
                if options.Overwrite
                    for i = 1:numel(doc_old)
                        obj.session.database_rm(doc_old{i});
                    end
                else
                    doc = doc_old{1};
                    return;
                end
            end

            % Get variable (column) names from table
            varNames = tableRow.Properties.VariableNames;

            % Initialize ontologyTableRow field names
            names = {}; variableNames = {}; ontologyNodes = {}; data = struct();
            for i = 1:numel(varNames)

                % Map variable name to ontology term given variableMapStruct
                try
                    termName = obj.variableMapStruct.(varNames{i});
                catch ME
                    if strcmpi(ME.identifier,'MATLAB:nonExistentField')
                        warning(ME.identifier,'%s Skipping.',ME.message)
                        continue
                    else
                        rethrow(ME)
                    end
                end

                % Lookup term from ontology
                [id,name,prefix,~,~,shortName] = ndi.ontology.lookup(termName);

                % Add values to field
                names{end+1} = name;
                variableNames{end+1} = name;
                ontologyNodes{end+1} = [prefix,':',id];
                data.(shortName) = tableRow.(varNames{i});
            end

            % Convert names, shortNames, and ids to comma-seperated char arrays
            names = join(names,','); names = names{1};
            variableNames = join(variableNames,','); variableNames = variableNames{1};
            ontologyNodes = join(ontologyNodes,','); ontologyNodes = ontologyNodes{1};

            % Compile ontologyTableRow struct
            ontologyTableRow = struct('names',names,'variableNames',variableNames,...
                'ontologyNodes',ontologyNodes,'data',data);
            doc = ndi.document('ontologyTableRow','ontologyTableRow',ontologyTableRow) + ...
                obj.session.newdocument();
            
            % Add dependencies
            for i = 1:numel(dependencies)
                doc.set_dependency_value(dependencyNames{i},...
                    dependencies.(dependencyNames{i}));
            end

            % Add document to database
            obj.session.database_add(doc);

        end % createOntologyTableRowDoc

        function docs = table2ontologyTableRowDocs(obj, dataTable, options)
            %TABLE2ONTOLOGYTABLEROWDOCS Converts rows in a table into NDI documents.
            %   Processes a MATLAB table where each row represents a set of data
            %   (e.g., an experimental trial or epoch). For each valid row,
            %   it extracts the data and calls `createOntologyTableRowDoc` to
            %   generate and add the corresponding NDI document to the database.
            %
            %   Inputs:
            %       obj: An instance of the tableDocMaker class.
            %       dataTable: A MATLAB table. Each row is processed.
            %
            %   Optional Name-Value Arguments:
            %       FilenameVariable: (char) The name of the column in 'dataTable'
            %                         containing filenames used to derive NDI 'epochid'.
            %                         If empty, 'RowNames' of dataTable are used.
            %       StimulatorIDVariable: (char) The name of the column in 'dataTable'
            %                             containing the stimulator NDI element ID.
            %                             If empty or column not found, stimulator_id
            %                             will be passed as empty to createOntologyTableRowDoc.
            %       NonNaNVariableNames: (cellstr) Variable names in 'dataTable'.
            %                            Values in these columns must not be NaN for a
            %                            row to be considered a valid epoch.
            %                            Default: {} (all rows processed).
            %       Overwrite: (logical) Flag passed to createOntologyTableRowDoc
            %                  to control overwriting of existing documents. Default: false.
            %
            %   Outputs:
            %       docs: A cell array where each cell corresponds to a processed
            %                 input row from 'dataTable'. Each cell contains the NDI
            %                 document object created for that row.

            arguments
                obj
                dataTable table
                options.FilenameVariable (1,:) char = ''
                options.StimulatorIDVariable (1,:) char = ''
                options.NonNaNVariableNames cell = {}
                options.Overwrite (1,1) logical = false
            end

            % Create progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label','Creating Ontology Table Row Document(s)','Tag','ontologyTableRow');

            docs = cell(size(epochInd)); % Initialize output cell array

            for i = 1:height(dataTable)

                dependencies = struct(''); % FILL IN

                docs{i} = createOntologyTableRowDoc(obj, dataTable(i,:), ...
                        dependencies,'Overwrite',options.Overwrite);

                % Update progress bar
                progressBar = progressBar.updateBar('ontologyTableRow',i/height(dataTable));
            end

        end % table2ontologyTableRowDocs

    end % methods
end % classdef tableDocMaker