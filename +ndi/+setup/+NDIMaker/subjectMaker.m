% Filename: +ndi/+setup/+NDIMaker/subjectMaker.m

classdef subjectMaker % Class name remains subjectMaker
%SUBJECTMAKER A helper class to extract subject information from tables and manage subject documents.
%   Provides methods to facilitate the extraction of unique subject
%   information based on metadata in tables, and to manage NDI subject
%   documents (e.g., creation, deletion). Resides in the ndi.setup.NDIMaker package.

    properties
        % No properties defined in this version.
    end

    methods
        function obj = subjectMaker() % Constructor name remains subjectMaker
            %SUBJECTMAKER Construct an instance of this class
            %
            %   OBJ = NDI.SETUP.NDIMAKER.SUBJECTMAKER()
            %
            %   Creates a subjectMaker object. Takes no arguments.
            %
        end

        function subjectInfo = getSubjectInfoFromTable(obj, dataTable, subjectInfoFun)
            %GETSUBJECTINFOFROMTABLE Extracts unique subject info by applying a function to table rows.
            %
            %   subjectInfo = GETSUBJECTINFOFROMTABLE(OBJ, dataTable, subjectInfoFun)
            %
            %   Applies a user-provided function to each row of a data table
            %   to extract subject information (ID, strain, species, sex).
            %   It also extracts the 'sessionInd' directly from the table.
            %   It then filters this information to return data only for
            %   unique, valid subject IDs found in the table.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The subjectMaker object instance.
            %       dataTable (table): A MATLAB table where each row contains
            %                        metadata potentially defining a subject.
            %                        Must contain columns needed by subjectInfoFun,
            %                        AND a column named 'sessionInd'.
            %       subjectInfoFun (function_handle): An anonymous function
            %                        (or handle to a function) like:
            %                        info = @(tableRow) createSubjectInformation(tableRow)
            %                        It takes a single table row as input and returns
            %                        four outputs:
            %                        [subjectId, strain, species, biologicalSex]
            %                        Where:
            %                         - subjectId is char/NaN (local identifier)
            %                         - strain is openminds.core.research.Strain/NaN or similar
            %                         - species is openminds.controlledterms.Species/NaN or similar
            %                         - biologicalSex is currently NaN or similar
            %
            %   Returns:
            %       subjectInfo (struct): A structure containing information about
            %                        unique subjects found in the table. It has fields:
            %                        - subjectName (cell array): Unique, valid subject IDs (char).
            %                        - strain (cell array): Corresponding strain objects/NaN.
            %                        - species (cell array): Corresponding species objects/NaN.
            %                        - biologicalSex (cell array): Corresponding sex info/NaN.
            %                        - tableRowIndex (numeric vector): Original row index in
            %                          dataTable where this unique subject was first found.
            %                        - sessionInd (numeric vector): Session index from the
            %                          'sessionInd' column of dataTable for the row that
            %                          generated the unique subject.
            %                        Returns an empty struct with empty fields if no
            %                        valid, unique subjects are found.
            %
            %   Assumes:
            %       - dataTable contains a numeric column named 'sessionInd'.

            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                dataTable table {mustBeNonempty, mustHaveSessionIndColumn(dataTable)}
                subjectInfoFun (1,1) function_handle
            end

            numRows = height(dataTable);

            % Preallocate cell arrays/vectors to store results from all rows
            allSubjectNames = cell(numRows, 1);
            allStrains = cell(numRows, 1);
            allSpecies = cell(numRows, 1);
            allBiologicalSex = cell(numRows, 1);
            allTableRowIndex = (1:numRows)'; % Store original index
            allSessionInds = nan(numRows, 1); % Preallocate for sessionInd, assuming numeric

            validRowProcessedSuccessfully = false(numRows, 1); % Track if subjectInfoFun completed without error

            % --- Loop 1: Extract info from all rows ---
            for i = 1:numRows
                currentRow = dataTable(i, :);
                local_id_from_fun = NaN; % Default in case of error or non-assignment
                strain_obj_from_fun = NaN;
                species_obj_from_fun = NaN;
                sex_obj_from_fun = NaN;

                try
                    % Call the user-provided function to get the subject info
                    [local_id_from_fun, strain_obj_from_fun, species_obj_from_fun, sex_obj_from_fun] = subjectInfoFun(currentRow);
                    validRowProcessedSuccessfully(i) = true; % Mark row as processed by subjectInfoFun without error
                catch ME_Func
                    escaped_message = strrep(ME_Func.message, '%', '%%');
                    warning_msg = sprintf('Error executing subjectInfoFun for table row %d: %s. Skipping this row for subject info extraction.', i, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:subjectInfoFunError', warning_msg);
                    % local_id_from_fun and other outputs remain as default (e.g., NaN)
                    % validRowProcessedSuccessfully(i) remains false
                end

                % Store results from subjectInfoFun
                allSubjectNames{i} = local_id_from_fun;
                allStrains{i} = strain_obj_from_fun;
                allSpecies{i} = species_obj_from_fun;
                allBiologicalSex{i} = sex_obj_from_fun;
                
                % Extract sessionInd directly from the table row
                try
                    rawSessionInd = currentRow.sessionInd;
                    extractedSessionIndValue = NaN; % Default

                    if iscell(rawSessionInd) % Check if the content is a cell
                        if ~isempty(rawSessionInd) && numel(rawSessionInd) > 0
                            % Handle potential nested cells, though less common for simple indices
                            if iscell(rawSessionInd{1}) && ~isempty(rawSessionInd{1}) && numel(rawSessionInd{1}) > 0
                                extractedSessionIndValue = rawSessionInd{1}{1}; % Extract from nested cell
                            else
                                extractedSessionIndValue = rawSessionInd{1}; % Take the first element
                            end
                        end
                        % If cell is empty, extractedSessionIndValue remains NaN
                    else
                        extractedSessionIndValue = rawSessionInd; % It's not a cell, use directly
                    end

                    % Now validate the extracted value
                    if isnumeric(extractedSessionIndValue) && isscalar(extractedSessionIndValue)
                        allSessionInds(i) = extractedSessionIndValue;
                    else
                        warning_msg = sprintf('Data in "sessionInd" column for table row %d (extracted as type %s) is not a numeric scalar. Storing NaN.', i, class(extractedSessionIndValue));
                        warning('ndi:setup:NDIMaker:subjectMaker:InvalidSessionIndData', warning_msg);
                        % allSessionInds(i) remains NaN
                    end
                catch ME_SessionInd
                    escaped_message = strrep(ME_SessionInd.message, '%', '%%');
                    warning_msg = sprintf('Error accessing "sessionInd" for table row %d: %s. Storing NaN for sessionInd.', i, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionIndAccessError', warning_msg);
                     % allSessionInds(i) remains NaN
                end
                
                % If subjectInfoFun completed without error but returned an invalid ID
                if validRowProcessedSuccessfully(i) && ~(ischar(local_id_from_fun) && ~isempty(local_id_from_fun))
                    if (isnumeric(local_id_from_fun) && all(isnan(local_id_from_fun(:)))) || ...
                       (islogical(local_id_from_fun) && all(isnan(local_id_from_fun(:)))) || ...
                       (iscell(local_id_from_fun) && isempty(local_id_from_fun)) || ...
                       (ischar(local_id_from_fun) && isempty(local_id_from_fun)) % Redundant but explicit
                        warning_msg = sprintf('subjectInfoFun completed for table row %d but returned an invalid or empty subject ID. This may be due to an internal issue in the function (e.g., invalid date, potentially indicated by a separate warning from that function).', i);
                        warning('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectIDReturned', warning_msg);
                    end
                end
            end

            % --- Filter for valid and unique subjects ---
            % Find rows where subjectInfoFun executed AND returned a valid (char) subject name
            isValidName = cellfun(@(x) ischar(x) && ~isempty(x), allSubjectNames);
            finalValidIndices = find(isValidName);


            if isempty(finalValidIndices)
                % Return empty struct if no valid subjects found
                 subjectInfo = struct(...
                    'subjectName', {{}}, ...
                    'strain', {{}}, ...
                    'species', {{}}, ...
                    'biologicalSex', {{}}, ...
                    'tableRowIndex', [], ...
                    'sessionInd', [] ...
                 );
                return;
            end

            % Extract data only for rows with valid subject names
            validSubjectNames = allSubjectNames(finalValidIndices);
            validStrains = allStrains(finalValidIndices);
            validSpecies = allSpecies(finalValidIndices);
            validBiologicalSex = allBiologicalSex(finalValidIndices);
            validOriginalIndices = allTableRowIndex(finalValidIndices);
            validSessionInds = allSessionInds(finalValidIndices);

            % Find the indices of the *first* occurrence of each unique valid subject name
            [uniqueNames, ia, ~] = unique(validSubjectNames, 'stable'); % 'stable' keeps first occurrence

            % Select the data corresponding to these unique first occurrences
            uniqueStrains = validStrains(ia);
            uniqueSpecies = validSpecies(ia);
            uniqueBiologicalSex = validBiologicalSex(ia);
            uniqueOriginalIndices = validOriginalIndices(ia);
            uniqueSessionInds = validSessionInds(ia);

            % --- Create Output Struct ---
            subjectInfo = struct(...
                'subjectName', {uniqueNames}, ...
                'strain', {uniqueStrains}, ...
                'species', {uniqueSpecies}, ...
                'biologicalSex', {uniqueBiologicalSex}, ...
                'tableRowIndex', uniqueOriginalIndices, ...
                'sessionInd', uniqueSessionInds ...
            );

        end % function getSubjectInfoFromTable

        function output = makeSubjectDocuments(obj, subjectInfo, sessionIDs)
            %MAKESUBJECTDOCUMENTS Creates NDI subject documents from subjectInfo structure.
            %
            %   output = MAKESUBJECTDOCUMENTS(OBJ, subjectInfo, sessionIDs)
            %
            %   Constructs NDI subject documents for each unique subject listed
            %   in the subjectInfo structure. It creates a main subject document
            %   and then attempts to create separate NDI documents for species,
            %   strain, and biological sex information by calling
            %   ndi.database.fun.openMINDSobj2ndi_document for each valid
            %   openMINDS object, linking them to the main subject document.
            %   The output for each subject is a cell array containing all these documents.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The subjectMaker instance.
            %       subjectInfo (struct): A structure as returned by
            %                             getSubjectInfoFromTable. Validated to ensure
            %                             it has a 'subjectName' cell array field.
            %       sessionIDs (cellstr): A cell array of NDI session ID strings.
            %                             Validated to ensure it's text-like. Length
            %                             is checked against numSubjects.
            %
            %   Returns:
            %       output (struct): A structure with fields:
            %                        - subjectName (cell array): Subject names for which
            %                          documents were attempted.
            %                        - documents (cell array): Each element is a cell array
            %                          of NDI document objects (ndi.document) pertaining
            %                          to the corresponding subject. This includes the main
            %                          subject document and any documents created for its
            %                          species, strain, and sex. Contains an empty cell
            %                          if document creation failed for a subject.
            %
            %   Throws:
            %       error: If sessionIDs length does not match the number of subjects.
            %       error: If any subjectName in subjectInfo.subjectName is invalid.
            %
            %   Assumptions:
            %       - ndi.document class can be instantiated as:
            %         ndi.document('subject_type_string', 'prop1', val1, 'prop2', val2, ...)
            %       - ndi.database.fun.openMINDSobj2ndi_document(openminds_obj, session_id, 'subject', subject_doc_id)
            %         exists and returns a cell array of NDI document(s)
            %         representing the openMINDS_obj, or an empty cell array if conversion fails.
            %       - NDI document objects have an id() method that returns a unique ID
            %         even for documents not yet added to a database.

            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                subjectInfo (1,1) struct {mustBeValidSubjectInfoForDocCreation(subjectInfo)}
                sessionIDs (1,:) cell {mustBeTextLike(sessionIDs)}
            end

            % Further validation after arguments block
            numSubjects = numel(subjectInfo.subjectName);

            if numSubjects == 0
                warning_msg = 'subjectInfo.subjectName is empty. No documents to create.';
                warning('ndi:setup:NDIMaker:subjectMaker:EmptySubjectInfo', warning_msg);
                output = struct('subjectName', {{}}, 'documents', {{}});
                return;
            end

            if numel(sessionIDs) ~= numSubjects
                error('ndi:setup:NDIMaker:subjectMaker:SessionIDMismatch', ...
                    'The number of sessionIDs (%d) must match the number of subjects in subjectInfo (%d).', ...
                    numel(sessionIDs), numSubjects);
            end

            mustHaveAllValidSubjectNames(subjectInfo.subjectName); % Validate all subject names upfront

            output_subjectNames = cell(numSubjects, 1);
            output_documents = cell(numSubjects, 1); % Each element will be a cell array of docs

            for i = 1:numSubjects
                sName = subjectInfo.subjectName{i}; % Already validated by mustHaveAllValidSubjectNames
                output_subjectNames{i} = sName;

                current_session_id = sessionIDs{i};
                if ~(ischar(current_session_id) && ~isempty(current_session_id))
                     escaped_sName = strrep(sName, '%', '%%');
                     warning_msg = sprintf('Session ID for subject "%s" (index %d) is not a valid string. Skipping document creation.', escaped_sName, i);
                     warning('ndi:setup:NDIMaker:subjectMaker:InvalidSessionID', warning_msg);
                     output_documents{i} = {}; % Placeholder for failed document set
                     continue;
                end

                all_docs_for_this_subject = {}; % Initialize cell array for this subject's documents
                main_subject_doc_id = ''; % To store the ID of the main subject document

                try
                    % 1. Create base subject document
                    main_subject_doc = ndi.document('subject', ...
                        'subject.local_identifier', sName, ...
                        'base.session_id', current_session_id);
                    all_docs_for_this_subject{end+1} = main_subject_doc; % Add as the first document
                    
                    % Get the ID of the main subject document for linking
                    main_subject_doc_id = main_subject_doc.id(); 

                    % 2. Create and add species document(s)
                    if isfield(subjectInfo, 'species') && numel(subjectInfo.species) >= i
                        species_obj = subjectInfo.species{i};
                        if isa(species_obj, 'openminds.controlledterms.Species') % Corrected check
                            try
                                % Returns a cell array of NDI documents
                                species_ndi_docs = ndi.database.fun.openMINDSobj2ndi_document(species_obj, current_session_id, 'subject', main_subject_doc_id);
                                if ~isempty(species_ndi_docs)
                                    % Ensure new_docs is a column vector for cat
                                    all_docs_for_this_subject = cat(1, all_docs_for_this_subject(:), species_ndi_docs(:));
                                end
                            catch ME_SpeciesConv
                                escaped_sName = strrep(sName, '%', '%%');
                                escaped_message = strrep(ME_SpeciesConv.message, '%', '%%');
                                warning_msg = sprintf('Failed to convert/add species NDI document(s) for subject %s: %s', escaped_sName, escaped_message);
                                warning('ndi:setup:NDIMaker:subjectMaker:OpenMINDSConversionError', warning_msg);
                            end
                        end
                    end

                    % 3. Create and add strain document(s)
                    if isfield(subjectInfo, 'strain') && numel(subjectInfo.strain) >= i
                        strain_obj = subjectInfo.strain{i};
                        if isa(strain_obj, 'openminds.core.research.Strain') % Corrected check
                             try
                                % Returns a cell array of NDI documents
                                strain_ndi_docs = ndi.database.fun.openMINDSobj2ndi_document(strain_obj, current_session_id, 'subject', main_subject_doc_id);
                                if ~isempty(strain_ndi_docs)
                                    all_docs_for_this_subject = cat(1, all_docs_for_this_subject(:), strain_ndi_docs(:));
                                end
                            catch ME_StrainConv
                                escaped_sName = strrep(sName, '%', '%%');
                                escaped_message = strrep(ME_StrainConv.message, '%', '%%');
                                warning_msg = sprintf('Failed to convert/add strain NDI document(s) for subject %s: %s', escaped_sName, escaped_message);
                                warning('ndi:setup:NDIMaker:subjectMaker:OpenMINDSConversionError', warning_msg);
                            end
                        end
                    end

                    % 4. Create and add biological sex document(s)
                    if isfield(subjectInfo, 'biologicalSex') && numel(subjectInfo.biologicalSex) >= i
                        sex_obj = subjectInfo.biologicalSex{i};
                        if isa(sex_obj, 'openminds.controlledterms.BiologicalSex') % Corrected check
                            try
                                % Returns a cell array of NDI documents
                                sex_ndi_docs = ndi.database.fun.openMINDSobj2ndi_document(sex_obj, current_session_id, 'subject', main_subject_doc_id);
                                if ~isempty(sex_ndi_docs)
                                    all_docs_for_this_subject = cat(1, all_docs_for_this_subject(:), sex_ndi_docs(:));
                                end
                            catch ME_SexConv
                                escaped_sName = strrep(sName, '%', '%%');
                                escaped_message = strrep(ME_SexConv.message, '%', '%%');
                                warning_msg = sprintf('Failed to convert/add biological sex NDI document(s) for subject %s: %s', escaped_sName, escaped_message);
                                warning('ndi:setup:NDIMaker:subjectMaker:OpenMINDSConversionError', warning_msg);
                            end
                        end
                    end
                    output_documents{i} = all_docs_for_this_subject;

                catch ME_DocCreation
                    escaped_sName = strrep(sName, '%', '%%');
                    escaped_message = strrep(ME_DocCreation.message, '%', '%%');
                    warning_msg = sprintf('Failed to create base NDI document for subject %s: %s', escaped_sName, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:DocumentCreationError', warning_msg);
                    output_documents{i} = {}; % Store empty cell for this subject on error
                end
            end

            output = struct('subjectName', {output_subjectNames}, 'documents', {output_documents});

        end % function makeSubjectDocuments


        function deletion_report = deleteSubjectDocs(obj, sessionArray, localIdentifiersToDelete)
            %DELETESUBJECTDOCS Deletes subject documents from sessions based on local identifiers.
            %
            %   deletion_report = DELETESUBJECTDOCS(OBJ, sessionArray, localIdentifiersToDelete)
            %
            %   Searches each NDI session for 'subject' documents whose
            %   'document_properties.subject.local_identifier' matches any of the
            %   identifiers provided in localIdentifiersToDelete. Found documents
            %   are then removed from the database via the session object.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The subjectMaker object instance.
            %       sessionArray (ndi.session.dir vector): An array of NDI session
            %                                          directory objects.
            %       localIdentifiersToDelete (cellstr | string): A cell array of
            %                                          character vectors or a string array
            %                                          containing the local subject
            %                                          identifiers to be deleted.
            %
            %   Returns:
            %       deletion_report (struct): A structure array detailing the
            %                               deletion attempts. Each element corresponds
            %                               to a session and contains fields:
            %                               - session_id (char): The ID of the session.
            %                               - session_reference (char): The reference of the session.
            %                               - docs_found_ids (cellstr): Database IDs of matching documents found.
            %                               - docs_deleted_ids (cellstr): Database IDs of documents successfully deleted.
            %                               - errors (cell): Cell array of any MException objects encountered.
            %
            %   Assumptions:
            %       - Session objects in sessionArray are of type `ndi.session.dir`
            %         (or similar) and have methods: `id()`, `Reference` (property),
            %         `database_search(query)`, `database_delete(doc_ids_cell_array)`.
            %       - Document objects have a method `id()` to get their database ID.
            %       - `ndi.query` class exists and supports '&' and '|' operations.
            %       - Document property paths:
            %         `document_properties.document_class.objectname`
            %         `document_properties.subject.local_identifier`

            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                sessionArray (1,:) ndi.session.dir % Assuming object array
                localIdentifiersToDelete {mustBeTextLike(localIdentifiersToDelete)} % Renamed validator
            end

            if isempty(localIdentifiersToDelete) || isempty(sessionArray)
                warning_msg = 'No local identifiers provided or no sessions to search. No action taken.';
                warning('ndi:setup:NDIMaker:subjectMaker:EmptyInput', warning_msg); % Corrected ID
                deletion_report = struct('session_id', {}, 'session_reference', {}, ...
                                         'docs_found_ids', {}, 'docs_deleted_ids', {}, 'errors', {});
                return;
            end

            % Ensure localIdentifiersToDelete is a cellstr for ismember/query construction
            if isstring(localIdentifiersToDelete)
                localIdentifiersToDelete = cellstr(localIdentifiersToDelete);
            end
            localIdentifiersToDelete = localIdentifiersToDelete(:); % Ensure column vector

            numSessions = numel(sessionArray);
            deletion_report = repmat(struct('session_id', '', 'session_reference', '', ...
                                            'docs_found_ids', {{}}, 'docs_deleted_ids', {{}}, ...
                                            'errors', {{}}), numSessions, 1);
            expected_doc_type = 'subject';

            for s = 1:numSessions
                currentSession = sessionArray(s);
                session_errors = {};
                docs_found_for_deletion_ids = {};
                docs_successfully_deleted_ids = {};

                try
                    current_session_id = currentSession.id();
                    current_session_ref = currentSession.Reference; % Assuming Reference property
                    deletion_report(s).session_id = current_session_id;
                    deletion_report(s).session_reference = current_session_ref;
                catch ME_SessionInfo
                    escaped_message = strrep(ME_SessionInfo.message, '%', '%%');
                    warning_msg = sprintf('Could not get ID or Reference for session %d: %s. Skipping session.', s, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionInfoError', warning_msg); % Corrected ID
                    deletion_report(s).errors{end+1} = ME_SessionInfo;
                    continue;
                end

                % --- Build Query ---
                type_query = ndi.query('document_properties.document_class.objectname', 'exact_string', expected_doc_type);
                if isempty(localIdentifiersToDelete)
                    continue;
                end
                id_queries = cell(numel(localIdentifiersToDelete), 1);
                for k = 1:numel(localIdentifiersToDelete)
                    id_queries{k} = ndi.query('document_properties.subject.local_identifier', 'exact_string', localIdentifiersToDelete{k});
                end
                if numel(id_queries) == 1
                    combined_local_id_query = id_queries{1};
                else
                    combined_local_id_query = id_queries{1};
                    for q_idx = 2:numel(id_queries)
                        combined_local_id_query = combined_local_id_query | id_queries{q_idx};
                    end
                end
                final_query = type_query & combined_local_id_query;

                % --- Search Database ---
                docs_found = {};
                try
                    docs_found = currentSession.database_search(final_query);
                catch ME_Search
                    escaped_sRef = strrep(current_session_ref, '%', '%%');
                    escaped_sID = strrep(current_session_id, '%', '%%');
                    escaped_message = strrep(ME_Search.message, '%', '%%');
                    warning_msg = sprintf('Database search failed for session %s (ID: %s): %s.', ...
                        escaped_sRef, escaped_sID, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:DBSearchError', warning_msg); % Corrected ID
                    session_errors{end+1} = ME_Search;
                    deletion_report(s).errors = session_errors;
                    continue;
                end

                if ~isempty(docs_found)
                    try
                        docs_found_for_deletion_ids = cellfun(@(d) d.id(), docs_found, 'UniformOutput', false);
                        deletion_report(s).docs_found_ids = docs_found_for_deletion_ids;
                    catch ME_DocID
                        escaped_sRef = strrep(current_session_ref, '%', '%%');
                        escaped_sID = strrep(current_session_id, '%', '%%');
                        escaped_message = strrep(ME_DocID.message, '%', '%%');
                        warning_msg = sprintf('Could not extract database IDs from found documents for session %s (ID: %s): %s.', ...
                            escaped_sRef, escaped_sID, escaped_message);
                         warning('ndi:setup:NDIMaker:subjectMaker:DocIDError', warning_msg); % Corrected ID
                        session_errors{end+1} = ME_DocID;
                        deletion_report(s).errors = session_errors;
                        continue;
                    end

                    if ~isempty(docs_found_for_deletion_ids)
                        try
                            currentSession.database_delete(docs_found_for_deletion_ids);
                            docs_successfully_deleted_ids = docs_found_for_deletion_ids;
                            deletion_report(s).docs_deleted_ids = docs_successfully_deleted_ids;
                            fprintf('Session %s (ID: %s): Deleted %d subject document(s).\n', ...
                                strrep(current_session_ref, '%', '%%'), strrep(current_session_id, '%', '%%'), numel(docs_successfully_deleted_ids));
                        catch ME_Delete
                            escaped_sRef = strrep(current_session_ref, '%', '%%');
                            escaped_sID = strrep(current_session_id, '%', '%%');
                            escaped_message = strrep(ME_Delete.message, '%', '%%');
                            warning_msg = sprintf('Database delete operation failed for session %s (ID: %s): %s.', ...
                                escaped_sRef, escaped_sID, escaped_message);
                            warning('ndi:setup:NDIMaker:subjectMaker:DBDeleteError', warning_msg); % Corrected ID
                            session_errors{end+1} = ME_Delete;
                        end
                    end
                else
                     fprintf('Session %s (ID: %s): No subject documents found matching the provided local identifiers.\n', ...
                         strrep(current_session_ref, '%', '%%'), strrep(current_session_id, '%', '%%'));
                end
                deletion_report(s).errors = session_errors;
            end % loop through sessions
        end % function deleteSubjectDocs

        % --- Deprecated/Needs Refactoring ---
        function added_status = addSubjectsToSessions(obj, sessionArray, subjectDocuments)
            %ADDSUBJECTSTOSESSIONS Adds subject documents to sessions if not already present.
            % *** NOTE: This function is currently incompatible with the output of
            %     getSubjectInfoFromTable and needs refactoring. ***
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                sessionArray (1,:) ndi.session.dir
                subjectDocuments (1,:) cell {mustBeVector}
            end
            warning_msg = 'addSubjectsToSessions is not compatible with the current class structure and needs refactoring.';
            warning('ndi:setup:NDIMaker:subjectMaker:DeprecatedFunction', warning_msg); % Corrected ID
            numSubjectDocs = numel(subjectDocuments);
            added_status = false(1, numSubjectDocs);
            if isempty(subjectDocuments) || isempty(sessionArray)
                return;
            end
            disp('Placeholder: addSubjectsToSessions logic needs complete rewrite.');
        end % function addSubjectsToSessions

    end % methods block

end % classdef subjectMaker


% --- Local Helper Function for Argument Validation ---
function mustBeTextLike(value) % Renamed function
% Validate that input is char, string, or cell array of char/string
    if ~(ischar(value) || isstring(value) || iscellstr(value) || (iscell(value) && all(cellfun(@(x) ischar(x) || isstring(x), value))))
        error('Validation:InvalidTextLikeType', 'Input must be a character vector, string, cell array of character vectors, or cell array of strings.');
    end
end

% --- New Local Validation Functions ---
function mustBeValidSubjectInfoForDocCreation(subjectInfo)
% Validates the basic structure of subjectInfo for makeSubjectDocuments
    if ~isstruct(subjectInfo)
        error('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectInfoType', ...
            'subjectInfo must be a struct.');
    end
    if ~isfield(subjectInfo, 'subjectName') || ~iscell(subjectInfo.subjectName)
        error('ndi:setup:NDIMaker:subjectMaker:MissingSubjectNameField', ...
            'subjectInfo must be a struct with a cell array field named "subjectName".');
    end
    % Further checks for strain, species, biologicalSex can be added if they are strictly required
    % and not just optional. For now, only subjectName is critical for this validator.
end

function mustHaveAllValidSubjectNames(subjectNameCellArray)
% Validates that all subject names in the cell array are non-empty char vectors
    if ~iscell(subjectNameCellArray)
        % This should ideally be caught by mustBeValidSubjectInfoForDocCreation
        error('ndi:setup:NDIMaker:subjectMaker:InternalSubjectNameError', 'subjectNameCellArray is not a cell array.');
    end
    for k_val = 1:numel(subjectNameCellArray)
        sName_val = subjectNameCellArray{k_val};
        if ~(ischar(sName_val) && ~isempty(sName_val))
            error('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectNameEntry', ...
                  'All subject names in subjectInfo.subjectName must be valid, non-empty character vectors. Error at index %d.', k_val);
        end
    end
end

function mustHaveSessionIndColumn(dataTable)
% Validates that the dataTable has a 'sessionInd' column
    if ~ismember('sessionInd', dataTable.Properties.VariableNames)
        error('ndi:setup:NDIMaker:subjectMaker:MissingSessionIndColumn', ...
            'The input dataTable must contain a column named "sessionInd".');
    end
end
