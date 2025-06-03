classdef ProbeData < ndi.database.metadata_app.class.MDAData % Inherit from MDAData
    %PROBEDATA A utility class for storing and retrieving information about probes.
    %   Implements the MDAData interface.

    properties
        ProbeList (1,:) cell % Cell array to hold different types of probe objects
        % TypeAssigned can be removed if ClassType is a reliable field in each probe struct/object
        % For now, keeping it as it was, but its usage might need review.
        TypeAssigned 
    end

    methods
        function obj = ProbeData()
            % Constructor
            fprintf('DEBUG (ProbeData): Constructor called.\n');
            obj.ClearAll(); % Initialize properties by calling ClearAll
        end

        % --- MDAData Interface Implementation ---
        function ClearAll(obj)
            %CLEARALL Clears all data items from the object.
            fprintf('DEBUG (ProbeData): ClearAll called.\n');
            obj.ProbeList = {};
            obj.TypeAssigned = containers.Map; % Re-initialize
        end

        function outputStructArray = toStructs(obj)
            %TOSTRUCTS Converts the internal list of probe objects to an array of plain structs.
            %   Returns a 0x1 struct with fields if the list is empty.
            fprintf('DEBUG (ProbeData): toStructs called. Number of probes: %d\n', numel(obj.ProbeList));
            if isempty(obj.ProbeList)
                % Define fields for an empty struct array based on expected probe properties
                outputStructArray = struct('Name', {}, 'ClassType', {}, 'InternalDetails', {}); % Added InternalDetails as a generic field
                fprintf('DEBUG (ProbeData): ProbeList is empty, returning 0x1 struct with defined fields.\n');
                return;
            end
            
            numProbes = numel(obj.ProbeList);
            % Preallocate struct array with a template from the first valid probe
            % or a default template if the first is problematic.
            templateStruct = struct('Name', '', 'ClassType', '', 'InternalDetails', struct()); 
            firstValidProbeProcessed = false;
            for k = 1:numProbes % Find first valid probe to get field names for template
                probe_k = obj.ProbeList{k};
                if isobject(probe_k) && ismethod(probe_k, 'toStruct')
                    try
                        tempS = probe_k.toStruct();
                        % Ensure essential fields exist, even if toStruct doesn't return them all
                        if ~isfield(tempS, 'Name'), tempS.Name = ''; end
                        if ~isfield(tempS, 'ClassType'), tempS.ClassType = class(probe_k); end
                        if ~isfield(tempS, 'InternalDetails'), tempS.InternalDetails = struct(); end % Generic placeholder
                        
                        templateStruct = tempS; % Use this as the template
                        % Remove all data from template, keeping only field names
                        fields = fieldnames(templateStruct);
                        for f_idx = 1:numel(fields)
                            templateStruct.(fields{f_idx}) = []; 
                        end
                        firstValidProbeProcessed = true;
                        break; 
                    catch ME_template
                         fprintf(2, 'Warning (ProbeData/toStructs): Error creating template from probe %d: %s\n', k, ME_template.message);
                    end
                end
            end
            
            if ~firstValidProbeProcessed && numProbes > 0
                 fprintf(2, 'Warning (ProbeData/toStructs): No valid probe object with toStruct method found to create template. Using default template.\n');
            end

            outputStructArray = repmat(templateStruct, numProbes, 1);

            for k = 1:numProbes
                probe_k = obj.ProbeList{k};
                fprintf('DEBUG (ProbeData/toStructs): Processing probe %d of type %s.\n', k, class(probe_k));
                if isobject(probe_k) && ismethod(probe_k, 'toStruct')
                    try
                        struct_k = probe_k.toStruct();
                        % Ensure all fields from templateStruct are present in struct_k
                        % and assign, otherwise use default from template (which is empty)
                        fields_template = fieldnames(templateStruct);
                        for f_idx = 1:numel(fields_template)
                            fieldName = fields_template{f_idx};
                            if isfield(struct_k, fieldName)
                                outputStructArray(k).(fieldName) = struct_k.(fieldName);
                            else
                                % Field missing in probe_k.toStruct(), keep template's default (empty)
                                % Or, if templateStruct had actual defaults, they would be used.
                                % For now, template fields are set to [] so this will keep them empty.
                                outputStructArray(k).(fieldName) = []; 
                                 fprintf('DEBUG (ProbeData/toStructs): Field "%s" missing in toStruct output for probe %d. Using default empty.\n', fieldName, k);
                            end
                        end
                    catch ME_tostruct
                        fprintf(2, 'Error (ProbeData/toStructs): Could not convert probe %d to struct: %s. Leaving as default empty fields.\n', k, ME_tostruct.message);
                        % outputStructArray(k) will remain as the default empty field struct
                    end
                else
                    fprintf(2, 'Warning (ProbeData/toStructs): Probe %d is not an object or lacks toStruct method. Creating default struct.\n', k);
                    % outputStructArray(k) will remain as the default empty field struct
                end
            end
            if isempty(outputStructArray) && numProbes > 0
                % This case should not be reached if templateStruct is properly initialized
                outputStructArray = repmat(templateStruct,0,1);
            elseif isempty(outputStructArray) && numProbes == 0
                 outputStructArray = repmat(templateStruct,0,1);
            end
             fprintf('DEBUG (ProbeData): toStructs finished.\n');
        end

        function fromStructs(obj, inputStructArray)
            %FROMSTRUCTS Populates ProbeList from an array of plain structs.
            obj.ClearAll(); % Clear existing data first
            fprintf('DEBUG (ProbeData): fromStructs called. Input array size: %dx%d\n', size(inputStructArray,1), size(inputStructArray,2));

            if ~isstruct(inputStructArray) || isempty(inputStructArray)
                if ~isstruct(inputStructArray) && ~isempty(inputStructArray)
                    fprintf(2, 'Warning (ProbeData/fromStructs): Input is not a struct array. ProbeList will be empty.\n');
                else
                    fprintf('DEBUG (ProbeData/fromStructs): Input struct array is empty. ProbeList will be empty.\n');
                end
                return;
            end

            for k = 1:numel(inputStructArray)
                structIn = inputStructArray(k);
                fprintf('DEBUG (ProbeData/fromStructs): Processing input struct #%d\n', k);
                % disp(structIn);
                
                if isfield(structIn, 'ClassType') && ~isempty(structIn.ClassType)
                    className = char(structIn.ClassType);
                    fullClassName = ['ndi.database.metadata_app.class.' className];
                    
                    if exist(fullClassName, 'class') == 8 % Check if class exists
                        try
                            % Check if the class has a static fromStruct method
                            metaInfo = meta.class.fromName(fullClassName);
                            hasFromStruct = false;
                            for m_idx = 1:numel(metaInfo.MethodList)
                                if strcmp(metaInfo.MethodList(m_idx).Name, 'fromStruct') && metaInfo.MethodList(m_idx).Static
                                    hasFromStruct = true;
                                    break;
                                end
                            end

                            if hasFromStruct
                                probeObj = feval([fullClassName '.fromStruct'], structIn);
                                obj.addProbe(probeObj); % Use the corrected addProbe method
                                fprintf('DEBUG (ProbeData/fromStructs): Created and added probe of type %s using fromStruct.\n', className);
                            else
                                % Fallback: Use constructor and then try to set properties
                                fprintf('DEBUG (ProbeData/fromStructs): Class %s missing static fromStruct. Using constructor and setting props.\n', fullClassName);
                                probeObj = feval(fullClassName); % Call constructor
                                propsToSet = fieldnames(structIn);
                                for p_idx = 1:numel(propsToSet)
                                    if isprop(probeObj, propsToSet{p_idx})
                                        try
                                            probeObj.(propsToSet{p_idx}) = structIn.(propsToSet{p_idx});
                                        catch ME_setprop
                                            fprintf(2, 'Warning (ProbeData/fromStructs): Could not set property %s on %s: %s\n', propsToSet{p_idx}, className, ME_setprop.message);
                                        end
                                    end
                                end
                                obj.addProbe(probeObj);
                            end
                        catch ME_create
                            fprintf(2, 'Error (ProbeData/fromStructs): Could not create/populate probe of type %s: %s\n', className, ME_create.message);
                        end
                    else
                        fprintf(2, 'Warning (ProbeData/fromStructs): Class %s not found. Cannot create probe object.\n', fullClassName);
                    end
                else
                    fprintf(2, 'Warning (ProbeData/fromStructs): Struct #%d missing ClassType field or it is empty. Skipping.\n', k);
                end
            end
            fprintf('DEBUG (ProbeData): fromStructs finished.\n');
        end
        
        % --- Existing/Modified Methods ---
        function createNewProbe(obj, probeType) % Removed unused index argument
            % Creates a new probe object of the specified type and adds it to ProbeList.
            fprintf('DEBUG (ProbeData): createNewProbe called for type: %s\n', probeType);
            probe = [];
            fullClassName = ['ndi.database.metadata_app.class.' probeType];
            
            if exist(fullClassName, 'class') == 8
                try
                    probe = feval(fullClassName); % Call constructor
                    probe.Name = ['New ' probeType]; % Default name
                catch ME_construct
                    fprintf(2, 'Error (ProbeData/createNewProbe): Could not construct probe of type %s: %s\n', probeType, ME_construct.message);
                    return; % Exit if construction fails
                end
            else
                fprintf(2, 'Error (ProbeData/createNewProbe): Probe class %s not found.\n', fullClassName);
                return; % Exit if class not found
            end
            
            if ~isempty(probe)
                obj.addProbe(probe); % Use the corrected addProbe method
                fprintf('DEBUG (ProbeData): Added new probe of type %s.\n', probeType);
            end
        end

        function addProbe(obj, probe) % Corrected method name from addNewProbe and removed index
            %ADDS Adds a probe object to the ProbeList.
            if isobject(probe) % Basic check
                obj.ProbeList{end + 1} = probe;
                fprintf('DEBUG (ProbeData): Probe added to ProbeList. Total: %d\n', numel(obj.ProbeList));
            else
                fprintf(2, 'Warning (ProbeData/addProbe): Attempted to add a non-object to ProbeList.\n');
            end
        end

        function replaceProbe(obj, index, probeData)
            %REPLACEPROBE Replaces a probe at a given index.
            %   probeData can be a probe object or a struct to create/update a probe object.
            fprintf('DEBUG (ProbeData): replaceProbe called for index %d.\n', index);
            if index > 0 && index <= numel(obj.ProbeList)
                if isobject(probeData) && isa(probeData, 'handle') % Assuming probe classes are handle
                    obj.ProbeList{index} = probeData;
                    fprintf('DEBUG (ProbeData): Replaced probe at index %d with new object.\n', index);
                elseif isstruct(probeData)
                    % If struct, try to update existing object or create new one
                    if isfield(probeData, 'ClassType') && ~isempty(probeData.ClassType)
                        className = char(probeData.ClassType);
                        fullClassName = ['ndi.database.metadata_app.class.' className];
                        if exist(fullClassName, 'class') == 8
                            try
                                existingProbe = obj.ProbeList{index};
                                if isa(existingProbe, fullClassName) && ismethod(existingProbe, 'fromStruct')
                                    existingProbe.fromStruct(probeData); % Update existing if possible
                                    fprintf('DEBUG (ProbeData): Updated existing probe at index %d from struct.\n', index);
                                elseif ismethod(fullClassName, 'fromStruct')
                                    newProbeObj = feval([fullClassName '.fromStruct'], probeData);
                                    obj.ProbeList{index} = newProbeObj;
                                    fprintf('DEBUG (ProbeData): Replaced probe at index %d with new object created from struct (fromStruct).\n', index);
                                else
                                    newProbeObj = feval(fullClassName); % Constructor
                                    props = fieldnames(probeData);
                                    for p_idx = 1:numel(props)
                                        if isprop(newProbeObj, props{p_idx})
                                            newProbeObj.(props{p_idx}) = probeData.(props{p_idx});
                                        end
                                    end
                                    obj.ProbeList{index} = newProbeObj;
                                    fprintf('DEBUG (ProbeData): Replaced probe at index %d with new object created from struct (manual props).\n', index);
                                end
                            catch ME_replace
                                fprintf(2, 'Error (ProbeData/replaceProbe): Failed to update/create probe from struct: %s\n', ME_replace.message);
                            end
                        else
                             fprintf(2, 'Warning (ProbeData/replaceProbe): Class %s for probe update not found.\n', fullClassName);
                        end
                    else
                        fprintf(2, 'Warning (ProbeData/replaceProbe): Struct for probe update missing ClassType.\n');
                    end
                else
                    fprintf(2, 'Warning (ProbeData/replaceProbe): Invalid data type for probe replacement.\n');
                end
            else
                fprintf(2, 'Warning (ProbeData/replaceProbe): Index %d out of bounds for ProbeList (size %d).\n', index, numel(obj.ProbeList));
            end
        end
        
        function removeProbe(obj, index)
            %REMOVEPROBE Removes a probe from the ProbeList by index.
            if index > 0 && index <= numel(obj.ProbeList)
                obj.ProbeList(index) = [];
                fprintf('DEBUG (ProbeData): Probe at index %d removed. Total: %d\n', index, numel(obj.ProbeList));
            else
                fprintf(2, 'Warning (ProbeData/removeProbe): Index %d out of bounds for ProbeList.\n', index);
            end
        end


        function exist = probeExist(obj, index)
            if numel(obj.ProbeList) < index || isempty(obj.ProbeList{index})
                exist = false; % Changed to logical false
            else
                exist = true; % Changed to logical true
            end
        end

        function t_struct_array = formatTable(obj)
            %FORMATTABLE Formats the ProbeList into a struct array suitable for uitable.
            %   Each probe object in ProbeList should have a toTableStruct() method.
            fprintf('DEBUG (ProbeData): formatTable called. Number of probes: %d\n', numel(obj.ProbeList));
            if isempty(obj.ProbeList)
                t_struct_array = struct('ProbeName', {}, 'ProbeType', {}, 'Status', {}); % Ensure correct fields for empty table
                return;
            end
            
            numProbes = numel(obj.ProbeList);
            % Preallocate with a template from the first valid probe
            % or a default template.
            defaultTableStruct = struct('ProbeName', '', 'ProbeType', '', 'Status', '');
            
            % Dynamically create cell array for struct creation
            tempCellArray = cell(numProbes, numel(fieldnames(defaultTableStruct))); 
            
            validProbesCount = 0;
            for i = 1:numProbes
                if ~isempty(obj.ProbeList{i}) && isobject(obj.ProbeList{i}) && ismethod(obj.ProbeList{i}, 'toTableStruct')
                    try
                        probeStruct = obj.ProbeList{i}.toTableStruct();
                        validProbesCount = validProbesCount + 1;
                        % Ensure all expected fields are present
                        tempCellArray{validProbesCount, 1} = ifthenelse(isfield(probeStruct, 'ProbeName'), probeStruct.ProbeName, defaultTableStruct.ProbeName);
                        tempCellArray{validProbesCount, 2} = ifthenelse(isfield(probeStruct, 'ProbeType'), probeStruct.ProbeType, defaultTableStruct.ProbeType);
                        tempCellArray{validProbesCount, 3} = ifthenelse(isfield(probeStruct, 'Status'), probeStruct.Status, defaultTableStruct.Status);
                    catch ME_format
                         fprintf(2, 'Error (ProbeData/formatTable) calling toTableStruct for probe %d: %s\n', i, ME_format.message);
                         % Skip this probe or add default empty values
                    end
                else
                    fprintf(2, 'Warning (ProbeData/formatTable): Probe %d is empty or not an object with toTableStruct.\n', i);
                end
            end
            
            if validProbesCount > 0
                % Convert cell array to struct array
                fieldNames = fieldnames(defaultTableStruct);
                t_struct_array = cell2struct(tempCellArray(1:validProbesCount,:), fieldNames, 2);
            else
                t_struct_array = struct('ProbeName', {}, 'ProbeType', {}, 'Status', {}); % Empty struct with fields
            end
             fprintf('DEBUG (ProbeData): formatTable finished. Returning struct array of size %dx%d.\n', size(t_struct_array,1), size(t_struct_array,2));
        end

        function list = getPipetteList(obj) % This method seems out of place if ProbeList is generic
            fprintf(2, 'Warning (ProbeData): getPipetteList is likely deprecated. Use ProbeList and filter by type.\n');
            list = {}; 
            for i = 1:numel(obj.ProbeList)
                if isa(obj.ProbeList{i}, 'ndi.database.metadata_app.class.Pipette')
                    list{end+1} = obj.ProbeList{i}; %#ok<AGROW>
                end
            end
        end
    end
end

% Helper function for conditional assignment (inline if-else)
function result = ifthenelse(condition, trueval, falseval)
    if condition
        result = trueval;
    else
        result = falseval;
    end
end
