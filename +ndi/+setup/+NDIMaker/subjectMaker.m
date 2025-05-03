% Filename: +ndi/+setup/subjectMaker.m

classdef subjectMaker
%SUBJECTMAKER A helper class to create NDI subject documents during import.
%   Provides methods to facilitate the generation of subject documents based
%   on metadata extracted from datasets and associated NDI sessions, and
%   adding those documents to the sessions if they don't already exist.

    properties
        % No properties defined in this version.
    end

    methods
        function obj = subjectMaker()
            %SUBJECTMAKER Construct an instance of this class
            %
            %   OBJ = NDI.SETUP.SUBJECTMAKER()
            %
            %   Creates a subjectMaker object. Takes no arguments.
            %
        end

        function subjectDocuments = makeSubjectDocs(obj, dataTable, createSubjectStringFun, sessionArray, tableSessionIndexes)
            %MAKESUBJECTDOCS Creates NDI subject documents based on table data.
            %
            %   subjectDocuments = MAKESUBJECTDOCS(OBJ, dataTable, createSubjectStringFun, sessionArray, tableSessionIndexes)
            %
            %   Generates NDI subject documents by applying a user-provided function
            %   to generate subject identifiers from table rows and associating them
            %   with corresponding NDI sessions.
            %
            %   Args:
            %       obj (ndi.setup.subjectMaker): The subjectMaker object instance.
            %       dataTable (table): A MATLAB table where each row potentially
            %                          corresponds to data requiring a subject document.
            %                          Must contain columns needed by createSubjectStringFun.
            %       createSubjectStringFun (function_handle): An anonymous function
            %                               (or handle to a function) like:
            %                               subjectId = @(tableRow) your_function(tableRow)
            %                               It takes a single table row as input and returns
            %                               either a char array (subject identifier) or NaN
            %                               (if a subject ID cannot be created for that row).
            %       sessionArray (cell): A cell array of NDI session objects (e.g., ndi.session objects).
            %                            Assumed here to be base ndi.session or similar.
            %       tableSessionIndexes (numeric vector): A vector with the same number
            %                               of elements as rows in dataTable. Each element
            %                               is either a 1-based index into sessionArray indicating
            %                               the corresponding session, or NaN if the table row
            %                               does not correspond to any session in the array.
            %
            %   Returns:
            %       subjectDocuments (cell): A cell array containing newly created
            %                                ndi.document objects of the 'subject' type.
            %                                Each document has its 'base.session_id' set by
            %                                linking to the session and its local identifier field
            %                                (assumed to be document_properties.subject.local_identifier)
            %                                set to the output of createSubjectStringFun.
            %                                Documents are only created for rows with a valid session index
            %                                and where createSubjectStringFun returns a char array (not NaN).
            %
            %   Assumptions:
            %       - Session objects in sessionArray have a method:
            %         `newdoc = newdocument('ndi.document.subject')` or similar
            %       - Document objects (`newdoc`) have a settable property path like:
            %         `document_properties.subject.local_identifier`

            arguments
                obj (1,1) ndi.setup.subjectMaker
                dataTable table {mustBeNonempty}
                createSubjectStringFun (1,1) function_handle
                sessionArray (1,:) cell {mustBeVector} % Keeping as cell based on original description
                tableSessionIndexes (:,1) double {mustBeVector, mustBeIntegerOrNan(tableSessionIndexes), mustMatchTableRows(tableSessionIndexes, dataTable)}
            end

            numRows = height(dataTable);
            subjectDocuments = {}; % Initialize empty cell array for output docs

            for i = 1:numRows
                sessionIdx = tableSessionIndexes(i);

                % Condition 1: Check for valid session index
                isValidSessionIndex = ~isnan(sessionIdx) && (sessionIdx >= 1) && (sessionIdx <= numel(sessionArray));

                if isValidSessionIndex
                    currentRow = dataTable(i, :);

                    % Call the user-provided function to get the subject ID string
                    try
                        local_id = createSubjectStringFun(currentRow);
                    catch ME_Func
                        warning('ndi.setup.subjectMaker:createFunError', ...
                            'Error executing createSubjectStringFun for table row %d: %s. Skipping row.', i, ME_Func.message);
                        continue; % Skip to next row
                    end

                    % Condition 2: Check if function returned a valid string ID
                    isValidLocalId = ischar(local_id) && ~isempty(local_id);

                    if isValidLocalId
                        try
                            currentSession = sessionArray{sessionIdx}; % Access session from cell array

                            % --- NDI specific part: Needs verification/adjustment ---
                            % Assumption: Create a new subject document linked to the session
                            % Replace with your actual NDI API call (e.g., using 'subject' type)
                            newdoc = currentSession.newdocument('subject'); % EXAMPLE CALL - Using 'subject' type string

                            % Assumption: Set the local identifier field
                            % Replace with your actual NDI document property path
                            newdoc.document_properties.subject.local_identifier = local_id; % EXAMPLE PATH
                            % ---------------------------------------------------------

                            % Add the new document to the output list
                            subjectDocuments{end+1, 1} = newdoc; % Append as column

                        catch ME_Ndi
                            warning('ndi.setup.subjectMaker:ndiError', ...
                                'Error creating/modifying NDI document for table row %d: %s. Skipping row.', i, ME_Ndi.message);
                            % Continue to next row if NDI operation fails
                        end
                    end
                end
            end % loop through rows
        end % function makeSubjectDocs


        function added_status = addSubjectsToSessions(obj, sessionArray, subjectDocuments)
            %ADDSUBJECTSTOSESSIONS Adds subject documents to sessions if not already present.
            %
            %   added_status = ADDSUBJECTSTOSESSIONS(OBJ, sessionArray, subjectDocuments)
            %
            %   Checks each NDI session for existing subject documents matching those
            %   provided in subjectDocuments (based on local identifier) and adds
            %   any missing subject documents to the database via the session object.
            %
            %   Args:
            %       obj (ndi.setup.subjectMaker): The subjectMaker object instance.
            %       sessionArray (ndi.session.dir vector): An array of NDI session
            %                                directory objects.
            %       subjectDocuments (cell vector): A cell array of NDI subject
            %                                       document objects (e.g., generated
            %                                       by makeSubjectDocs).
            %
            %   Returns:
            %       added_status (logical vector): A boolean vector of the same size
            %                                      as subjectDocuments. added_status(i)
            %                                      is true if subjectDocuments{i} was
            %                                      added to its corresponding session's
            %                                      database, false otherwise.
            %
            %   Assumptions:
            %       - Session objects in sessionArray are of type `ndi.session.dir`
            %         (or similar) and have methods: `id()`, `database_search(query)`,
            %         `database_add(docs_cell_array)`.
            %       - Document objects in subjectDocuments are of type `ndi.document`
            %         (or similar) and have properties/methods:
            %           `document_properties.document_class.objectname` (or similar field for type string)
            %           `session_id()` (or similar to get linked session ID)
            %           `document_properties.subject.local_identifier` (to get ID)
            %       - `ndi.query` class exists and supports '&' and '|' operations.

            arguments
                obj (1,1) ndi.setup.subjectMaker
                sessionArray (1,:) ndi.session.dir % Assuming object array, adjust if cell
                subjectDocuments (1,:) cell {mustBeVector}
            end

            numSubjectDocs = numel(subjectDocuments);
            added_status = false(1, numSubjectDocs); % Initialize status vector

            if isempty(subjectDocuments) || isempty(sessionArray)
                return; % Nothing to do
            end

            % --- Quick Check: Verify all are subject documents ---
            % *** CORRECTED expected_doc_type based on user feedback ***
            expected_doc_type = 'subject'; % NDI Document class identifier string
            subjects_by_session = containers.Map('KeyType', 'char', 'ValueType', 'any');

            for k = 1:numSubjectDocs
                doc = subjectDocuments{k};
                if ~isa(doc, 'ndi.document') % Check if it's the expected MATLAB class
                    error('ndi.setup.subjectMaker:InvalidInput', ...
                          'Item %d in subjectDocuments is not an ndi.document object.', k);
                end
                % --- NDI specific part: Check document type string ---
                % Replace with your actual NDI property path/check for the type string
                try
                    doc_type = doc.document_properties.document_class.objectname; % EXAMPLE PATH
                catch ME_DocType
                    warning('ndi.setup.subjectMaker:DocTypeError', ...
                            'Could not read document type property for document %d: %s. Skipping doc.', k, ME_DocType.message);
                    continue; % Skip this document
                end
                % -----------------------------------------------
                if ~strcmp(doc_type, expected_doc_type)
                    error('ndi.setup.subjectMaker:InvalidDocumentType', ...
                          'Document %d is type "%s", expected "%s".', k, doc_type, expected_doc_type);
                end

                % --- Group subjects by Session ID ---
                try
                    % --- NDI specific part: Get Session ID ---
                    session_id = doc.session_id(); % EXAMPLE CALL (adjust if property)
                    % -----------------------------------------
                    % --- NDI specific part: Get Local ID ---
                    local_id = doc.document_properties.subject.local_identifier; % EXAMPLE PATH
                    % -----------------------------------------

                    newEntry = struct('local_id', local_id, 'original_index', k);

                    if isKey(subjects_by_session, session_id)
                        subjects_by_session(session_id) = [subjects_by_session(session_id), newEntry];
                    else
                        subjects_by_session(session_id) = newEntry; % Initialize struct array
                    end
                catch ME_PropAccess
                     warning('ndi.setup.subjectMaker:DocPropertyError', ...
                            'Could not access required properties (session_id, local_identifier, type) for document %d: %s. Skipping doc.', k, ME_PropAccess.message);
                     % Mark as not added (implicitly false)
                end
            end % loop through subject docs for check/grouping

            % --- Loop through sessions, query, and add missing subjects ---
            sessionIDs_in_map = keys(subjects_by_session);

            for s = 1:numel(sessionArray)
                currentSession = sessionArray(s);
                try
                   % --- NDI specific part: Get Session ID ---
                   current_session_id = currentSession.id(); % EXAMPLE CALL
                   % -----------------------------------------
                catch ME_SessionID
                    warning('ndi.setup.subjectMaker:SessionIDError', ...
                            'Could not get ID for session %d: %s. Skipping session.', s, ME_SessionID.message);
                    continue;
                end


                % Check if we have any candidate subjects for this session
                if ~isKey(subjects_by_session, current_session_id)
                    continue;
                end

                candidates = subjects_by_session(current_session_id); % Struct array
                if isempty(candidates)
                    continue;
                end

                % --- Build Query ---
                q_list = {};
                 % Query for document type = 'subject'
                base_query = ndi.query('document_properties.document_class.objectname', 'exact_string', expected_doc_type); % EXAMPLE QUERY using corrected type
                for c = 1:numel(candidates)
                    % --- NDI specific part: Query for local ID ---
                    q_list{end+1} = ndi.query('document_properties.subject.local_identifier', 'exact_string', candidates(c).local_id); % EXAMPLE QUERY
                    % ---------------------------------------------
                end

                % Combine local_id queries with OR (|)
                if isempty(q_list)
                    continue; % Should not happen if candidates is not empty, but safe check
                elseif numel(q_list) == 1
                    combined_local_id_query = q_list{1};
                else
                    combined_local_id_query = q_list{1};
                    for q_idx = 2:numel(q_list)
                        combined_local_id_query = combined_local_id_query | q_list{q_idx}; % Build OR query
                    end
                end

                % Final query is: base_query AND (local_id_1 OR local_id_2 ...)
                % The session.database_search should implicitly scope to the session
                final_query = base_query & combined_local_id_query;

                % --- Search Database ---
                try
                    % --- NDI specific part: Database Search ---
                    existingDocs = currentSession.database_search(final_query); % EXAMPLE CALL
                    % ------------------------------------------
                catch ME_Search
                    warning('ndi.setup.subjectMaker:DBSearchError', ...
                            'Database search failed for session %s (ID: %s): %s. Skipping session.', ...
                            currentSession.Reference, current_session_id, ME_Search.message); % Assuming Reference property exists
                    continue;
                end

                % --- Determine which subjects to add ---
                existing_ids = {};
                if ~isempty(existingDocs)
                    try
                       % --- NDI specific part: Get Local IDs from existing docs ---
                       existing_ids = cellfun(@(d) d.document_properties.subject.local_identifier, existingDocs, 'UniformOutput', false); % EXAMPLE PATH
                       % -----------------------------------------------------------
                    catch ME_ExistingID
                         warning('ndi.setup.subjectMaker:ExistingIDError', ...
                                'Could not extract local IDs from existing documents for session %s (ID: %s): %s. Assuming none exist.', ...
                                currentSession.Reference, current_session_id, ME_ExistingID.message);
                        existing_ids = {}; % Proceed cautiously
                    end
                end

                docs_to_add_cell = {};
                original_indices_to_add = [];

                for c = 1:numel(candidates)
                    if ~ismember(candidates(c).local_id, existing_ids)
                        original_index = candidates(c).original_index;
                        docs_to_add_cell{end+1} = subjectDocuments{original_index};
                        original_indices_to_add(end+1) = original_index;
                    end
                end

                % --- Add to Database ---
                if ~isempty(docs_to_add_cell)
                    try
                        % --- NDI specific part: Database Add ---
                        currentSession.database_add(docs_to_add_cell); % EXAMPLE CALL
                        % ---------------------------------------
                        % Update status only if add was successful
                        added_status(original_indices_to_add) = true;
                    catch ME_Add
                        warning('ndi.setup.subjectMaker:DBAddError', ...
                            'Database add failed for session %s (ID: %s): %s. Added status may be incorrect.', ...
                            currentSession.Reference, current_session_id, ME_Add.message);
                        % Leave status as false for docs that failed to add
                    end
                end % if docs_to_add_cell

            end % loop through sessions

        end % function addSubjectsToSessions

    end % methods block

end % classdef


% --- Local Validation Functions ---
% (Place these outside the classdef block if in the same file,
%  or put them in separate files on the path)

function mustBeIntegerOrNan(a)
% Validate that input is numeric, and all elements are NaN or positive integers
    if ~isnumeric(a)
        error('Validation:NotNumeric', 'Input must be numeric.');
    end
    % Allow empty input to pass this specific check
    if isempty(a)
        return;
    end
    if ~all(isnan(a(:)) | (a(:) == fix(a(:)) & a(:) >= 1))
        error('Validation:InvalidIndex', 'Input must contain only NaN or positive integer values.');
    end
end

function mustMatchTableRows(idx, tbl)
% Validate that number of elements in idx matches number of rows in tbl
    if ~isempty(idx) && numel(idx) ~= height(tbl) % Only check if idx is not empty
        error('Validation:SizeMismatch', 'Number of elements in index vector (%d) must match number of rows in table (%d).', numel(idx), height(tbl));
    end
end

function mustHaveRequiredColumns(t)
% Checks if the input table t has the required columns for createSubjectString

    % Note: This validator assumes createSubjectString is the *only* consumer.
    % If other methods need different columns, this needs adjustment or removal.
    requiredCols = {'IsWildType', 'RecordingDate'};
    actualCols = t.Properties.VariableNames;

    missingCols = setdiff(requiredCols, actualCols);

    if ~isempty(missingCols)
        error('Validation:MissingColumns', ...
              'Input table is missing required column(s) for subject string creation: %s', ...
              strjoin(missingCols, ', '));
    end
end

