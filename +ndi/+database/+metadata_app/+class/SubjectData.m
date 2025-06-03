classdef SubjectData < ndi.database.metadata_app.class.MDAData % Inherit from MDAData
    %SubjectData A utility class for storing and retrieving information about subjects.
    %   Implements the MDAData interface.

    properties
        % A list holding Subject objects.
        SubjectList (1,:) ndi.database.metadata_app.class.Subject 
    end

    methods
        function obj = SubjectData()
            % Constructor
            fprintf('DEBUG (SubjectData): Constructor called.\n');
            obj.ClearAll(); % Initialize properties
        end

        % --- MDAData Interface Implementation ---
        function ClearAll(obj)
            %CLEARALL Clears all Subject items from the object.
            fprintf('DEBUG (SubjectData): ClearAll called.\n');
            obj.SubjectList = ndi.database.metadata_app.class.Subject.empty(0,1);
        end

        function outputStructArray = toStructs(obj)
            %TOSTRUCTS Converts the internal list of Subject objects to an array of plain structs.
            %   Returns a 0x1 struct with fields if the list is empty.
            fprintf('DEBUG (SubjectData): toStructs called. Number of subjects: %d\n', numel(obj.SubjectList));
            if isempty(obj.SubjectList)
                % Create a template from a default Subject object's toStruct method
                tempSubject = ndi.database.metadata_app.class.Subject();
                if ismethod(tempSubject, 'toStruct')
                    structFieldsTemplate = tempSubject.toStruct();
                    % Ensure all fields are initialized as empty cell for repmat
                    fn = fieldnames(structFieldsTemplate);
                    for k_fn = 1:numel(fn)
                        structFieldsTemplate.(fn{k_fn}) = [];
                    end
                    outputStructArray = repmat(structFieldsTemplate, 0, 1);
                else
                    % Fallback if Subject.toStruct is missing (should not happen)
                    outputStructArray = struct('SubjectName', {}, 'BiologicalSexList', {}, 'SpeciesList', {}, 'StrainList', {});
                     fprintf(2,'ERROR (SubjectData/toStructs): Subject class missing toStruct method.\n');
                end
                fprintf('DEBUG (SubjectData): SubjectList is empty, returning 0xN struct with defined fields.\n');
                return;
            end
            
            numSubjects = numel(obj.SubjectList);
            % Preallocate struct array by calling toStruct on the first item
            % This assumes all Subject objects will return structs with the same fields.
            try
                outputStructArray = repmat(obj.SubjectList(1).toStruct(), numSubjects, 1);
                for k = 2:numSubjects % Start from 2 if first one was used for repmat template
                    outputStructArray(k) = obj.SubjectList(k).toStruct();
                end
                if numSubjects == 1 % if only one subject, the loop for k=2:.. won't run
                    outputStructArray(1) = obj.SubjectList(1).toStruct();
                end

            catch ME_toStruct
                fprintf(2, 'Error (SubjectData/toStructs) converting SubjectList to structs: %s\n', ME_toStruct.message);
                % Fallback to iterative construction if repmat fails (e.g. first element is problematic)
                outputStructArray = struct([]); % Initialize as empty struct array
                for k = 1:numSubjects
                    try
                        outputStructArray(k) = obj.SubjectList(k).toStruct();
                    catch ME_inner
                        fprintf(2, 'Error (SubjectData/toStructs) converting subject %d to struct: %s\n', k, ME_inner.message);
                        % Add an empty struct with expected fields if one fails
                         tempSubject = ndi.database.metadata_app.class.Subject();
                         structFieldsTemplate = tempSubject.toStruct();
                         fn = fieldnames(structFieldsTemplate);
                         for k_fn = 1:numel(fn), structFieldsTemplate.(fn{k_fn}) = []; end
                         outputStructArray(k) = structFieldsTemplate;
                    end
                end
            end
            fprintf('DEBUG (SubjectData): toStructs finished. Output array size: %dx%d\n', size(outputStructArray,1), size(outputStructArray,2));
        end

        function fromStructs(obj, inputStructArray)
            %FROMSTRUCTS Populates SubjectList from an array of plain structs.
            obj.ClearAll(); % Clear existing data first
            fprintf('DEBUG (SubjectData): fromStructs called.\n');

            if ~isstruct(inputStructArray) || isempty(inputStructArray)
                if ~isstruct(inputStructArray) && ~isempty(inputStructArray)
                     fprintf(2, 'Warning (SubjectData/fromStructs): Input is not a struct array. SubjectList will be empty.\n');
                else
                    fprintf('DEBUG (SubjectData/fromStructs): Input struct array is empty. SubjectList will be empty.\n');
                end
                return;
            end

            numSubjects = numel(inputStructArray);
            obj.SubjectList = ndi.database.metadata_app.class.Subject.empty(0, numSubjects); % Preallocate if possible

            for k = 1:numSubjects
                structIn = inputStructArray(k);
                fprintf('DEBUG (SubjectData/fromStructs): Processing input struct #%d\n', k);
                try
                    % Use the static fromStruct method of the Subject class
                    if ismethod('ndi.database.metadata_app.class.Subject', 'fromStruct')
                        newSubObj = ndi.database.metadata_app.class.Subject.fromStruct(structIn);
                        obj.SubjectList(k) = newSubObj;
                    else
                        fprintf(2, 'Error (SubjectData/fromStructs): Subject class is missing static fromStruct method.\n');
                        % Fallback or error handling if fromStruct is not available
                    end
                catch ME_create
                    fprintf(2, 'Error (SubjectData/fromStructs): Could not create/populate Subject object from struct #%d: %s\n', k, ME_create.message);
                end
            end
            fprintf('DEBUG (SubjectData): fromStructs finished. SubjectList populated with %d subjects.\n', numel(obj.SubjectList));
        end
        
        % --- Existing Methods ---
        function removeItem(obj, subjectIndex)
            if subjectIndex > 0 && subjectIndex <= numel(obj.SubjectList)
                obj.SubjectList(subjectIndex) = [];
                fprintf('DEBUG (SubjectData): Removed subject at index %d.\n', subjectIndex);
            else
                fprintf(2, 'Warning (SubjectData/removeItem): Invalid subjectIndex %d.\n', subjectIndex);
            end
        end

        function newSubject = addItem(obj)
            newSubject = ndi.database.metadata_app.class.Subject();
            % Assign a default name if needed, or handle in Subject class constructor
            newSubject.SubjectName = sprintf("NewSubject%d", numel(obj.SubjectList)+1); 
            if isempty(obj.SubjectList)
                obj.SubjectList = newSubject;
            else
                obj.SubjectList(end+1) = newSubject;
            end
            fprintf('DEBUG (SubjectData): Added new subject. Total subjects: %d.\n', numel(obj.SubjectList));
        end

        function assignName(obj) % This might be redundant if addItem assigns a default name
            for i = 1:numel(obj.SubjectList)
                if ismissing(obj.SubjectList(i).SubjectName) || obj.SubjectList(i).SubjectName == ""
                    obj.SubjectList(i).SubjectName = sprintf("subject%d", i);
                end
            end
        end

        function idx = getIndex(obj, subjectName)
            idx = -1;
            for i = 1:numel(obj.SubjectList)
                if isprop(obj.SubjectList(i),'SubjectName') && strcmp(obj.SubjectList(i).SubjectName, subjectName)
                    idx = i;
                    break;
                end
            end
        end

        function S = getItem(obj, subjectIndex)
            if subjectIndex > 0 && subjectIndex <= numel(obj.SubjectList)
                S = obj.SubjectList(subjectIndex);
            else
                S = ndi.database.metadata_app.class.Subject.empty(); % Return empty Subject object
                fprintf(2, 'Warning (SubjectData/getItem): Invalid subjectIndex %d.\n', subjectIndex);
            end
        end

        function S = getSubjectList(obj)
            S = obj.SubjectList;
        end

        function setSubjectList(obj, S)
            if isa(S, 'ndi.database.metadata_app.class.Subject') || isempty(S)
                obj.SubjectList = S;
            else
                fprintf(2, 'Error (SubjectData/setSubjectList): Input must be an array of Subject objects or empty.\n');
            end
        end
        
        function clearAllSubjects(obj) % Alias for ClearAll for backward compatibility if used elsewhere
            obj.ClearAll();
        end


        function selected = biologicalSexSelected(obj, subjectName)
            idx = obj.getIndex(subjectName);
            selected = false; % Default to false
            if idx > 0
                sex = obj.SubjectList(idx).BiologicalSexList;
                if ~isempty(sex) && (~iscell(sex) || ~isempty(sex{1})) % Check if not empty cell or cell with empty string
                    selected = true;
                end
            end
        end

        function selected = SpeciesSelected(obj, subjectName)
            idx = obj.getIndex(subjectName);
            selected = false; % Default to false
            if idx > 0
                speciesList = obj.SubjectList(idx).SpeciesList;
                if ~isempty(speciesList)
                    % Check if the SpeciesList contains actual species objects with names
                    hasValidSpecies = false;
                    for k=1:numel(speciesList)
                        if isprop(speciesList(k), 'Name') && ~ismissing(speciesList(k).Name) && speciesList(k).Name ~= ""
                            hasValidSpecies = true;
                            break;
                        end
                    end
                    selected = hasValidSpecies;
                end
            end
        end

        function data = formatTable(obj)
            % This should return a struct array suitable for uitable display
            fprintf('DEBUG (SubjectData): formatTable called.\n');
            if isempty(obj.SubjectList)
                data = struct('SubjectName', {}, 'BiologicalSexList', {}, 'SpeciesList', {}, 'StrainList', {});
                return;
            end
            
            numSubjects = numel(obj.SubjectList);
            % Preallocate with a template from the first subject's formatTable
            % or a default template if the first is problematic.
            try
                template = obj.SubjectList(1).formatTable(); % Assuming this returns a scalar struct
            catch
                template = struct('SubjectName', '', 'BiologicalSexList', '', 'SpeciesList', '', 'StrainList', '');
            end
            
            data = repmat(template, numSubjects, 1); % Preallocate struct array
            
            for i = 1:numSubjects
                try
                    data(i) = obj.SubjectList(i).formatTable();
                catch ME_format
                     fprintf(2, 'Error (SubjectData/formatTable) formatting subject %d for table: %s\n', i, ME_format.message);
                     % Fill with default empty values if formatting fails
                     data(i).SubjectName = sprintf('ErrorFormattingSubject%d',i);
                     data(i).BiologicalSexList = '';
                     data(i).SpeciesList = '';
                     data(i).StrainList = '';
                end
            end
            if isempty(data) && numSubjects > 0 % Should not happen if template is good
                 data = repmat(template,0,1);
            elseif isempty(data) && numSubjects == 0
                 data = repmat(template,0,1);
            end
        end
    end
end
