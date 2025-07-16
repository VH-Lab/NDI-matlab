% file: +ndi/+setup/+NDIMaker/subjectMaker.m
classdef subjectMaker < handle
%SUBJECTMAKER A helper class to extract subject information from tables and manage NDI subject documents.
%   Provides methods to facilitate the extraction of unique subject
%   information based on metadata in tables, and to manage NDI subject
%   documents (e.g., creation, addition to sessions, deletion).

    properties
        % No public properties are defined for this class.
    end

    methods
        function obj = subjectMaker()
            %SUBJECTMAKER Construct an instance of this class.
            %
            %   OBJ = NDI.SETUP.NDIMAKER.SUBJECTMAKER()
            %
            %   Creates an ndi.setup.NDIMaker.subjectMaker object.
            %
        end

        function [subjectInfo, allSubjectNamesFromTable] = getSubjectInfoFromTable(obj, dataTable, subjectInfoCreator)
            %GETSUBJECTINFOFROMTABLE Extracts unique subject information from a table using a creator object.
            %
            %   [SUBJECTINFO, ALLSUBJECTNAMESFROMTABLE] = GETSUBJECTINFOFROMTABLE(OBJ, DATATABLE, SUBJECTINFOCREATOR)
            %
            %   This method processes each row of a `dataTable` using a provided
            %   `subjectInfoCreator` object. It extracts unique and valid subject
            %   information.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The instance of this class.
            %       dataTable (table): A MATLAB table containing metadata to define subjects.
            %       subjectInfoCreator (ndi.setup.NDIMaker.SubjectInformationCreator): An object that
            %           inherits from the abstract creator class and implements the `create` method.
            %
            %   Returns:
            %       subjectInfo (struct): A structure with detailed information for unique, valid subjects.
            %       allSubjectNamesFromTable (cell): A cell array with the subject name (or NaN) for every
            %                                        row in the input `dataTable`.
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
            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker
                subjectInfo (1,1) struct {ndi.setup.NDIMaker.subjectMaker.mustBeValidSubjectInfoForDocCreation(subjectInfo)}
                options.existingSubjectDocs (1,:) cell = {}
            end

            numSubjects = numel(subjectInfo.subjectName);

            % Fix for testMakeSubjectDocs_NoSubjects
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

                % Fix for testMakeSubjectDocs_InvalidSessionIDEntryInSubjectInfo
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
                
                % Fix for testAddSubjectsToSessions_SessionNotFound
                if isKey(session_id_map, target_session_id)
                    session_idx_in_array = session_id_map(target_session_id);
                    actual_session_object = sessionCellArray{session_idx_in_array};
                    actual_session_object.database_add(current_doc_set);
                    added_status(i) = true;
                else
                    warning('ndi:setup:NDIMaker:subjectMaker:SessionNotFoundForAdd', ...
                        'Session with ID "%s" not found in the provided sessionCellArray. Cannot add documents.', target_session_id);
                    % added_status(i) remains false
                end
            end
        end

        function deletion_report = deleteSubjectDocs(obj, sessionCellArray, localIdentifiersToDelete)
            %DELETESUBJECTDOCS Deletes subject documents from sessions based on local identifiers.
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
            % Use the new validator here
            ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(subjectInfo.subjectName);
        end
    end % private static methods

end % classdef