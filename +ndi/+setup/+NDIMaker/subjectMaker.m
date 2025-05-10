% Filename: +ndi/+setup/+NDIMaker/subjectMaker.m % Corrected path casing

classdef subjectMaker % Class name remains subjectMaker
%SUBJECTMAKER A helper class to extract subject information from tables. % Corrected H1 casing
%   Provides methods to facilitate the extraction of unique subject
%   information based on metadata in tables, intended for use in NDI import
%   workflows. Resides in the ndi.setup.NDIMaker package. % Corrected package casing

    properties
        % No properties defined in this version.
    end

    methods
        function obj = subjectMaker() % Constructor name remains subjectMaker
            %SUBJECTMAKER Construct an instance of this class % Constructor doc
            %
            %   OBJ = NDI.SETUP.NDIMAKER.SUBJECTMAKER() % Corrected package casing
            %
            %   Creates a subjectMaker object. Takes no arguments. % Constructor doc
            %
        end

        function subjectInfo = getSubjectInfoFromTable(obj, dataTable, subjectInfoFun)
            %GETSUBJECTINFOFROMTABLE Extracts unique subject info by applying a function to table rows.
            %
            %   subjectInfo = GETSUBJECTINFOFROMTABLE(OBJ, dataTable, subjectInfoFun)
            %
            %   Applies a user-provided function to each row of a data table
            %   to extract subject information (ID, strain, species, sex).
            %   It then filters this information to return data only for
            %   unique, valid subject IDs found in the table.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The subjectMaker object instance. % Corrected package casing
            %       dataTable (table): A MATLAB table where each row contains
            %                        metadata potentially defining a subject.
            %                        Must contain columns needed by subjectInfoFun.
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
            %                        Returns an empty struct with empty fields if no
            %                        valid, unique subjects are found.

            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker % Corrected package casing
                dataTable table {mustBeNonempty}
                subjectInfoFun (1,1) function_handle
            end

            numRows = height(dataTable);

            % Preallocate cell arrays to store results from all rows
            allSubjectNames = cell(numRows, 1);
            allStrains = cell(numRows, 1);
            allSpecies = cell(numRows, 1);
            allBiologicalSex = cell(numRows, 1);
            allTableRowIndex = (1:numRows)'; % Store original index

            validRowProcessed = false(numRows, 1); % Keep track of rows processed without error

            % --- Loop 1: Extract info from all rows ---
            for i = 1:numRows
                currentRow = dataTable(i, :);
                try
                    % Call the user-provided function to get the subject info
                    [local_id, strain_obj, species_obj, sex_obj] = subjectInfoFun(currentRow);

                    % Store results (even if local_id is NaN for now)
                    allSubjectNames{i} = local_id;
                    allStrains{i} = strain_obj;
                    allSpecies{i} = species_obj;
                    allBiologicalSex{i} = sex_obj;
                    validRowProcessed(i) = true; % Mark row as processed

                catch ME_Func
                    warning('ndi.setup.NDIMaker.subjectMaker:subjectInfoFunError', ... % Corrected package casing in warning ID
                        'Error executing subjectInfoFun for table row %d: %s. Skipping row.', i, ME_Func.message);
                    % Leave preallocated NaNs/empty cells for this row
                end
            end

            % --- Filter for valid and unique subjects ---
            % Find rows that were processed AND have a valid (char) subject name
            isValidName = cellfun(@(x) ischar(x) && ~isempty(x), allSubjectNames);
            validIndices = find(isValidName & validRowProcessed);

            if isempty(validIndices)
                % Return empty struct if no valid subjects found
                 subjectInfo = struct(...
                    'subjectName', {{}}, ...
                    'strain', {{}}, ...
                    'species', {{}}, ...
                    'biologicalSex', {{}}, ...
                    'tableRowIndex', [] ...
                 );
                return;
            end

            % Extract data only for rows with valid subject names
            validSubjectNames = allSubjectNames(validIndices);
            validStrains = allStrains(validIndices);
            validSpecies = allSpecies(validIndices);
            validBiologicalSex = allBiologicalSex(validIndices);
            validOriginalIndices = allTableRowIndex(validIndices);

            % Find the indices of the *first* occurrence of each unique valid subject name
            [uniqueNames, ia, ~] = unique(validSubjectNames, 'stable'); % 'stable' keeps first occurrence

            % Select the data corresponding to these unique first occurrences
            uniqueStrains = validStrains(ia);
            uniqueSpecies = validSpecies(ia);
            uniqueBiologicalSex = validBiologicalSex(ia);
            uniqueOriginalIndices = validOriginalIndices(ia);

            % --- Create Output Struct ---
            subjectInfo = struct(...
                'subjectName', {uniqueNames}, ...           % Cell array of unique names
                'strain', {uniqueStrains}, ...             % Cell array of corresponding strains
                'species', {uniqueSpecies}, ...            % Cell array of corresponding species
                'biologicalSex', {uniqueBiologicalSex}, ...% Cell array of corresponding sexes
                'tableRowIndex', uniqueOriginalIndices ... % Numeric vector of original indices
            );

        end % function getSubjectInfoFromTable


        % --- Deprecated/Needs Refactoring ---
        % This method depended on the output of the removed 'makeSubjectDocs'
        % It needs to be updated to work with the 'subjectInfo' struct
        % or potentially removed/replaced depending on the workflow.
        function added_status = addSubjectsToSessions(obj, sessionArray, subjectDocuments)
            %ADDSUBJECTSTOSESSIONS Adds subject documents to sessions if not already present.
            % *** NOTE: This function is currently incompatible with the output of
            %     getSubjectInfoFromTable and needs refactoring. ***
            %
            %   added_status = ADDSUBJECTSTOSESSIONS(OBJ, sessionArray, subjectDocuments)
            %
            %   Checks each NDI session for existing subject documents matching those
            %   provided in subjectDocuments (based on local identifier) and adds
            %   any missing subject documents to the database via the session object.
            %
            %   Args:
            %       obj (ndi.setup.NDIMaker.subjectMaker): The subjectMaker object instance. % Corrected package casing
            %       sessionArray (ndi.session.dir vector): An array of NDI session
            %                                          directory objects.
            %       subjectDocuments (cell vector): A cell array of NDI subject
            %                                     document objects (e.g., generated
            %                                     by the *previous* makeSubjectDocs).
            %
            %   Returns:
            %       added_status (logical vector): A boolean vector of the same size
            %                                    as subjectDocuments. added_status(i)
            %                                    is true if subjectDocuments{i} was
            %                                    added to its corresponding session's
            %                                    database, false otherwise.

            arguments
                obj (1,1) ndi.setup.NDIMaker.subjectMaker % Corrected package casing
                sessionArray (1,:) ndi.session.dir % Assuming object array, adjust if cell
                subjectDocuments (1,:) cell {mustBeVector} % This input is problematic now
            end

            warning('ndi.setup.NDIMaker.subjectMaker:DeprecatedFunction', ... % Corrected package casing in warning ID
                    'addSubjectsToSessions is not compatible with the current class structure and needs refactoring.');

            numSubjectDocs = numel(subjectDocuments);
            added_status = false(1, numSubjectDocs); % Initialize status vector

            if isempty(subjectDocuments) || isempty(sessionArray)
                return; % Nothing to do
            end

            % --- The rest of this function's logic is likely invalid ---
            % --- as it assumes subjectDocuments are pre-made documents ---
            expected_doc_type = 'subject';
            subjects_by_session = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % (Code from previous version omitted for brevity as it needs rewrite)
            disp('Placeholder: addSubjectsToSessions logic needs complete rewrite.');


        end % function addSubjectsToSessions

    end % methods block

end % classdef subjectMaker % Class name remains subjectMaker


% --- Local Validation Functions ---
% Removed unused local validation functions: mustBeIntegerOrNan, mustMatchTableRows
