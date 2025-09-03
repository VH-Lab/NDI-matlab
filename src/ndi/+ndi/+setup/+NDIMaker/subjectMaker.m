% file: +ndi/+setup/+NDIMaker/subjectMaker.m
classdef subjectMaker < handle
%SUBJECTMAKER A helper class to extract subject information from tables and manage NDI subject documents.
%   Provides methods to facilitate the extraction of unique subject
%   information based on metadata in tables, and to manage NDI subject
%   documents (e.g., creation, addition to sessions, deletion).
%
%   This class acts as an orchestrator for a common NDI setup workflow:
%   1. Read a metadata table (e.g., from a spreadsheet).
%   2. Use a lab-specific 'creator' object to interpret the table and extract subject details.
%   3. Generate NDI documents for each unique subject and their related metadata (species, strain, etc.).
%   4. Add these new documents to the appropriate NDI session database.
%

    properties
        % No public properties are defined for this class.
    end

    methods
        function obj = subjectMaker()
            %SUBJECTMAKER Construct an instance of this class.
            %
            %   OBJ = NDI.SETUP.NDIMAKER.SUBJECTMAKER()
            %
            %   Creates an ndi.setup.NDIMaker.subjectMaker object. This constructor
            %   currently takes no arguments and initializes an empty object, ready
            %   to use its methods.
            %
        end

        function [subjectInfo, allSubjectNamesFromTable,subjectDocIDs] = addSubjectsFromTable(obj, session, dataTable, subjectInfoCreator)
            %ADDSUBJECTSFROMTABLE Processes a table to create and add subjects to a session.
            %
            %   [SUBJECTINFO, ALLSUBJECTNAMESFROMTABLE] = ADDSUBJECTSFROMTABLE(OBJ, SESSION, DATATABLE, SUBJECTINFOCREATOR)
            %
            %   This method provides a high-level workflow that encapsulates the entire process of
            %   importing subjects from a metadata table into an NDI session. It handles extracting
            %   unique subject information, creating the corresponding NDI documents, and adding
            %   those documents to the session's database.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The instance of this class.
            %       session (ndi.session.dir): The NDI session object where the subjects will be added.
            %       dataTable (table): A MATLAB table containing metadata to define subjects.
            %       subjectInfoCreator (ndi.setup.NDIMaker.SubjectInformationCreator): An object that
            %           encapsulates the lab-specific rules for converting a table row to subject information.
            %
            %   Returns:
            %       subjectInfo (struct): A structure array containing data for unique, valid subjects that were added.
            %                         See the documentation for `getSubjectInfoFromTable` for a detailed description
            %                         of the fields in this structure.
            %       allSubjectNamesFromTable (cell array): A cell array with one entry per row of
            %                         the input `dataTable`. Each entry is the subject name (char array)
            %                         or NaN returned by `subjectInfoCreator` for that row.
            %       subjectDocIDs (cell array): A cell array with one entry per row of the input 
            %                         `dataTable`. Each entry is thesubject document identifier 
            %                         for that row.                    
                
                % The subjectMaker requires a sessionID column to map subjects to sessions
                dataTable.sessionID(:) = {session.id()};

                disp('Extracting unique subject information from the table...');
                
                % 1. Extract unique subject information using the creator
                [subjectInfo, allSubjectNamesFromTable] = obj.getSubjectInfoFromTable(dataTable, subjectInfoCreator);

                if isempty(subjectInfo.subjectName)
                    disp('No valid subjects found to add.');
                    return;
                end

                disp(['Found ' num2str(numel(subjectInfo.subjectName)) ' unique subjects to process.']);

                % 2. Create NDI documents for the unique subjects
                disp('Creating NDI documents for subjects...');
                subDocStruct = obj.makeSubjectDocuments(subjectInfo);

                % 3. Add the new subject documents to the session
                disp('Adding new subject documents to the session database...');
                obj.addSubjectsToSessions({session}, subDocStruct.documents);

                % 4. Return subject document ids
                subjectDocIDs = cellfun(@(d) d{1}.id,subDocStruct.documents,'UniformOutput',false);
        end


        function [subjectInfo, allSubjectNamesFromTable] = getSubjectInfoFromTable(obj, dataTable, subjectInfoCreator)
            %GETSUBJECTINFOFROMTABLE Extracts unique subject information from a table using a creator object.
            %
            %   [SUBJECTINFO, ALLSUBJECTNAMESFROMTABLE] = GETSUBJECTINFOFROMTABLE(OBJ, DATATABLE, SUBJECTINFOCREATOR)
            %
            %   This is the core data extraction and transformation method. It processes each row of an input `dataTable` 
            %   using a user-provided "creator" function handle. This creator function contains the lab-specific logic 
            %   to interpret the columns of the table.
            %
            %   The method returns two main outputs:
            %   1. `subjectInfo`: A clean, de-duplicated structure of all *valid* subjects found in the table. A subject
            %      is considered valid if the creator function returns a non-empty name and the table row has a valid
            %      session ID.
            %   2. `allSubjectNamesFromTable`: A cell array that has a 1-to-1 mapping with the rows of the input `dataTable`.
            %      It contains the raw output (the generated name or NaN) from the creator function for every row, which is
            %      useful for later associating data back to the original table.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The instance of this class.
            %       dataTable (table): A MATLAB table containing metadata to define subjects. It MUST contain a column
            %                          named 'sessionID'.
            %       subjectInfoCreator (ndi.setup.NDIMaker.SubjectInformationCreator): An object that
            %           inherits from the abstract creator class and implements the `create` method. This object
            %           encapsulates the lab-specific rules for converting a table row to subject information.
            %
            %   Returns:
            %       subjectInfo (struct): A structure array containing data for unique, valid subjects.
            %                         It has the following fields, each being a cell array or vector
            %                         aligned by subject:
            %                         - subjectName (cell array): Unique subject identifiers (char arrays).
            %                         - strain (cell array): Corresponding openminds.core.research.Strain objects (or NaN).
            %                         - species (cell array): Corresponding openminds.controlledterms.Species objects (or NaN).
            %                         - biologicalSex (cell array): Corresponding openminds.controlledterms.BiologicalSex data (or NaN).
            %                         - tableRowIndex (numeric vector): The 1-based row index from the
            %                           original `dataTable` where this unique subject's information
            %                           was first successfully extracted.
            %                         - sessionID (cell array): The session identifier (char array)
            %                           associated with the row that generated the unique subject.
            %                         If no subjects meet the validity criteria, an empty struct
            %                         (with fields initialized as empty arrays) is returned.
            %       allSubjectNamesFromTable (cell array): A cell array with one entry per row of
            %                         the input `dataTable`. Each entry is the subject name (char array)
            %                         or NaN returned by `subjectInfoCreator` for that row.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                dataTable table {mustBeNonempty, ndi.validators.mustHaveRequiredColumns(dataTable, 'sessionID')}
                subjectInfoCreator (1,1) ndi.setup.NDIMaker.SubjectInformationCreator
            end

            numRows = height(dataTable);
            allSubjectNames = cell(numRows, 1);
            allStrains = cell(numRows, 1);
            allSpecies = cell(numRows, 1);
            allBiologicalSex = cell(numRows, 1);
            allSessionIDs = cell(numRows, 1);
            allSessionIDs(:) = {''};
            rawSessionIDs = dataTable.sessionID; % For a more robust NaN check

            for i = 1:numRows
                currentRow = dataTable(i, :);
                try
                    [local_id, strain_obj, species_obj, sex_obj] = subjectInfoCreator.create(currentRow);
                    allSubjectNames{i} = local_id;
                    allStrains{i} = strain_obj;
                    allSpecies{i} = species_obj;
                    allBiologicalSex{i} = sex_obj;
                    % Use the raw value for the validity check later
                    allSessionIDs{i} = char(ndi.util.unwrapTableCellContent(rawSessionIDs{i}));
                catch ME
                    warning('ndi:setup:NDIMaker:subjectMaker:subjectInfoFunError',...
                        'Error executing subjectInfoCreator for table row %d: %s. Skipping.', i, ME.message);
                    allSubjectNames{i} = NaN; % Ensure failure is marked
                end
            end
            
            allSubjectNamesFromTable = allSubjectNames;

            % Corrected Validity Checks
            isValidName = cellfun(@(x) ischar(x) && ~isempty(x), allSubjectNames);
            % A more robust check for sessionID validity
            isValidSessionID = cellfun(@(x) ischar(x) && ~isempty(x), allSessionIDs) & ~cellfun(@(x) isnumeric(x) && all(isnan(x(:))), rawSessionIDs);

            finalValidIndices = find(isValidName & isValidSessionID);
            
            if isempty(finalValidIndices)
                 subjectInfo = struct('subjectName',{{}},'strain',{{}},'species',{{}},...
                    'biologicalSex',{{}},'tableRowIndex',[],'sessionID',{{}});
                 return;
            end

            [uniqueNames, ia] = unique(allSubjectNames(finalValidIndices), 'stable');
            subjectInfo = struct(...
                'subjectName', {uniqueNames}, ...
                'strain', {allStrains(finalValidIndices(ia))}, ...
                'species', {allSpecies(finalValidIndices(ia))}, ...
                'biologicalSex', {allBiologicalSex(finalValidIndices(ia))}, ...
                'tableRowIndex', finalValidIndices(ia), ...
                'sessionID', {allSessionIDs(finalValidIndices(ia))} ...
            );
        end

        function output = makeSubjectDocuments(obj, subjectInfo, options)
            %MAKESUBJECTDOCUMENTS Creates NDI subject documents from a subjectInfo structure.
            %
            %   OUTPUT = MAKESUBJECTDOCUMENTS(OBJ, SUBJECTINFO, 'existingSubjectDocs', DOCS)
            %
            %   This method converts the clean `subjectInfo` structure (from `getSubjectInfoFromTable`)
            %   into a set of `ndi.document` objects ready to be added to a database.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The instance of this class.
            %       subjectInfo (struct): The structured data for unique subjects returned from `getSubjectInfoFromTable`.
            %       options.existingSubjectDocs (cell): An optional cell array of `ndi.document` objects
            %           that are already in the database. Providing this list is an optimization that
            %           prevents the function from creating duplicate documents for subjects that already exist.
            %
            %   Returns:
            %       output (struct): A structure containing the results.
            %           - 'subjectName' (cell): The name of each subject processed.
            %           - 'documents' (cell): A cell array where each element is another cell array containing
            %             all documents created for the corresponding subject (e.g., the main 'subject' document,
            %             plus 'openminds' documents for species, strain, etc.).
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                subjectInfo (1,1) struct {ndi.setup.NDIMaker.subjectMaker.mustBeValidSubjectInfoForDocCreation(subjectInfo)}
                options.existingSubjectDocs (1,:) cell = {}
            end

            numSubjects = numel(subjectInfo.subjectName);

            if numSubjects == 0
                warning('ndi:setup:NDIMaker:subjectMaker:EmptySubjectInfo', 'Provided subjectInfo structure contains no subjects. Returning empty output.');
                output = struct('subjectName', {{}}, 'documents', {{}});
                return;
            end

            output_subjectNames = cell(numSubjects, 1);
            output_documents = cell(numSubjects, 1);

            for i = 1:numSubjects
                sName = subjectInfo.subjectName{i};
                output_subjectNames{i} = sName;
                all_docs_for_this_subject = {};

                current_session_id_for_doc = subjectInfo.sessionID{i};

                if isempty(current_session_id_for_doc) || ~ischar(current_session_id_for_doc)
                    warning('ndi:setup:NDIMaker:subjectMaker:InvalidSessionIDFromSubjectInfo', ...
                        'Invalid or empty sessionID for subject "%s". Skipping document creation for this subject.', sName);
                    output_documents{i} = {}; % Assign empty cell for this subject
                    continue; % Skip to next subject
                end

                main_subject_doc = [];
                is_new_main_doc = true;
                for k = 1:numel(options.existingSubjectDocs)
                    existing_doc = options.existingSubjectDocs{k};
                    if isa(existing_doc, 'ndi.document') && isfield(existing_doc.document_properties, 'subject') && ...
                       isfield(existing_doc.document_properties.subject, 'local_identifier') && ...
                       strcmp(existing_doc.document_properties.subject.local_identifier, sName)
                        main_subject_doc = existing_doc;
                        is_new_main_doc = false;
                        break;
                    end
                end
                
                if is_new_main_doc
                    main_subject_doc = ndi.document('subject', 'subject.local_identifier', sName, ...
                        'base.session_id', current_session_id_for_doc);
                    all_docs_for_this_subject{end+1} = main_subject_doc;
                end
                
                main_subject_doc_id = main_subject_doc.id();
                if isfield(subjectInfo, 'species') && numel(subjectInfo.species) >= i && isa(subjectInfo.species{i}, 'openminds.controlledterms.Species')
                    species_docs = ndi.database.fun.openMINDSobj2ndi_document(subjectInfo.species{i}, current_session_id_for_doc, 'subject', main_subject_doc_id);
                    all_docs_for_this_subject = cat(1, all_docs_for_this_subject(:), species_docs(:));
                end
                if isfield(subjectInfo, 'strain') && numel(subjectInfo.strain) >= i && isa(subjectInfo.strain{i}, 'openminds.core.research.Strain')
                    strain_docs = ndi.database.fun.openMINDSobj2ndi_document(subjectInfo.strain{i}, current_session_id_for_doc, 'subject', main_subject_doc_id);
                    all_docs_for_this_subject = cat(1, all_docs_for_this_subject(:), strain_docs(:));
                end
                if isfield(subjectInfo, 'biologicalSex') && numel(subjectInfo.biologicalSex) >= i && isa(subjectInfo.biologicalSex{i}, 'openminds.controlledterms.BiologicalSex')
                    sex_docs = ndi.database.fun.openMINDSobj2ndi_document(subjectInfo.biologicalSex{i}, current_session_id_for_doc, 'subject', main_subject_doc_id);
                    all_docs_for_this_subject = cat(1, all_docs_for_this_subject(:), sex_docs(:));
                end

                output_documents{i} = all_docs_for_this_subject;
            end
            output = struct('subjectName', {output_subjectNames}, 'documents', {output_documents});
        end

        function added_status = addSubjectsToSessions(obj, sessionCellArray, documentsToAddSets)
            %ADDSUBJECTSTOSESSIONS Adds sets of subject-related documents to their respective NDI sessions.
            %
            %   ADDED_STATUS = ADDSUBJECTSTOSESSIONS(OBJ, SESSIONCELLARRAY, DOCUMENTSTOADDSETS)
            %
            %   This is the final step in the workflow, writing the newly created documents to the NDI database.
            %   It identifies the correct session for each set of documents by reading the `session_id` from the
            %   first document in the set. It then finds the corresponding session object from `sessionCellArray`
            %   and uses its `database_add` method.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The instance of this class.
            %       sessionCellArray (cell): A cell array of all NDI session objects (`ndi.session.dir`) 
            %                                involved in the import.
            %       documentsToAddSets (cell): The `.documents` field from the output of `makeSubjectDocuments`.
            %                                  This is a cell array where each element is another cell array
            %                                  containing all documents for a single subject.
            %
            %   Returns:
            %       added_status (logical vector): A logical vector indicating the success (true) or failure (false)
            %                                      for each set of documents.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                sessionCellArray (1,:) cell {ndi.validators.mustBeCellArrayOfNdiSessions(sessionCellArray)}
                documentsToAddSets (1,:) cell
            end
            
            if isempty(documentsToAddSets), added_status = logical([]); return; end
            if isempty(sessionCellArray), added_status = false(1, numel(documentsToAddSets)); return; end
            
            numDocSets = numel(documentsToAddSets);
            added_status = false(1, numDocSets);
            session_id_map = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for k_sess = 1:numel(sessionCellArray)
                session_id_map(sessionCellArray{k_sess}.id()) = k_sess;
            end

            for i = 1:numDocSets
                current_doc_set = documentsToAddSets{i};
                if isempty(current_doc_set) || ~iscell(current_doc_set) || ~isa(current_doc_set{1}, 'ndi.document'), continue; end
                
                target_session_id = current_doc_set{1}.document_properties.base.session_id;
                
                if isKey(session_id_map, target_session_id)
                    session_idx_in_array = session_id_map(target_session_id);
                    actual_session_object = sessionCellArray{session_idx_in_array};
                    actual_session_object.database_add(current_doc_set);
                    added_status(i) = true;
                else
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionNotFoundForAdd', ...
                        'Session with ID "%s" not found in the provided sessionCellArray. Cannot add documents.', target_session_id);
                end
            end
        end

        function deletion_report = deleteSubjectDocs(obj, sessionCellArray, localIdentifiersToDelete)
            %DELETESUBJECTDOCS Deletes subject documents from sessions based on local identifiers.
            %
            %   DELETION_REPORT = DELETESUBJECTDOCS(OBJ, SESSIONCELLARRAY, LOCALIDENTIFIERSTODELETE)
            %
            %   A utility function for cleaning up or resetting subject data. It searches through
            %   one or more sessions and removes any `subject` documents that match the provided
            %   list of `local_identifier` strings.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The instance of this class.
            %       sessionCellArray (cell): A cell array of `ndi.session.dir` objects to search.
            %       localIdentifiersToDelete (cellstr/string): A list of subject `local_identifier` strings
            %                                                  to target for deletion.
            %
            %   Returns:
            %       deletion_report (struct): A structure that provides a log of which documents were
            %                                 found and deleted in each session, which is useful for
            %                                 verification.
            %
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                sessionCellArray (1,:) cell {ndi.validators.mustBeCellArrayOfNdiSessions(sessionCellArray)}
                localIdentifiersToDelete {ndi.validators.mustBeTextLike(localIdentifiersToDelete)}
            end
            
            if isempty(localIdentifiersToDelete) || isempty(sessionCellArray), deletion_report = struct(); return; end
            if isstring(localIdentifiersToDelete), localIdentifiersToDelete = cellstr(localIdentifiersToDelete); end
            
            localIdentifiersToDelete = localIdentifiersToDelete(:);
            numSessions = numel(sessionCellArray);
            deletion_report = repmat(struct('session_id', '', 'session_reference', '', 'docs_found_ids', {{}}, 'docs_deleted_ids', {{}}, 'errors', {{}}), numSessions, 1);

            for s = 1:numSessions
                currentSession = sessionCellArray{s};
                deletion_report(s).session_id = currentSession.id();
                deletion_report(s).session_reference = currentSession.reference;
                
                type_query = ndi.query('','isa','subject');
                
                if numel(localIdentifiersToDelete) > 0
                    id_queries = cellfun(@(id) ndi.query('subject.local_identifier', 'exact_string', id), localIdentifiersToDelete, 'UniformOutput', false);
                    combined_local_id_query = id_queries{1};
                    for q_idx = 2:numel(id_queries)
                        combined_local_id_query = combined_local_id_query | id_queries{q_idx};
                    end
                    docs_found = currentSession.database_search(type_query & combined_local_id_query);
                else
                    docs_found = {};
                end
                
                if ~isempty(docs_found)
                    docs_found_ids = cellfun(@(d) d.id(), docs_found, 'UniformOutput', false);
                    deletion_report(s).docs_found_ids = docs_found_ids;
                    currentSession.database_rm(docs_found_ids);
                    deletion_report(s).docs_deleted_ids = docs_found_ids;
                end
            end
        end
    end % methods block

    methods (Static, Access = private)
        % These are internal helper functions for input validation, ensuring that the public methods
        % receive correctly formatted data, which helps prevent runtime errors.
        
        function mustBeValidSubjectInfoForDocCreation(subjectInfo)
            %MUSTBEVALIDSUBJECTINFOFORDOCREATION Validates structure of subjectInfo for document creation.
            if ~isstruct(subjectInfo)
                error('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectInfoType', 'subjectInfo must be a struct.');
            end
            if ~isfield(subjectInfo, 'subjectName') || ~iscell(subjectInfo.subjectName)
                error('ndi:setup:NDIMaker:subjectMaker:MissingSubjectNameField', 'subjectInfo must have a cell array field "subjectName".');
            end
            if ~isfield(subjectInfo, 'sessionID') || ~iscell(subjectInfo.sessionID)
                error('ndi:setup:NDIMaker:subjectMaker:MissingSessionIDField', 'subjectInfo must have a cell array field "sessionID".');
            end
            if numel(subjectInfo.subjectName) ~= numel(subjectInfo.sessionID)
                error('ndi:setup:NDIMaker:subjectMaker:SubjectSessionIDLengthMismatch', 'subjectInfo.subjectName and subjectInfo.sessionID must have the same number of elements.');
            end
            ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(subjectInfo.subjectName);
        end
    end % private static methods

end % classdef
