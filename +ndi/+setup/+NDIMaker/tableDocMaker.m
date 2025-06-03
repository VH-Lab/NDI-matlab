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
        function obj = tableDocMaker(session, labName)
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

        function doc = createOntologyTableRowDoc(obj, tableRow, identifyingVariables, options)
            %CREATEONTOLOGYTABLEROWDOC Creates a single NDI 'ontologyTableRow' document for a row of table data.
            %   DOC = CREATEONTOLOGYTABLEROWDOC(OBJ, TABLEROW, IDENTIFYINGVARIABLES, OPTIONS)
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
            %     - 'variableNames': A comma-separated string of full short/code names.
            %     - 'ontologyNodes': A comma-separated string of full ontology IDs (e.g., "PREFIX:ID").
            %     - 'data': A struct where field names are the 'variableNames' (shortName)
            %               obtained from the ontology lookup, and values are the
            %               corresponding data from the input 'tableRow'.
            %
            %   Inputs:
            %       obj: An instance of the tableDocMaker class. It must have the
            %                 'variableMapStruct' property initialized, mapping table variable
            %                 names to ontology term identifiers, and a valid 'session' property.
            %       tableRow: A 1xN MATLAB table representing a single row of data.
            %                 The variable names (column headers) of this table are used
            %                 for mapping to ontology terms.
            %       identifyingVariables: A string, char array, or cellstr array of
            %                 variable names present in 'tableRow'. These variables
            %                 and their corresponding values in 'tableRow' are used
            %                 to query for an existing 'ontologyTableRow' document.
            %                 The combination of these variable values should
            %                 form a unique identifier for the row's data context.
            %
            %   Optional Name-Value Arguments:
            %       Overwrite: Controls behavior if a document matching the 'identifyingVariables' is found:
            %                          - true: The existing document is removed, and a new one is created.
            %                          - false (default): The existing document is returned, and no
            %                                           new document is created.
            %
            %   Outputs:
            %       doc: The NDI document object (ndi.document) of type 'ontologyTableRow'.
            %            This will be the newly created document or the existing document
            %            if found and 'options.Overwrite' is false.
            %
            %   See also: ndi.ontology.lookup, ndi.document, ndi.query, tableDocMaker.table2ontologyTableRowDocs

            arguments
                obj
                tableRow (1,:) table % Input is a single table row
                identifyingVariables {mustBeText}
                options.Overwrite (1,1) logical = false
            end

            % Ensure identifyingVariables is a cell array
            identifyingVariables = cellstr(identifyingVariables);

            % Search for existing document(s)
            % query = ndi.query('','isa','ontologyTableRow'); % Document type
            % for i = 1:numel(identifyingVariables)
            %     termName = obj.variableMapStruct.(identifyingVariables{i});
            %     [~,~,~,~,~,shortName] = ndi.ontology.lookup(termName);
            %     query = query & ndi.query(['ontologyTableRow.data.',shortName],...
            %         'exact_string',tableRow.(identifyingVariables{i}));
            % end
            % doc_old = obj.session.database_search(query);

            % % Remove old document(s) if overwriting
            % if isscalar(doc_old)
            %     if options.Overwrite
            %         obj.session.database_rm(doc_old{1});
            %     else
            %         doc = doc_old{1};
            %         return;
            %     end
            % elseif numel(doc_old) > 1
            %     error('tableDocMaker:createOntologyTableRowDoc:NonUniqueFile',...
            %         'The identifying variables %s do not return a unique document',...
            %         join(identifyingVariables,','))
            %     % NOTE: We should have a way to tell the difference between
            %     % duplicate table rows and those that require additional
            %     % identifying variables to distinguish between them
            % end

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
                variableNames{end+1} = shortName;
                ontologyNodes{end+1} = id;
                data.(shortName) = tableRow.(varNames{i});
            end

            % Convert names, shortNames, and ids to comma-seperated char arrays
            names = join(names,','); names = names{1};
            variableNames = join(variableNames,','); variableNames = variableNames{1};
            ontologyNodes = join(ontologyNodes,','); ontologyNodes = ontologyNodes{1};

            % Compile ontologyTableRow struct
            ontologyTableRow = struct('names',names,'variableNames',variableNames,...
                'ontologyNodes',ontologyNodes,'data',data);

            % Create ontologyTableRow doument
            doc = ndi.document('ontologyTableRow','ontologyTableRow',ontologyTableRow) + ...
                obj.session.newdocument();

            % Add document to database
            obj.session.database_add(doc);

        end % createOntologyTableRowDoc

        function docs = table2ontologyTableRowDocs(obj, dataTable, identifyingVariables, options)
            %TABLE2ONTOLOGYTABLEROWDOCS Converts each row in a table into an NDI 'ontologyTableRow' document.
            %   DOCS = TABLE2ONTOLOGYTABLEROWDOCS(OBJ, DATATABLE, IDENTIFYINGVARIABLES, OPTIONS)
            %
            %   This method iterates through each row of the input 'dataTable'.
            %   For each row, it calls `obj.createOntologyTableRowDoc` to generate
            %   an NDI document of type 'ontologyTableRow'. The resulting documents
            %   are collected into a cell array.
            %
            %   Inputs:
            %       obj: An instance of the tableDocMaker class.
            %       dataTable: A MATLAB table. Each row will be processed to create
            %                  an 'ontologyTableRow' document.
            %       identifyingVariables: A string, char array, or cellstr array of
            %                  variable names present in 'dataTable'. This is
            %                  passed directly to `createOntologyTableRowDoc`
            %                  for each row to identify potentially existing documents.
            %   Optional Name-Value Arguments:
            %       Overwrite: Flag passed directly to `createOntologyTableRowDoc`.
            %                  Controls whether existing documents matching the
            %                  'identifyingVariables' for a given row should be
            %                  overwritten. Default: false.
            %
            %   Outputs:
            %       docs: A cell array with the same number of rows as 'dataTable'.
            %             Each cell contains the NDI document object (ndi.document)
            %             created by `createOntologyTableRowDoc` for the corresponding row.
            %
            %   See also: tableDocMaker.createOntologyTableRowDoc, ndi.gui.component.ProgressBarWindow

            arguments
                obj
                dataTable table
                identifyingVariables {mustBeText}
                options.Overwrite (1,1) logical = false
            end

            % Create progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label','Creating Ontology Table Row Document(s)','Tag','ontologyTableRow');

            docs = cell(height(dataTable),1); % Initialize output cell array
            for i = 1:height(dataTable)

                % Create onotologyTableRowDoc
                docs{i} = createOntologyTableRowDoc(obj, dataTable(i,:), ...
                        identifyingVariables,'Overwrite',options.Overwrite);

                % Update progress bar
                progressBar = progressBar.updateBar('ontologyTableRow',i/height(dataTable));
            end

        end % table2ontologyTableRowDocs

    end % methods
end % classdef tableDocMaker