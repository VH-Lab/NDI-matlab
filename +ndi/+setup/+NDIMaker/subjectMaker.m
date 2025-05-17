% Filename: +ndi/+setup/+NDIMaker/subjectMaker.m

classdef subjectMaker
%SUBJECTMAKER A helper class to extract subject information from tables and manage NDI subject documents.
%   Provides methods to facilitate the extraction of unique subject
%   information based on metadata in tables, and to manage NDI subject
%   documents (e.g., creation, deletion). Resides in the ndi.setup.NDIMaker package.

    properties
        % No properties are defined for this class in the current version.
    end

    methods
        function obj = subjectMaker()
            %SUBJECTMAKER Construct an instance of this class.
            %
            %   OBJ = NDI.SETUP.NDIMAKER.SUBJECTMAKER()
            %
            %   Creates a subjectMaker object.
            %
        end

        function subjectInfo = getSubjectInfoFromTable(obj, dataTable, subjectInfoFun)
            %GETSUBJECTINFOFROMTABLE Extracts unique subject info by applying a function to table rows.
            %
            %   subjectInfo = GETSUBJECTINFOFROMTABLE(OBJ, dataTable, subjectInfoFun)
            %
            %   This method processes each row of an input 'dataTable' using a
            %   provided function 'subjectInfoFun'. It extracts subject-specific
            %   details (name, strain, species, biological sex) and a 'sessionID'
            %   (character array) directly from the table. The method then filters
            %   these results to return information only for unique subject names
            %   that also have a valid (non-empty char) sessionID.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The instance of this subjectMaker class.
            %       dataTable (table): A MATLAB table where each row contains metadata.
            %                        This table must include all columns required by 'subjectInfoFun'
            %                        and a column named 'sessionID' (containing char/string IDs).
            %       subjectInfoFun (function_handle): A handle to a function that processes
            %                        a single row of 'dataTable'. Expected to return:
            %                        [subjectId, strain, species, biologicalSex]
            %                        - subjectId: char array (subject's local identifier) or NaN.
            %                        - strain: openMINDS strain object or NaN.
            %                        - species: openMINDS species object or NaN.
            %                        - biologicalSex: openMINDS biological sex object or NaN.
            %
            %   Returns:
            %       subjectInfo (struct): A structure containing data for unique subjects.
            %                        Fields: subjectName, strain, species, biologicalSex (all cell arrays),
            %                        tableRowIndex (numeric vector), sessionID (cell array of char).
            %                        If no valid subjects are found, an empty struct is returned.
            %
            %   Assumes:
            %       - 'dataTable' contains a column 'sessionID' with char/string session identifiers.

            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                dataTable table {mustBeNonempty, ndi.setup.NDIMaker.subjectMaker.mustHaveSessionIDColumn(dataTable)}
                subjectInfoFun (1,1) function_handle
            end

            numRows = height(dataTable);

            allSubjectNames = cell(numRows, 1);
            allStrains = cell(numRows, 1);
            allSpecies = cell(numRows, 1);
            allBiologicalSex = cell(numRows, 1);
            allTableRowIndex = (1:numRows)';
            allSessionIDs = cell(numRows, 1); 
            allSessionIDs(:) = {''}; 

            validRowProcessedSuccessfully = false(numRows, 1);

            for i = 1:numRows
                currentRow = dataTable(i, :);
                local_id_from_fun = NaN; 
                strain_obj_from_fun = NaN;
                species_obj_from_fun = NaN;
                sex_obj_from_fun = NaN;

                try
                    [local_id_from_fun, strain_obj_from_fun, species_obj_from_fun, sex_obj_from_fun] = subjectInfoFun(currentRow);
                    validRowProcessedSuccessfully(i) = true;
                catch ME_Func
                    escaped_message = strrep(ME_Func.message, '%', '%%');
                    warning_msg = sprintf('Error executing subjectInfoFun for table row %d: %s. Skipping this row for subject info extraction.', i, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:subjectInfoFunError', warning_msg);
                end

                allSubjectNames{i} = local_id_from_fun;
                allStrains{i} = strain_obj_from_fun;
                allSpecies{i} = species_obj_from_fun;
                allBiologicalSex{i} = sex_obj_from_fun;
                
                try
                    % Use static helper to unwrap cell content for sessionID
                    valueToProcess = ndi.setup.NDIMaker.subjectMaker.unwrapTableCellContent(currentRow.sessionID);
                    
                    % Convert to char if it's a string
                    if isstring(valueToProcess)
                        valueToProcess = char(valueToProcess);
                    end
                    
                    % Store if char; if numeric NaN, treat as empty
                    if ischar(valueToProcess)
                         allSessionIDs{i} = valueToProcess; 
                    elseif isnumeric(valueToProcess) && all(isnan(valueToProcess(:))) 
                         allSessionIDs{i} = ''; 
                    else
                        % If it's not char and not numeric NaN, it's an unexpected type for sessionID
                        warning_msg = sprintf('Data in "sessionID" column for table row %d (type %s after unwrapping) is not char/string or NaN. Storing as empty.', i, class(valueToProcess));
                        warning('ndi:setup:NDIMaker:subjectMaker:InvalidSessionIDType', warning_msg);
                        allSessionIDs{i} = ''; % Ensure it's an empty char for filtering
                    end
                catch ME_SessionID
                    escaped_message = strrep(ME_SessionID.message, '%', '%%');
                    warning_msg = sprintf('Error accessing "sessionID" for table row %d: %s. Storing as empty.', i, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionIDAccessError', warning_msg);
                    allSessionIDs{i} = ''; 
                end
                
                if validRowProcessedSuccessfully(i) && ~(ischar(local_id_from_fun) && ~isempty(local_id_from_fun))
                    isEffectivelyNaNOrEmpty = false;
                    if isnumeric(local_id_from_fun) && all(isnan(local_id_from_fun(:)))
                        isEffectivelyNaNOrEmpty = true;
                    elseif (islogical(local_id_from_fun) || iscell(local_id_from_fun)) && isempty(local_id_from_fun) 
                        isEffectivelyNaNOrEmpty = true;
                    elseif ischar(local_id_from_fun) && isempty(local_id_from_fun)
                        isEffectivelyNaNOrEmpty = true;
                    end

                    if isEffectivelyNaNOrEmpty
                        warning_msg = sprintf('subjectInfoFun completed for table row %d but returned an invalid or empty subject ID. This may be due to an internal issue in the function (e.g., invalid date, potentially indicated by a separate warning from that function).', i);
                        warning('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectIDReturned', warning_msg);
                    end
                end
            end

            isValidName = cellfun(@(x) ischar(x) && ~isempty(x), allSubjectNames);
            isValidSessionID = cellfun(@(x) ischar(x) && ~isempty(x), allSessionIDs); 
            
            finalValidIndices = find(isValidName & isValidSessionID);

            if isempty(finalValidIndices)
                 subjectInfo = struct(...
                    'subjectName', {{}}, ...
                    'strain', {{}}, ...
                    'species', {{}}, ...
                    'biologicalSex', {{}}, ...
                    'tableRowIndex', [], ...
                    'sessionID', {{}} ... 
                 );
                return;
            end

            validSubjectNames = allSubjectNames(finalValidIndices);
            validStrains = allStrains(finalValidIndices);
            validSpecies = allSpecies(finalValidIndices);
            validBiologicalSex = allBiologicalSex(finalValidIndices);
            validOriginalIndices = allTableRowIndex(finalValidIndices);
            validSessionIDs = allSessionIDs(finalValidIndices); 

            [uniqueNames, ia, ~] = unique(validSubjectNames, 'stable'); 

            uniqueStrains = validStrains(ia);
            uniqueSpecies = validSpecies(ia);
            uniqueBiologicalSex = validBiologicalSex(ia);
            uniqueOriginalIndices = validOriginalIndices(ia);
            uniqueSessionIDs = validSessionIDs(ia); 

            subjectInfo = struct(...
                'subjectName', {uniqueNames}, ...
                'strain', {uniqueStrains}, ...
                'species', {uniqueSpecies}, ...
                'biologicalSex', {uniqueBiologicalSex}, ...
                'tableRowIndex', uniqueOriginalIndices, ...
                'sessionID', {uniqueSessionIDs} ... 
            );

        end % function getSubjectInfoFromTable

        function output = makeSubjectDocuments(obj, subjectInfo)
            %MAKESUBJECTDOCUMENTS Creates NDI subject documents from subjectInfo structure.
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                subjectInfo (1,1) struct {ndi.setup.NDIMaker.subjectMaker.mustBeValidSubjectInfoForDocCreation(subjectInfo)}
            end

            numSubjects = numel(subjectInfo.subjectName);

            if numSubjects == 0
                warning_msg = 'subjectInfo.subjectName is empty. No documents to create.';
                warning('ndi:setup:NDIMaker:subjectMaker:EmptySubjectInfo', warning_msg);
                output = struct('subjectName', {{}}, 'documents', {{}});
                return;
            end
            
            if numel(subjectInfo.sessionID) ~= numSubjects
                 error('ndi:setup:NDIMaker:subjectMaker:SessionIDLengthMismatch', ... 
                    'The number of sessionIDs in subjectInfo.sessionID (%d) must match the number of subjects in subjectInfo.subjectName (%d).', ...
                    numel(subjectInfo.sessionID), numSubjects);
            end

            ndi.setup.NDIMaker.subjectMaker.mustHaveAllValidSubjectNames(subjectInfo.subjectName);

            output_subjectNames = cell(numSubjects, 1);
            output_documents = cell(numSubjects, 1); 

            for i = 1:numSubjects
                sName = subjectInfo.subjectName{i}; 
                output_subjectNames{i} = sName;

                current_session_id_for_doc = subjectInfo.sessionID{i}; 
                if ~(ischar(current_session_id_for_doc) && ~isempty(current_session_id_for_doc))
                     escaped_sName = strrep(sName, '%', '%%');
                     warning_msg = sprintf('Session ID for subject "%s" (index %d from subjectInfo.sessionID) is not a valid string. Skipping document creation.', escaped_sName, i);
                     warning('ndi:setup:NDIMaker:subjectMaker:InvalidSessionIDFromSubjectInfo', warning_msg);
                     output_documents{i} = {}; 
                     continue;
                end

                all_docs_for_this_subject = {}; 
                main_subject_doc_id = ''; 

                try
                    main_subject_doc = ndi.document('subject', ...
                        'subject.local_identifier', sName, ...
                        'base.session_id', current_session_id_for_doc);
                    all_docs_for_this_subject{end+1} = main_subject_doc; 
                    main_subject_doc_id = main_subject_doc.id(); 

                    if isfield(subjectInfo, 'species') && numel(subjectInfo.species) >= i
                        species_obj = subjectInfo.species{i};
                        if isa(species_obj, 'openminds.controlledterms.Species') 
                            try
                                species_ndi_docs = ndi.database.fun.openMINDSobj2ndi_document(species_obj, current_session_id_for_doc, 'subject', main_subject_doc_id);
                                if ~isempty(species_ndi_docs)
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

                    if isfield(subjectInfo, 'strain') && numel(subjectInfo.strain) >= i
                        strain_obj = subjectInfo.strain{i};
                        if isa(strain_obj, 'openminds.core.research.Strain') 
                             try
                                strain_ndi_docs = ndi.database.fun.openMINDSobj2ndi_document(strain_obj, current_session_id_for_doc, 'subject', main_subject_doc_id);
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

                    if isfield(subjectInfo, 'biologicalSex') && numel(subjectInfo.biologicalSex) >= i
                        sex_obj = subjectInfo.biologicalSex{i};
                        if isa(sex_obj, 'openminds.controlledterms.BiologicalSex') 
                            try
                                sex_ndi_docs = ndi.database.fun.openMINDSobj2ndi_document(sex_obj, current_session_id_for_doc, 'subject', main_subject_doc_id);
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
                    output_documents{i} = {}; 
                end
            end

            output = struct('subjectName', {output_subjectNames}, 'documents', {output_documents});

        end % function makeSubjectDocuments

        function added_status = addSubjectsToSessions(obj, sessionArray, documentsToAddSets)
            %ADDSUBJECTSTOSESSIONS Adds sets of subject-related documents to their respective sessions.
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                sessionArray (1,:) ndi.session.dir 
                documentsToAddSets (1,:) cell 
            end

            if isempty(documentsToAddSets)
                warning('ndi:setup:NDIMaker:subjectMaker:EmptyDocSetInput', 'documentsToAddSets is empty. No documents to add.');
                added_status = logical([]); 
                return;
            end
            if isempty(sessionArray)
                warning('ndi:setup:NDIMaker:subjectMaker:EmptySessionArray', 'sessionArray is empty. Cannot add documents.');
                added_status = false(1, numel(documentsToAddSets)); 
                return;
            end

            numDocSets = numel(documentsToAddSets);
            added_status = false(1, numDocSets); 

            session_id_map = containers.Map('KeyType', 'char', 'ValueType', 'double'); 
            for k_sess = 1:numel(sessionArray)
                try
                    sess_obj = sessionArray(k_sess);
                    session_id_map(sess_obj.id()) = k_sess; 
                catch ME_SessIDMap
                    escaped_message = strrep(ME_SessIDMap.message, '%', '%%');
                    warning_msg = sprintf('Could not get ID for a session in sessionArray at index %d: %s. This session will be unavailable for adding documents.', k_sess, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionMapCreationError',warning_msg);
                end
            end
            
            if isempty(session_id_map) && numDocSets > 0 
                 warning('ndi:setup:NDIMaker:subjectMaker:NoUsableSessions', 'No usable sessions found in sessionArray. Cannot add documents.');
                 return; 
            end

            for i = 1:numDocSets
                current_doc_set = documentsToAddSets{i};

                if isempty(current_doc_set) || ~iscell(current_doc_set) || ~isa(current_doc_set{1}, 'ndi.document')
                    warning_msg = sprintf('Document set at index %d is empty, not a cell, or does not start with an ndi.document. Skipping.', i);
                    warning('ndi:setup:NDIMaker:subjectMaker:InvalidDocSetEntry', warning_msg);
                    continue; 
                end

                try
                    target_session_id = current_doc_set{1}.document_properties.base.session_id;
                    
                    if ~(ischar(target_session_id) && ~isempty(target_session_id))
                        warning_msg = sprintf('Target session ID for document set %d is invalid or empty. Skipping.', i);
                        warning('ndi:setup:NDIMaker:subjectMaker:InvalidTargetSessionID', warning_msg);
                        continue;
                    end

                catch ME_TargetSessID
                    escaped_message = strrep(ME_TargetSessID.message, '%', '%%');
                    warning_msg = sprintf('Error retrieving target session ID from document set %d: %s. Skipping.', i, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:TargetSessionIDError', warning_msg);
                    continue;
                end

                if isKey(session_id_map, target_session_id)
                    session_idx_in_array = session_id_map(target_session_id);
                    actual_session_object = sessionArray(session_idx_in_array);
                    
                    try
                        actual_session_object.database_add(current_doc_set);
                        added_status(i) = true; 
                        fprintf('Added %d documents for subject (target session: %s) to session %s.\n', ...
                            numel(current_doc_set), strrep(target_session_id,'%','%%'), strrep(actual_session_object.Reference,'%','%%'));
                    catch ME_DbAdd
                        escaped_message = strrep(ME_DbAdd.message, '%', '%%');
                        escaped_target_id = strrep(target_session_id, '%', '%%');
                        warning_msg = sprintf('Failed to add document set %d (target session: %s) to database for session %s: %s', ...
                            i, escaped_target_id, strrep(actual_session_object.Reference,'%','%%'), escaped_message);
                        warning('ndi:setup:NDIMaker:subjectMaker:DatabaseAddError', warning_msg);
                    end
                else
                    escaped_target_id = strrep(target_session_id, '%', '%%');
                    warning_msg = sprintf('Session with ID "%s" (for document set %d) not found in the provided sessionArray. Skipping document set.', ...
                        escaped_target_id, i);
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionNotFoundForAdd', warning_msg);
                end
            end
        end % function addSubjectsToSessions

        function deletion_report = deleteSubjectDocs(obj, sessionArray, localIdentifiersToDelete)
            %DELETESUBJECTDOCS Deletes subject documents from sessions based on local identifiers.
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                sessionArray (1,:) ndi.session.dir 
                localIdentifiersToDelete {ndi.setup.NDIMaker.subjectMaker.mustBeTextLike(localIdentifiersToDelete)}
            end

            if isempty(localIdentifiersToDelete) || isempty(sessionArray)
                warning_msg = 'No local identifiers provided or no sessions to search. No action taken.';
                warning('ndi:setup:NDIMaker:subjectMaker:EmptyInput', warning_msg);
                deletion_report = struct('session_id', {}, 'session_reference', {}, ...
                                         'docs_found_ids', {}, 'docs_deleted_ids', {}, 'errors', {});
                return;
            end

            if isstring(localIdentifiersToDelete)
                localIdentifiersToDelete = cellstr(localIdentifiersToDelete);
            end
            localIdentifiersToDelete = localIdentifiersToDelete(:); 

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
                    current_session_id_val = currentSession.id(); 
                    current_session_ref = currentSession.Reference; 
                    deletion_report(s).session_id = current_session_id_val;
                    deletion_report(s).session_reference = current_session_ref;
                catch ME_SessionInfo
                    escaped_message = strrep(ME_SessionInfo.message, '%', '%%');
                    warning_msg = sprintf('Could not get ID or Reference for session %d: %s. Skipping session.', s, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionInfoError', warning_msg);
                    deletion_report(s).errors{end+1} = ME_SessionInfo;
                    continue;
                end

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

                docs_found = {};
                try
                    docs_found = currentSession.database_search(final_query);
                catch ME_Search
                    escaped_sRef = strrep(current_session_ref, '%', '%%');
                    escaped_sID = strrep(current_session_id_val, '%', '%%');
                    escaped_message = strrep(ME_Search.message, '%', '%%');
                    warning_msg = sprintf('Database search failed for session %s (ID: %s): %s.', ...
                        escaped_sRef, escaped_sID, escaped_message);
                    warning('ndi:setup:NDIMaker:subjectMaker:DBSearchError', warning_msg);
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
                        escaped_sID = strrep(current_session_id_val, '%', '%%');
                        escaped_message = strrep(ME_DocID.message, '%', '%%');
                        warning_msg = sprintf('Could not extract database IDs from found documents for session %s (ID: %s): %s.', ...
                            escaped_sRef, escaped_sID, escaped_message);
                         warning('ndi:setup:NDIMaker:subjectMaker:DocIDError', warning_msg);
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
                                strrep(current_session_ref, '%', '%%'), strrep(current_session_id_val, '%', '%%'), numel(docs_successfully_deleted_ids));
                        catch ME_Delete
                            escaped_sRef = strrep(current_session_ref, '%', '%%');
                            escaped_sID = strrep(current_session_id_val, '%', '%%');
                            escaped_message = strrep(ME_Delete.message, '%', '%%');
                            warning_msg = sprintf('Database delete operation failed for session %s (ID: %s): %s.', ...
                                escaped_sRef, escaped_sID, escaped_message);
                            warning('ndi:setup:NDIMaker:subjectMaker:DBDeleteError', warning_msg);
                            session_errors{end+1} = ME_Delete;
                        end
                    end
                else
                     fprintf('Session %s (ID: %s): No subject documents found matching the provided local identifiers.\n', ...
                         strrep(current_session_ref, '%', '%%'), strrep(current_session_id_val, '%', '%%'));
                end
                deletion_report(s).errors = session_errors;
            end % loop through sessions
        end % function deleteSubjectDocs

    end % methods block

    methods (Static)
        % --- Static Helper/Validation Functions ---
        function mustBeTextLike(value)
            if ~(ischar(value) || isstring(value) || iscellstr(value) || (iscell(value) && all(cellfun(@(x) ischar(x) || isstring(x), value))))
                error('ndi:setup:NDIMaker:subjectMaker:InvalidTextLikeType', 'Input must be a character vector, string, cell array of character vectors, or cell array of strings.');
            end
        end

        function mustBeValidSubjectInfoForDocCreation(subjectInfo)
            if ~isstruct(subjectInfo)
                error('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectInfoType', ...
                    'subjectInfo must be a struct.');
            end
            if ~isfield(subjectInfo, 'subjectName') || ~iscell(subjectInfo.subjectName)
                error('ndi:setup:NDIMaker:subjectMaker:MissingSubjectNameField', ...
                    'subjectInfo must be a struct with a cell array field named "subjectName".');
            end
            if ~isfield(subjectInfo, 'sessionID') || ~iscell(subjectInfo.sessionID) 
                error('ndi:setup:NDIMaker:subjectMaker:MissingSessionIDField', ...
                    'subjectInfo must be a struct with a cell array field named "sessionID".');
            end
            if numel(subjectInfo.subjectName) ~= numel(subjectInfo.sessionID)
                error('ndi:setup:NDIMaker:subjectMaker:SubjectSessionIDLengthMismatch', ...
                    'subjectInfo.subjectName and subjectInfo.sessionID must have the same number of elements.');
            end
        end

        function mustHaveAllValidSubjectNames(subjectNameCellArray)
            if ~iscell(subjectNameCellArray)
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

        function mustHaveSessionIDColumn(dataTable) 
            if ~ismember('sessionID', dataTable.Properties.VariableNames) 
                error('ndi:setup:NDIMaker:subjectMaker:MissingSessionIDColumn', ...
                    'The input dataTable must contain a column named "sessionID".');
            end
        end
        
        function unwrappedValue = unwrapTableCellContent(cellValue)
            %UNWRAPTABLECELLCONTENT Recursively unwraps content from nested cell arrays.
            %   UNWRAPPEDVALUE = UNWRAPTABLECELLCONTENT(CELLVALUE)
            %   If CELLVALUE is a cell, this function attempts to extract the
            %   innermost content. It handles multiple layers of cell nesting.
            %   If CELLVALUE is not a cell, it's returned as is.
            %   If a cell is empty at any level of unwrapping, it returns NaN.
            
            currentValue = cellValue;
            unwrap_count = 0; % Safety break for excessive nesting
            max_unwrap = 5;   % Max number of cell layers to unwrap

            while iscell(currentValue) && ~isempty(currentValue) && unwrap_count < max_unwrap
                currentValue = currentValue{1};
                unwrap_count = unwrap_count + 1;
            end
            
            % If after unwrapping it's still an empty cell (e.g. from initial {{}})
            % or if the original was an empty cell
            if iscell(currentValue) && isempty(currentValue)
                unwrappedValue = NaN;
            else
                unwrappedValue = currentValue;
            end
        end

    end % methods (Static)

end % classdef subjectMaker
