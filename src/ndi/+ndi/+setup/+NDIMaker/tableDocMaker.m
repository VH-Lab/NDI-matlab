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
            
            obj.variableMapFilename = fullfile(labFolder,'tableDoc_dictionary.json');
            if ~isfile(obj.variableMapFilename)
                variableMapFilename = which(fullfile('+ndi','+setup',...
                    '+conv',['+',labName],'tableDoc_dictionary.json'));
                if isfile(variableMapFilename)
                    obj.variableMapFilename = variableMapFilename;
                else
                    error('tableDocMaker:VariableMapFileNotFound',...
                        'Variable map dictionary file not found: %s',...
                        obj.variableMapFilename);
                end
            end
            try
                obj.variableMapStruct = jsondecode(fileread(obj.variableMapFilename));
            catch ME
                error('tableDocMaker:VariableMapFileInvalidJSON',...
                    'Failed to decode JSON from variable map dictionary file: %s. Error: %s',...
                    obj.variableMapFilename, ME.message);
            end
        end % constructor tableDocMaker

        function [doc,inDatabase] = createOntologyTableRowDoc(obj, tableRow, identifyingVariables, options)
            %CREATEONTOLOGYTABLEROWDOC Creates a single NDI 'ontologyTableRow' document for a row of table data.
            %   DOC = CREATEONTOLOGYTABLEROWDOC(OBJ, TABLEROW, IDENTIFYINGVARIABLES, OPTIONS)
            %
            %   This method constructs an NDI document that links the data fields
            %   from a single table row to ontology terms. The mapping from the
            %   table's variable names (column headers) to ontology term identifiers
            %   (e.g., "PREFIX:TermNameOrID") is performed using the 'obj.variableMapStruct'.
            %
            %   If identifyingVariables is provided, the method searches the database 
            %   to see if a matching document already exists. If identifyingVariables 
            %   is empty, the search is skipped and a new document is prepared.
            %
            %   The created NDI document is of type 'ontologyTableRow' and contains:
            %     - 'names': A comma-separated string of full ontology term names.
            %     - 'variableNames': A comma-separated string of full short/code names.
            %     - 'ontologyNodes': A comma-separated string of full ontology IDs.
            %     - 'data': A struct where field names are the 'variableNames' (shortName)
            %               obtained from the ontology lookup, and values are the
            %               corresponding data from the input 'tableRow'.
            %
            %   Inputs:
            %       obj: An instance of the tableDocMaker class.
            %       tableRow: A 1xN MATLAB table representing a single row of data.
            %       identifyingVariables: A string, char array, or cellstr array of
            %                 variable names present in 'tableRow'. If empty, 
            %                 no database search for existing documents is performed.
            %
            %   Optional Name-Value Arguments:
            %       dependencyVariable: Variable(s) used to establish NDI document dependencies.
            %       Overwrite: Controls behavior if a document matching the 'identifyingVariables' is found:
            %                   - true: The existing document is removed.
            %                   - false (default): The existing document is returned.
            %       OldDocs: A cell array of existing documents matching identifying variables.
            %                Used for batch speed optimization.
            %
            %   Outputs:
            %       doc: The NDI document object (ndi.document) of type 'ontologyTableRow'.
            %       inDatabase: Flag reporting whether the document already
            %            exists in the database and Overwrite is false.
            %
            %   See also: ndi.ontology.lookup, ndi.document, ndi.query, tableDocMaker.table2ontologyTableRowDocs
            arguments
                obj
                tableRow (1,:) table
                identifyingVariables {mustBeText} = ''
                options.dependencyVariable {mustBeText} = ''
                options.Overwrite (1,1) logical = false
                options.OldDocs cell = {NaN}
            end
            
            % Normalize identifyingVariables
            if isempty(identifyingVariables) || isequal(identifyingVariables, '')
                identifyingVariables = {};
            else
                identifyingVariables = cellstr(identifyingVariables);
            end
            dependencyVariable = cellstr(options.dependencyVariable);

            % Search for existing document(s) only if identifying variables are provided
            doc_old = {};
            if ~isempty(identifyingVariables)
                if ~isnan(options.OldDocs{1}) && isa(options.OldDocs{1}, 'ndi.document')
                    doc_old = options.OldDocs;
                elseif isnan(options.OldDocs{1})
                    % Perform a live database search
                    query = ndi.query('','isa','ontologyTableRow');
                    for i = 1:numel(identifyingVariables)
                        termName = obj.variableMapStruct.(identifyingVariables{i});
                        [~,~,~,~,~,shortName] = ndi.ontology.lookup(termName);
                        query = query & ndi.query(['ontologyTableRow.data.',shortName],...
                            'exact_string',tableRow.(identifyingVariables{i}));
                    end
                    doc_old = obj.session.database_search(query);
                end
            end

            % Remove duplicates from database if found
            if numel(doc_old) > 1
                for i = 2:length(doc_old)
                    if isequaln(doc_old{1}.document_properties.ontologyTableRow.data,...
                            doc_old{i}.document_properties.ontologyTableRow.data)
                        obj.session.database_rm(doc_old{i});
                    else
                        error('tableDocMaker:createOntologyTableRowDoc:NonUniqueFile',...
                            'The identifying variables %s do not return a unique document',...
                            join(identifyingVariables,','))
                    end
                end
            end

            % Handle existing document logic
            inDatabase = false;
            if isscalar(doc_old) && isa(doc_old{1}, 'ndi.document')
                if options.Overwrite
                    obj.session.database_rm(doc_old{1});
                else
                    doc = doc_old{1};
                    inDatabase = true;
                    return;
                end
            end

            % Get variable (column) names from table and filter out dependencies
            varNames = tableRow.Properties.VariableNames;
            varNames(ismember(varNames,dependencyVariable)) = [];
            
            % Initialize ontologyTableRow field names
            names = cell(numel(varNames),1); 
            variableNames = cell(numel(varNames),1);
            ontologyNodes = cell(numel(varNames),1); 
            data = struct();
            invalidInd = false(numel(varNames),1);
            
            for i = 1:numel(varNames)
                % Map variable name to ontology term
                try
                    termName = obj.variableMapStruct.(varNames{i});
                catch ME
                    if strcmpi(ME.identifier,'MATLAB:nonExistentField')
                        warning(ME.identifier,'%s Skipping.',ME.message)
                        invalidInd(i) = true;
                        continue
                    else
                        rethrow(ME)
                    end
                end
                
                % Lookup term from ontology
                [ontologyNodes{i},names{i},~,~,~,variableNames{i}] = ndi.ontology.lookup(termName);
                
                % Unpack data values
                value = tableRow.(varNames{i});
                if iscell(value)
                    if isscalar(value)
                        value = value{1};
                    else
                        error('tableDocMaker:TableValueIsCellArray',...
                            'A table cell can only contain a single value for variable: %s',varNames{i});
                    end
                end
                data.(variableNames{i}) = value;
            end
            
            % Clean up empty fields
            names(invalidInd) = []; variableNames(invalidInd) = []; ontologyNodes(invalidInd) = [];
            names = join(names,','); names = names{1};
            variableNames = join(variableNames,','); variableNames = variableNames{1};
            ontologyNodes = join(ontologyNodes,','); ontologyNodes = ontologyNodes{1};
            
            % Compile NDI document
            ontologyTableRow = struct('names',names,'variableNames',variableNames,...
                'ontologyNodes',ontologyNodes,'data',data);
            
            doc = ndi.document('ontologyTableRow','ontologyTableRow',ontologyTableRow) + ...
                obj.session.newdocument();
                
            % Add dependency logic
            if ~isempty(dependencyVariable) && ~isequal(dependencyVariable,{''})
                values = tableRow{:,dependencyVariable};
                for d = 1:numel(values)
                    value = values{d};
                    if iscell(value), value = value{1}; end
                    if isscalar(values)
                        doc = doc.set_dependency_value('document_id',value);
                    else
                        doc = doc.add_dependency_value_n('document_id',value);
                    end
                end
            end
        end % createOntologyTableRowDoc

        function docs = table2ontologyTableRowDocs(obj, dataTable, identifyingVariables, options)
            %TABLE2ONTOLOGYTABLEROWDOCS Converts each row in a table into an NDI 'ontologyTableRow' document.
            %   DOCS = TABLE2ONTOLOGYTABLEROWDOCS(OBJ, DATATABLE, IDENTIFYINGVARIABLES, OPTIONS)
            %
            %   This method iterates through each row of the input 'dataTable'.
            %   For each row, it calls `obj.createOntologyTableRowDoc`.
            %
            %   Inputs:
            %       obj: An instance of the tableDocMaker class.
            %       dataTable: A MATLAB table where each row becomes a document.
            %       identifyingVariables: Variable names to identify existing docs.
            %                             If empty, every row generates a new document.
            %
            %   Optional Name-Value Arguments:
            %       dependencyVariable: Variable(s) for document dependencies.
            %       Overwrite: Flag to overwrite existing documents. Default: false.
            %
            %   Outputs:
            %       docs: A cell array of the created or found NDI documents.
            %
            %   See also: tableDocMaker.createOntologyTableRowDoc, ndi.gui.component.ProgressBarWindow
            arguments
                obj
                dataTable table
                identifyingVariables {mustBeText} = ''
                options.dependencyVariable {mustBeText} = ''
                options.Overwrite (1,1) logical = false
            end
            
            % Progress bar
            progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);
            progressBar = progressBar.addBar('Label','Creating Ontology Table Row Document(s)',...
                'Tag','ontologyTableRow');
            
            docs = cell(height(dataTable),1);
            inDatabase = false(height(dataTable),1);
            onePercent = ceil(height(dataTable)/100);

            % Pre-caching logic (only if identifying variables are provided)
            old_docs = {};
            if ~isempty(identifyingVariables) && ~isequal(identifyingVariables, '')
                identifyingVariables = cellstr(identifyingVariables);
                query = ndi.query('','isa','ontologyTableRow');
                all_found = obj.session.database_search(query);
                
                % Filter docs that contain the necessary identification fields
                ind = true(size(all_found));
                shortNames = cell(size(identifyingVariables));
                for j = 1:numel(identifyingVariables)
                    termName = obj.variableMapStruct.(identifyingVariables{j});
                    [~,~,~,~,~,shortNames{j}] = ndi.ontology.lookup(termName);
                    ind = ind & cellfun(@(d) isfield(d.document_properties.ontologyTableRow.data,shortNames{j}),all_found);
                end
                old_docs = all_found(ind);
                
                if ~isempty(old_docs)
                    variableData = cell(numel(old_docs),numel(shortNames));
                    for j = 1:numel(shortNames)
                        variableData(:,j) = cellfun(@(d) d.document_properties.ontologyTableRow.data.(shortNames{j}),...
                            old_docs,'UniformOutput',false);
                    end
                    variableTable = array2table(variableData,'VariableNames',shortNames);
                end
            end
            
            for i = 1:height(dataTable)
                % Filter pre-cached documents for matches
                RowOldDocs = {NaN};
                if ~isempty(old_docs)
                    matchIdx = true(height(variableTable),1);
                    for j = 1:numel(identifyingVariables)
                        val = dataTable{i,identifyingVariables{j}};
                        if isnumeric(val)
                            matchIdx = matchIdx & cell2mat(variableTable.(shortNames{j})) == val;
                        else
                            matchIdx = matchIdx & strcmpi(variableTable.(shortNames{j}), val);
                        end
                    end
                    RowOldDocs = old_docs(matchIdx);
                    if isempty(RowOldDocs), RowOldDocs = {NaN}; end
                end

                [docs{i},inDatabase(i)] = obj.createOntologyTableRowDoc(dataTable(i,:), ...
                    identifyingVariables, 'Overwrite', options.Overwrite, ...
                    'dependencyVariable', options.dependencyVariable, 'OldDocs', RowOldDocs);

                if mod(i,onePercent)==1 || onePercent == 1
                    progressBar = progressBar.updateBar('ontologyTableRow',i/height(dataTable));
                end
            end
            
            % Batch add only the documents that aren't already in the database
            obj.session.database_add(docs(~inDatabase));
            progressBar.updateBar('ontologyTableRow',1);
        end % table2ontologyTableRowDocs
    end % methods
end % classdef