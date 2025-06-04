classdef SubjectData < ndi.database.metadata_app.class.MDAData % Inherit from MDAData
    %SubjectData A utility class for storing and retrieving information about subjects.
    %   Implements the MDAData interface. [cite: 910]
    properties
        % A list holding Subject objects.
        SubjectList (1,:) ndi.database.metadata_app.class.Subject % [cite: 911] Constraint: (1,:) row vector
    end
    methods
        function obj = SubjectData()
            % Constructor
            fprintf('DEBUG (SubjectData): Constructor called.\n'); % [cite: 912]
            obj.ClearAll(); % Initialize properties by calling ClearAll [cite: 912]
        end
        % --- MDAData Interface Implementation ---
        function ClearAll(obj)
            %CLEARALL Clears all Subject items from the object.
            fprintf('DEBUG (SubjectData): ClearAll called.\n'); % [cite: 913]
            obj.SubjectList = ndi.database.metadata_app.class.Subject.empty(1,0); % MODIFIED: Ensure 1x0 empty row vector
        end
        function outputStructArray = toStructs(obj)
            %TOSTRUCTS Converts the internal list of Subject objects to an array of plain structs.
            %   Returns a 0x1 struct with fields if the list is empty. [cite: 914, 917]
            fprintf('DEBUG (SubjectData): toStructs called. Number of subjects: %d\n', numel(obj.SubjectList)); % [cite: 915]
            if isempty(obj.SubjectList) % [cite: 915]
                tempSubject = ndi.database.metadata_app.class.Subject(); % [cite: 916]
                if ismethod(tempSubject, 'toStruct') % [cite: 916]
                    structFieldsTemplate = tempSubject.toStruct(); % [cite: 917]
                    fn = fieldnames(structFieldsTemplate); % [cite: 918]
                    for k_fn = 1:numel(fn) % [cite: 918]
                        structFieldsTemplate.(fn{k_fn}) = []; % [cite: 919]
                    end
                    outputStructArray = repmat(structFieldsTemplate, 0, 1); % [cite: 920]
                else
                    % Define all expected fields including sessionIdentifier
                    outputStructArray = struct('SubjectName', {}, 'BiologicalSexList', {}, 'SpeciesList', {}, 'StrainList', {}, 'sessionIdentifier', {}); 
                    fprintf(2,'ERROR (SubjectData/toStructs): Subject class missing toStruct method.\n'); % [cite: 921]
                end
                fprintf('DEBUG (SubjectData): SubjectList is empty, returning 0xN struct with defined fields.\n'); % [cite: 922]
                return; % [cite: 922]
            end
            
            numSubjects = numel(obj.SubjectList); % [cite: 923]
            try
                % Preallocate struct array by calling toStruct on the first item
                outputStructArray = repmat(obj.SubjectList(1).toStruct(), numSubjects, 1); % [cite: 924]
                for k = 2:numSubjects % Start from 2 if first one was used for repmat template [cite: 925]
                    outputStructArray(k) = obj.SubjectList(k).toStruct(); % [cite: 926]
                end
                if numSubjects == 1 % if only one subject, the loop for k=2:.. won't run [cite: 926]
                    outputStructArray(1) = obj.SubjectList(1).toStruct(); % [cite: 927]
                end
            catch ME_toStruct % [cite: 927]
                fprintf(2, 'Error (SubjectData/toStructs) converting SubjectList to structs: %s\n', ME_toStruct.message); % [cite: 928]
                outputStructArray = struct([]); % [cite: 929]
                for k = 1:numSubjects % [cite: 929]
                    try
                        outputStructArray(k) = obj.SubjectList(k).toStruct(); % [cite: 930]
                    catch ME_inner % [cite: 930]
                        fprintf(2, 'Error (SubjectData/toStructs) converting subject %d to struct: %s\n', k, ME_inner.message); % [cite: 931]
                         tempSubject = ndi.database.metadata_app.class.Subject(); % [cite: 932]
                         % Ensure template includes sessionIdentifier if toStruct might not
                         structFieldsTemplate = tempSubject.toStruct(); 
                         if ~isfield(structFieldsTemplate, 'sessionIdentifier')
                             structFieldsTemplate.sessionIdentifier = missing;
                         end
                         fn = fieldnames(structFieldsTemplate); % [cite: 933]
                         for k_fn = 1:numel(fn), structFieldsTemplate.(fn{k_fn}) = []; end % [cite: 933]
                         outputStructArray(k) = structFieldsTemplate; % [cite: 934]
                    end
                end
            end
            fprintf('DEBUG (SubjectData): toStructs finished. Output array size: %dx%d\n', size(outputStructArray,1), size(outputStructArray,2)); % [cite: 935]
        end
        function fromStructs(obj, inputStructArray)
            %FROMSTRUCTS Populates SubjectList from an array of plain structs. [cite: 936]
            obj.ClearAll(); % Clear existing data first; SubjectList is now Subject.empty(1,0) [cite: 936]
            fprintf('DEBUG (SubjectData): fromStructs called.\n'); % [cite: 937]
            
            if ~isstruct(inputStructArray) || numel(inputStructArray) == 0
                if ~isstruct(inputStructArray) && ~isempty(inputStructArray)
                     fprintf(2, 'Warning (SubjectData/fromStructs): Input is not a struct array or is an unexpected empty. SubjectList will be empty.\n'); % [cite: 938]
                else
                    fprintf('DEBUG (SubjectData/fromStructs): Input struct array is effectively empty. SubjectList remains 1x0.\n'); % [cite: 939]
                end
                return; % SubjectList is already 1x0 from ClearAll [cite: 940]
            end
            numSubjects = numel(inputStructArray); % [cite: 941]
            
            try
                obj.SubjectList = repmat(ndi.database.metadata_app.class.Subject(), 1, numSubjects);
            catch ME_repmat 
                fprintf(2, 'FATAL (SubjectData/fromStructs): repmat preallocation failed: %s. This indicates an issue with Subject constructor or class definition. SubjectList will be empty.\n', ME_repmat.message);
                obj.SubjectList = ndi.database.metadata_app.class.Subject.empty(1,0); 
                return;
            end
            for k = 1:numSubjects % [cite: 941]
                structIn = inputStructArray(k); % [cite: 942]
                fprintf('DEBUG (SubjectData/fromStructs): Processing input struct #%d\n', k); % [cite: 942]
                try
                    if ismethod('ndi.database.metadata_app.class.Subject', 'fromStruct') % [cite: 943]
                        newSubObj = ndi.database.metadata_app.class.Subject.fromStruct(structIn); % [cite: 943]
                        if isscalar(newSubObj)
                            obj.SubjectList(k) = newSubObj; % [cite: 943]
                        else
                            fprintf(2, 'Error (SubjectData/fromStructs): Subject.fromStruct did not return a scalar for input struct #%d. Assigning default Subject.\n', k);
                            obj.SubjectList(k) = ndi.database.metadata_app.class.Subject();
                        end
                    else
                        fprintf(2, 'Error (SubjectData/fromStructs): Subject class is missing static fromStruct method. Assigning default Subject.\n'); % [cite: 944]
                        obj.SubjectList(k) = ndi.database.metadata_app.class.Subject();
                    end
                catch ME_create % [cite: 944]
                    fprintf(2, 'Error (SubjectData/fromStructs): Could not create/populate Subject object from struct #%d: %s. Assigning default Subject.\n', k, ME_create.message); % [cite: 945]
                    obj.SubjectList(k) = ndi.database.metadata_app.class.Subject();
                end
            end
            
            if ~isrow(obj.SubjectList) && ~isempty(obj.SubjectList)
                obj.SubjectList = reshape(obj.SubjectList, 1, []);
            elseif isempty(obj.SubjectList) && numSubjects == 0 && ~isequal(size(obj.SubjectList), [1 0]) 
                 obj.SubjectList = ndi.database.metadata_app.class.Subject.empty(1,0);
            end
            fprintf('DEBUG (SubjectData): fromStructs finished. SubjectList populated with %d subjects. Size: %s\n', numel(obj.SubjectList), mat2str(size(obj.SubjectList))); % [cite: 946]
        end
        
        % --- Existing Methods ---
        function removeItem(obj, subjectIndex)
            if subjectIndex > 0 && subjectIndex <= numel(obj.SubjectList) % [cite: 947]
                obj.SubjectList(subjectIndex) = []; % [cite: 947]
                fprintf('DEBUG (SubjectData): Removed subject at index %d.\n', subjectIndex); % [cite: 947]
            else
                fprintf(2, 'Warning (SubjectData/removeItem): Invalid subjectIndex %d.\n', subjectIndex); % [cite: 948]
            end
        end
        function newSubject = addItem(obj)
            newSubject = ndi.database.metadata_app.class.Subject(); % [cite: 949]
            newSubject.SubjectName = sprintf("NewSubject%d", numel(obj.SubjectList)+1); % [cite: 950]
            if isempty(obj.SubjectList) % [cite: 950]
                obj.SubjectList = newSubject; % [cite: 951]
            else
                obj.SubjectList(end+1) = newSubject; % [cite: 952]
            end
            fprintf('DEBUG (SubjectData): Added new subject. Total subjects: %d.\n', numel(obj.SubjectList)); % [cite: 953]
        end
        function assignName(obj) 
            for i = 1:numel(obj.SubjectList) % [cite: 954]
                if ismissing(obj.SubjectList(i).SubjectName) || obj.SubjectList(i).SubjectName == "" % [cite: 954]
                    obj.SubjectList(i).SubjectName = sprintf("subject%d", i); % [cite: 955]
                end
            end
        end
        function idx = getIndex(obj, subjectName)
            idx = -1; % [cite: 956]
            for i = 1:numel(obj.SubjectList) % [cite: 956]
                if isprop(obj.SubjectList(i),'SubjectName') && strcmp(obj.SubjectList(i).SubjectName, subjectName) % [cite: 957]
                    idx = i; % [cite: 957]
                    break; % [cite: 957]
                end
            end
        end
        function S = getItem(obj, subjectIndex)
            if subjectIndex > 0 && subjectIndex <= numel(obj.SubjectList) % [cite: 958]
                S = obj.SubjectList(subjectIndex); % [cite: 958]
            else
                S = ndi.database.metadata_app.class.Subject.empty(1,0); % MODIFIED: ensure (1,0) for consistency [cite: 959]
                fprintf(2, 'Warning (SubjectData/getItem): Invalid subjectIndex %d.\n', subjectIndex); % [cite: 960]
            end
        end
        function S = getSubjectList(obj)
            S = obj.SubjectList; % [cite: 961]
        end
        function setSubjectList(obj, S)
            if (isa(S, 'ndi.database.metadata_app.class.Subject') && isrow(S)) || (isempty(S) && (isequal(size(S),[1 0]) || isequal(size(S),[0 0]) ) ) % Allow 1x0 or 0x0 for empty [cite: 962]
                obj.SubjectList = S; % [cite: 963]
            else
                fprintf(2, 'Error (SubjectData/setSubjectList): Input must be a row array of Subject objects or a compatible empty array.\n'); % [cite: 964]
            end
        end
        
        function clearAllSubjects(obj) 
            obj.ClearAll(); % [cite: 965]
        end
        function selected = biologicalSexSelected(obj, subjectName)
            idx = obj.getIndex(subjectName); % [cite: 966]
            selected = false; % Default to false % [cite: 966]
            if idx > 0 % [cite: 966]
                sex = obj.SubjectList(idx).BiologicalSexList; % [cite: 967]
                if ~isempty(sex) && (~iscell(sex) || ~isempty(sex{1})) % Check if not empty cell or cell with empty string % [cite: 967]
                    selected = true; % [cite: 968]
                end
            end
        end
        function selected = SpeciesSelected(obj, subjectName)
            idx = obj.getIndex(subjectName); % [cite: 969]
            selected = false; % Default to false % [cite: 969]
            if idx > 0 % [cite: 969]
                speciesList = obj.SubjectList(idx).SpeciesList; % [cite: 970]
                if ~isempty(speciesList) % [cite: 970]
                    hasValidSpecies = false; % [cite: 971]
                    for k=1:numel(speciesList) % [cite: 971]
                        if isprop(speciesList(k), 'Name') && ~ismissing(speciesList(k).Name) && speciesList(k).Name ~= "" % [cite: 972]
                            hasValidSpecies = true; % [cite: 972]
                            break; % [cite: 972]
                        end
                    end
                    selected = hasValidSpecies; % [cite: 973]
                end
            end
        end
        
        % MODIFIED formatTable method
        function data = formatTable(obj)
            fprintf('DEBUG (SubjectData): formatTable called.\n'); % [cite: 974]
            if isempty(obj.SubjectList) % [cite: 974]
                % Ensure SessionIdentifier is included in the empty struct definition
                data = struct('SubjectName', {}, 'BiologicalSexList', {}, 'SpeciesList', {}, 'StrainList', {}, 'sessionIdentifier', {}); % MODIFIED
                return; % [cite: 975]
            end
            
            numSubjects = numel(obj.SubjectList); % [cite: 976]
            
            % Define a template including SessionIdentifier
            % Option 1: If Subject.formatTable() is also updated to return SessionIdentifier
            % try 
            %     template = obj.SubjectList(1).formatTable(); % This would need to include sessionIdentifier
            %     if ~isfield(template, 'sessionIdentifier') % Ensure field exists in template from subject.formatTable
            %         template.sessionIdentifier = '';
            %     end
            % catch
            %     template = struct('SubjectName', '', 'BiologicalSexList', '', 'SpeciesList', '', 'StrainList', '', 'sessionIdentifier', '');
            % end

            % Option 2: Manually construct the struct here for clarity on included fields
            % This option is chosen for explicitness.
            template = struct('SubjectName', '', 'BiologicalSexList', '', 'SpeciesList', '', 'StrainList', '', 'sessionIdentifier', '');
            
            data = repmat(template, numSubjects, 1); % [cite: 980]
            
            for i = 1:numSubjects % [cite: 980]
                try % [cite: 981]
                    % Call existing formatTable from Subject object
                    subjectFormattedData = obj.SubjectList(i).formatTable(); % [cite: 981]
                    data(i).SubjectName = subjectFormattedData.SubjectName;
                    data(i).BiologicalSexList = subjectFormattedData.BiologicalSexList;
                    data(i).SpeciesList = subjectFormattedData.SpeciesList;
                    data(i).StrainList = subjectFormattedData.StrainList;
                    % Directly access and assign sessionIdentifier
                    if isprop(obj.SubjectList(i), 'sessionIdentifier') && ~ismissing(obj.SubjectList(i).sessionIdentifier)
                        data(i).sessionIdentifier = char(obj.SubjectList(i).sessionIdentifier);
                    else
                        data(i).sessionIdentifier = ''; % Default if missing or not set
                    end
                catch ME_format % [cite: 981]
                     fprintf(2, 'Error (SubjectData/formatTable) formatting subject %d for table: %s\n', i, ME_format.message); % [cite: 982]
                     data(i).SubjectName = sprintf('ErrorFormattingSubject%d',i); % [cite: 983]
                     data(i).BiologicalSexList = ''; % [cite: 983]
                     data(i).SpeciesList = ''; % [cite: 983]
                     data(i).StrainList = ''; % [cite: 983]
                     data(i).sessionIdentifier = 'Error'; % MODIFIED
                end
            end
            if isempty(data) && numSubjects > 0 % [cite: 984]
                 data = repmat(template,0,1); % [cite: 984]
            elseif isempty(data) && numSubjects == 0 % [cite: 984]
                 data = repmat(template,0,1); % [cite: 985]
            end
        end
    end
end