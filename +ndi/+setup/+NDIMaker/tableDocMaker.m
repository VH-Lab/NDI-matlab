% file: +ndi/+setup/+NDIMaker/treatmentMaker.m
classdef treatmentMaker < handle
%TREATMENTMAKER A class for creating and managing NDI treatment documents.
%   Provides methods to generate treatment information from tables, create
%   NDI treatment documents, and manage them within NDI sessions.

    properties
        % No public properties are defined for this class.
    end

    methods
        function obj = treatmentMaker()
            %TREATMENTMAKER - Construct an instance of the treatmentMaker class.
            %
            %   OBJ = NDI.SETUP.NDIMAKER.TREATMENTMAKER()
            %
            %   Creates a new treatmentMaker object.
            %
        end

        function treatmentInfoTable = getTreatmentInfoFromTable(obj, dataTable, treatmentCreator)
            %GETTREATMENTINFOFROMTABLE Generates a standardized treatment table from a data table.
            %
            %   TREATMENTINFOTABLE = GETTREATMENTINFOFROMTABLE(OBJ, DATATABLE, TREATMENTCREATOR)
            %
            %   This method uses a TreatmentCreator object to process a general data table
            %   and produce a standardized table formatted for creating NDI treatment documents.
            %
            %   Inputs:
            %       obj (ndi.setup.NDIMaker.treatmentMaker) - The instance of this class.
            %       dataTable (table) - A MATLAB table with raw metadata.
            %       treatmentCreator (ndi.setup.NDIMaker.TreatmentCreator) - An object that
            %           implements the logic to convert the dataTable into the treatmentInfoTable.
            %
            %   Outputs:
            %       treatmentInfoTable (table) - A standardized table ready for document creation.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.treatmentMaker
                dataTable table
                treatmentCreator (1,1) ndi.setup.NDIMaker.TreatmentCreator
            end
            treatmentInfoTable = treatmentCreator.create(dataTable);
        end

        function [docs_to_add, report] = makeTreatmentDocuments(obj, S, treatmentTable)
            %MAKETREATMENTDOCUMENTS Creates NDI treatment documents from a table without adding them to the database.
            %
            %   [DOCS_TO_ADD, REPORT] = MAKETREATMENTDOCUMENTS(OBJ, S, TREATMENTTABLE)
            %
            %   This method iterates through a treatmentTable, creates the corresponding
            %   NDI documents, and returns them in a cell array. It does not add them
            %   to the session database.
            %
            %   Inputs:
            %       obj (ndi.setup.NDIMaker.treatmentMaker) - The instance of this class.
            %       S (ndi.session) - The NDI session object, used to find subject documents.
            %       treatmentTable (table) - A table of treatment information.
            %
            %   Outputs:
            %       docs_to_add (cell) - A cell array of the new ndi.document objects.
            %       report (struct) - A structure detailing which rows were processed successfully.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.treatmentMaker
                S (1,1) ndi.session
                treatmentTable table
            end

            [docs_to_add, report] = obj.process_treatment_table(S, treatmentTable);
        end

        function addTreatmentDocuments(obj, S, documentsToAdd)
            %ADDTREATMENTDOCUMENTS Adds a cell array of treatment documents to a session.
            %
            %   ADDTREATMENTDOCUMENTS(OBJ, S, DOCUMENTSTOADD)
            %
            %   Adds the provided ndi.document objects to the session's database.
            %
            %   Inputs:
            %       obj (ndi.setup.NDIMaker.treatmentMaker) - The instance of this class.
            %       S (ndi.session) - The NDI session to add documents to.
            %       documentsToAdd (cell) - A cell array of ndi.document objects.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.treatmentMaker
                S (1,1) ndi.session
                documentsToAdd (1,:) cell
            end
            if ~isempty(documentsToAdd)
                S.database_add(documentsToAdd);
            end
        end

        function [created_docs, report] = makeAndAddTreatmentDocuments(obj, S, treatmentTable, options)
            %MAKEANDADDTREATMENTDOCUMENTS - Create and add NDI treatment documents from a table.
            %
            %   [CREATED_DOCS, REPORT] = MAKEANDADDTREATMENTDOCUMENTS(OBJ, S, TREATMENTTABLE, ...)
            %
            %   This method is a convenience function that both creates and adds documents
            %   to the session in a single step.
            %
            %   Inputs:
            %       obj (ndi.setup.NDIMaker.treatmentMaker) - The instance of this class.
            %       S (ndi.session) - The NDI session object to which documents will be added.
            %       treatmentTable (table) - A table of treatment information.
            %
            %   Optional Name-Value Arguments:
            %       doAdd (logical) - If true (default), documents are added to the database.
            %
            %   Outputs:
            %       created_docs (cell) - A cell array of the new ndi.document objects.
            %       report (struct) - A structure detailing processing success and failures.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.treatmentMaker
                S (1,1) ndi.session
                treatmentTable table
                options.doAdd (1,1) logical = true
            end

            [created_docs, report] = obj.process_treatment_table(S, treatmentTable);

            if options.doAdd && ~isempty(created_docs)
                S.database_add(created_docs);
            end
        end

        function deletion_report = deleteTreatmentDocs(obj, sessionCellArray, treatmentsToDelete)
            %DELETETREATMENTDOCS Deletes treatment documents from sessions based on content.
            %
            %   DELETION_REPORT = DELETETREATMENTDOCS(OBJ, SESSIONCELLARRAY, TREATMENTSTODELETE)
            %
            %   This method searches for and deletes treatment documents based on their
            %   content, as specified in the `treatmentsToDelete` table.
            %
            %   Inputs:
            %       obj (ndi.setup.NDIMaker.treatmentMaker) - The instance of this class.
            %       sessionCellArray (cell) - A cell array of NDI session objects to search.
            %       treatmentsToDelete (table) - A table specifying which treatments to delete.
            %           It must contain 'subjectIdentifier' and 'treatmentType' columns.
            %           Additional columns corresponding to document properties are needed
            %           to uniquely identify the documents (e.g., 'treatment' for type 'treatment').
            %
            %   Outputs:
            %       deletion_report (struct) - A report detailing which documents were found
            %                                  and deleted in each session.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.treatmentMaker
                sessionCellArray (1,:) cell {ndi.validators.mustBeCellArrayOfNdiSessions(sessionCellArray)}
                treatmentsToDelete table
            end

            if isempty(treatmentsToDelete) || isempty(sessionCellArray)
                deletion_report = struct();
                return;
            end

            numSessions = numel(sessionCellArray);
            deletion_report = repmat(struct('session_id', '', 'session_reference', '', 'docs_found_ids', {{}}, 'docs_deleted_ids', {{}}, 'errors', {{}}), numSessions, 1);

            for s = 1:numSessions
                currentSession = sessionCellArray{s};
                deletion_report(s).session_id = currentSession.id();
                deletion_report(s).session_reference = currentSession.reference;
                
                all_docs_to_delete = {};

                subject_docs = currentSession.database_search(ndi.query('','isa','subject'));
                subject_map = containers.Map('KeyType','char','ValueType','char');
                for i=1:numel(subject_docs)
                    subject_map(subject_docs{i}.document_properties.subject.local_identifier) = subject_docs{i}.id();
                end

                for i = 1:height(treatmentsToDelete)
                    row = treatmentsToDelete(i,:);
                    subject_id_str = char(row.subjectIdentifier);

                    if ~isKey(subject_map, subject_id_str)
                        warning('Subject with identifier "%s" not found in session %s. Skipping deletion for this entry.', subject_id_str, currentSession.reference);
                        continue;
                    end
                    subject_doc_id = subject_map(subject_id_str);

                    treatmentType = char(row.treatmentType);
                    q_base = ndi.query('','isa',treatmentType) & ndi.query('','depends_on','subject_id', subject_doc_id);
                    
                    q_content = ndi.query('','depends_on','ndi_document.id','exact_string','-'); % empty query

                    switch lower(treatmentType)
                        case 'treatment'
                            if ismember('treatment', row.Properties.VariableNames)
                                q_content = ndi.query('treatment.ontologyName','exact_string', char(row.treatment));
                            end
                        case 'treatment_drug'
                            if ismember('location_ontologyNode', row.Properties.VariableNames)
                                q_content = ndi.query('treatment_drug.location_ontologyNode','exact_string', char(row.location_ontologyNode));
                            end
                        case 'treatment_virus'
                             if ismember('virus_OntologyName', row.Properties.VariableNames)
                                q_content = ndi.query('treatment_virus.virus_OntologyName','exact_string', char(row.virus_OntologyName));
                            end
                    end
                    
                    docs_found = currentSession.database_search(q_base & q_content);
                    all_docs_to_delete = cat(1, all_docs_to_delete, docs_found(:));
                end
                
                if ~isempty(all_docs_to_delete)
                    docs_found_ids = cellfun(@(d) d.id(), all_docs_to_delete, 'UniformOutput', false);
                    deletion_report(s).docs_found_ids = docs_found_ids;
                    currentSession.database_rm(docs_found_ids);
                    deletion_report(s).docs_deleted_ids = docs_found_ids;
                end
            end
        end

    end % public methods

    methods (Access = private)

        function [created_docs, report] = process_treatment_table(obj, S, treatmentTable)
            %PROCESS_TREATMENT_TABLE - Internal helper to create documents from a table.
            
            created_docs = {};
            report.success = logical([]);
            report.errors = {};

            % Step 1: Validate the input table has the base required columns
            base_req = {'treatmentType', 'treatment', 'stringValue', 'numericValue', 'subjectIdentifier', 'sessionPath'};
            ndi.validators.mustHaveRequiredColumns(treatmentTable, base_req);

            % Step 2: Efficiently map subject identifiers to NDI document IDs
            subject_docs = S.database_search(ndi.query('','isa','subject'));
            subject_map = containers.Map('KeyType','char','ValueType','char');
            for i=1:numel(subject_docs)
                subject_map(subject_docs{i}.document_properties.subject.local_identifier) = subject_docs{i}.id();
            end

            % Step 3: Iterate through the table and create documents
            for i=1:height(treatmentTable)
                row = treatmentTable(i,:);
                try
                    new_doc = obj.create_doc_from_row(S, row, subject_map);
                    if ~isempty(new_doc)
                        created_docs{end+1} = new_doc;
                    end
                    report.success(i) = true;
                    report.errors{i} = '';
                catch ME
                    report.success(i) = false;
                    report.errors{i} = ME.message;
                    warning('Failed to create document for row %d: %s', i, ME.message);
                end
            end
        end

        function doc = create_doc_from_row(obj, S, tableRow, subject_map)
            %CREATE_DOC_FROM_ROW - Private helper to create a single document from a table row.
            
            doc = [];
            subject_id_str = char(tableRow.subjectIdentifier);

            if ~isKey(subject_map, subject_id_str)
                error('Subject with identifier "%s" not found in the session.', subject_id_str);
            end
            subject_doc_id = subject_map(subject_id_str);

            treatmentType = char(tableRow.treatmentType);

            switch lower(treatmentType)
                case 'treatment'
                    doc = obj.create_treatment_doc(S, tableRow, subject_doc_id);
                case 'treatment_drug'
                    doc = obj.create_treatment_drug_doc(S, tableRow, subject_doc_id);
                case 'treatment_virus'
                    doc = obj.create_treatment_virus_doc(S, tableRow, subject_doc_id);
                otherwise
                    error('Unknown treatmentType: "%s". Must be "treatment", "treatment_drug", or "treatment_virus".', treatmentType);
            end
        end

        function doc = create_treatment_doc(~, S, tableRow, subject_doc_id)
            % Creates a standard 'treatment' document
            [id, name] = ndi.ontology.lookup(char(tableRow.treatment));
            if isempty(id)
                error('Could not find ontology entry for treatment: %s', char(tableRow.treatment));
            end
            
            treatment_struct.ontologyName = id;
            treatment_struct.name = name;
            treatment_struct.stringValue = char(tableRow.stringValue);
            treatment_struct.numeric_value = tableRow.numericValue;

            doc = S.newdocument('treatment', 'treatment', treatment_struct);
            doc = doc.set_dependency_value('subject_id', subject_doc_id);
        end

        function doc = create_treatment_drug_doc(~, S, tableRow, subject_doc_id)
            % Creates a 'treatment_drug' document
            req_cols = {'location_ontologyNode', 'location_name', 'mixture_table', ...
                        'administration_onset_time', 'administration_offset_time', 'administration_duration'};
            ndi.validators.mustHaveRequiredColumns(tableRow, req_cols);

            drug_struct.location_ontologyNode = char(tableRow.location_ontologyNode);
            drug_struct.location_name = char(tableRow.location_name);
            drug_struct.mixture_table = char(tableRow.mixture_table);
            drug_struct.administration_onset_time = char(tableRow.administration_onset_time);
            drug_struct.administration_offset_time = char(tableRow.administration_offset_time);
            drug_struct.administration_duration = tableRow.administration_duration;
            
            doc = S.newdocument('treatment_drug', 'treatment_drug', drug_struct);
            doc = doc.set_dependency_value('subject_id', subject_doc_id);
        end

        function doc = create_treatment_virus_doc(~, S, tableRow, subject_doc_id)
            % Creates a 'treatment_virus' document
            req_cols = {'virus_OntologyName', 'virus_name', 'virusLocation_OntologyName', 'virusLocation_name', ...
                        'virus_AdministrationDate', 'virus_AdministrationPND', 'dilution', ...
                        'diluent_OntologyName', 'diluent_name'};
            ndi.validators.mustHaveRequiredColumns(tableRow, req_cols);
            
            virus_struct.virus_OntologyName = char(tableRow.virus_OntologyName);
            virus_struct.virus_name = char(tableRow.virus_name);
            virus_struct.virusLocation_OntologyName = char(tableRow.virusLocation_OntologyName);
            virus_struct.virusLocation_name = char(tableRow.virusLocation_name);
            virus_struct.virus_AdministrationDate = char(tableRow.virus_AdministrationDate);
            virus_struct.virus_AdministrationPND = tableRow.virus_AdministrationPND;
            virus_struct.dilution = tableRow.dilution;
            virus_struct.diluent_OntologyName = char(tableRow.diluent_OntologyName);
            virus_struct.diluent_name = char(tableRow.diluent_name);

            doc = S.newdocument('treatment_virus', 'treatment_virus', virus_struct);
            doc = doc.set_dependency_value('subject_id', subject_doc_id);
        end

    end % private methods
end % classdef
