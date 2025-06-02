classdef Subject < handle
    %SUBJECT Summary of this class goes here
    %   Detailed explanation goes here
    properties
        SubjectName (1,1) string = missing
        BiologicalSexList (1,:) cell = {} % Initialize as empty cell
        SpeciesList (1,:) ndi.database.metadata_app.class.Species
        StrainList (1,:) ndi.database.metadata_app.class.Strain
        StrainMap
        sessionIdentifier (1,1) string = missing % Initialize as missing
    end
    methods
        function obj = Subject()
            obj.StrainMap = containers.Map;
            % Initialize SpeciesList and StrainList to correctly typed empty arrays
            obj.SpeciesList = ndi.database.metadata_app.class.Species.empty(0,1);
            obj.StrainList = ndi.database.metadata_app.class.Strain.empty(0,1);
        end
        function updateProperty(obj, name, idx, value)
            obj.(name)(idx)=value;
        end
        function addItem(obj, name, value)
            % Ensure the property exists before trying to append
            if ~isprop(obj, name)
                fprintf(2, 'Warning (Subject/addItem): Property "%s" does not exist.\n', name);
                return;
            end
            % Handle case where property might be empty and needs initialization
            if isempty(obj.(name))
                obj.(name) = value; % Assign directly if it's the first item
            else
                try
                    obj.(name)(end+1) = value;
                catch ME
                    fprintf(2, 'Error (Subject/addItem) appending to "%s": %s\n', name, ME.message);
                    % Attempt to re-initialize as a cell if it's a common issue
                    if ~iscell(obj.(name)) && (ischar(obj.(name)) || isstring(obj.(name)))
                        fprintf(1, 'Attempting to convert "%s" to cell array for appending.\n', name);
                        obj.(name) = {obj.(name)};
                        obj.(name){end+1} = value;
                    end
                end
            end
        end
        function addStrain(obj, strainName)
            % This method should add to a list, not overwrite.
            % Assuming StrainList should hold multiple Strain objects.
            newStrain = ndi.database.metadata_app.class.Strain(strainName);
            if isempty(obj.StrainList)
                obj.StrainList = newStrain;
            else
                obj.StrainList(end+1) = newStrain;
            end
        end
        function speciesList = getSpeciesList(obj)
            speciesList = obj.SpeciesList;
        end
        function deleteItem(obj, name)
             if isprop(obj, name)
                if isa(obj.(name), 'ndi.database.metadata_app.class.Species')
                    obj.(name) = ndi.database.metadata_app.class.Species.empty(0,1);
                elseif isa(obj.(name), 'ndi.database.metadata_app.class.Strain')
                     obj.(name) = ndi.database.metadata_app.class.Strain.empty(0,1);
                elseif iscell(obj.(name))
                    obj.(name) = {};
                else
                    obj.(name) = []; % General fallback
                end
            end
        end
        function deleteSpeciesList(obj)
            obj.SpeciesList = ndi.database.metadata_app.class.Species.empty(0,1);
        end
        function deleteStrainList(obj)
            obj.StrainList = ndi.database.metadata_app.class.Strain.empty(0,1);
            obj.StrainMap = containers.Map; % Reset map as well
        end
        function deleteBiologicalSex(obj)
            obj.BiologicalSexList = {};
        end
        function sortedSpeciesList = sortSpeciesList(obj)
            % This method assumes SpeciesList elements have a getUuid method returning numeric/convertible string
            speciesList = obj.SpeciesList;
            if isempty(speciesList)
                sortedSpeciesList = ndi.database.metadata_app.class.Species.empty(0,1);
                return;
            end
            
            uuids_str = cell(1, numel(speciesList));
            valid_obj_idx = false(1, numel(speciesList));
            for i = 1:numel(speciesList)
                if isobject(speciesList(i)) && ismethod(speciesList(i), 'getUuid')
                    uuids_str{i} = speciesList(i).getUuid();
                    valid_obj_idx(i) = true;
                else
                    uuids_str{i} = '0'; % Default for non-objects or missing method
                end
            end
            
            % Convert to numeric for sorting, handle potential errors
            uuids_num = zeros(1, numel(speciesList));
            for i = 1:numel(uuids_str)
                val = str2double(uuids_str{i});
                if isnan(val)
                    uuids_num(i) = 0; % Or some other default for non-numeric UUIDs
                else
                    uuids_num(i) = val;
                end
            end

            [~, sortedIndices] = sort(uuids_num(valid_obj_idx));
            sortedSpeciesList = speciesList(valid_obj_idx(sortedIndices));
        end

        function str = toStringArr(obj, name)
            % Converts a list of objects (SpeciesList or StrainList) to a comma-separated string of their names.
            str = ""; % Default to empty string
            if isprop(obj, name) && ~isempty(obj.(name))
                itemList = obj.(name);
                itemNames = cell(1, numel(itemList));
                validCount = 0;
                for i = 1:numel(itemList)
                    if isobject(itemList(i)) && (isprop(itemList(i), 'Name') || isprop(itemList(i),'name'))
                        validCount = validCount + 1;
                        if isprop(itemList(i), 'Name')
                            itemNames{validCount} = char(itemList(i).Name);
                        else
                            itemNames{validCount} = char(itemList(i).name);
                        end
                    elseif ischar(itemList(i)) || isstring(itemList(i)) % Handle if it's already a name
                        validCount = validCount +1;
                        itemNames{validCount} = char(itemList(i));
                    end
                end
                if validCount > 0
                    str = strjoin(itemNames(1:validCount), ', ');
                end
            end
        end

        function str = biologicalSexToString(obj)
            if isempty(obj.BiologicalSexList)
                str = "";
            elseif ischar(obj.BiologicalSexList) || isstring(obj.BiologicalSexList)
                str = char(obj.BiologicalSexList); % Already a string or char
            elseif iscell(obj.BiologicalSexList)
                str = strjoin(cellstr(obj.BiologicalSexList), ', '); % Join if cell array
            else
                str = ""; % Fallback
            end
        end

        function formattedStruct = formatTable(obj)
            % This method should ideally return an array of structs if there are multiple subjects,
            % or a single struct if SubjectData holds one subject.
            % Assuming 'obj' is a single Subject instance here.
            
            % Get species name(s)
            speciesStr = "";
            if ~isempty(obj.SpeciesList)
                speciesNames = cell(1, numel(obj.SpeciesList));
                for i = 1:numel(obj.SpeciesList)
                    if isprop(obj.SpeciesList(i), 'Name')
                        speciesNames{i} = char(obj.SpeciesList(i).Name);
                    elseif isprop(obj.SpeciesList(i), 'name')
                         speciesNames{i} = char(obj.SpeciesList(i).name);
                    else
                        speciesNames{i} = '';
                    end
                end
                speciesStr = strjoin(speciesNames,'; ');
            end

            % Get strain name(s)
            strainStr = "";
            if ~isempty(obj.StrainList)
                strainNames = cell(1, numel(obj.StrainList));
                for i = 1:numel(obj.StrainList)
                     if isprop(obj.StrainList(i), 'Name')
                        strainNames{i} = char(obj.StrainList(i).Name);
                    elseif isprop(obj.StrainList(i), 'name')
                         strainNames{i} = char(obj.StrainList(i).name);
                    else
                        strainNames{i} = '';
                    end
                end
                strainStr = strjoin(strainNames,'; ');
            end

            formattedStruct = struct(...
                'SubjectName', char(obj.SubjectName), ... % Changed from 'Subject'
                'BiologicalSexList', obj.biologicalSexToString(), ... % Changed from 'BiologicalSex'
                'SpeciesList', speciesStr, ... % Changed from 'Species'
                'StrainList', strainStr ... % Changed from 'Strain'
                );
        end

        function equal = isEqual(obj, subject)
            % Basic equality check, can be expanded
            equal = false;
            if ~isa(subject, 'ndi.database.metadata_app.class.Subject'), return; end
            if obj.SubjectName ~= subject.SubjectName, return; end
            % Add more checks for other properties if needed
            equal = true; 
        end
        
        function s = toStruct(obj)
            %TOSTRUCT Converts the Subject object to a plain struct.
            %   Handles nested objects if they also have a toStruct method.
            props = properties(obj); 
            s = struct();
            for j = 1:length(props)
                propName = props{j};
                propValue = obj.(propName);
                
                if strcmp(propName, 'StrainMap'), continue; end % Skip StrainMap

                if isa(propValue, 'ndi.database.metadata_app.class.Species') || ...
                   isa(propValue, 'ndi.database.metadata_app.class.Strain')
                    if ~isempty(propValue)
                        s.(propName) = arrayfun(@(x) x.toStruct(), propValue); % Convert array of objects
                    else
                        s.(propName) = struct([]); % Empty struct for empty object arrays
                    end
                elseif isobject(propValue) && ismethod(propValue, 'toStruct') % General case for other objects
                    if ~isempty(propValue) 
                        s.(propName) = propValue.toStruct(); 
                    else
                        s.(propName) = struct([]);
                    end
                elseif iscell(propValue) && all(cellfun(@(c) ischar(c) || isstring(c), propValue))
                    s.(propName) = propValue; % Keep cell array of strings as is for now
                else
                    s.(propName) = propValue;
                end
            end
        end
    end

    methods (Static)
        function b = loadobj(a) % For loading from .mat files
            fprintf('DEBUG (Subject.loadobj): Attempting to load Subject object.\n');
            if isa(a, 'struct')
                fprintf('DEBUG (Subject.loadobj): Input is a struct. Reconstructing object.\n');
                b = ndi.database.metadata_app.class.Subject(); % Create new instance
                
                % Iterate through fields of struct 'a' and assign to 'b'
                fields_a = fieldnames(a);
                for k_field = 1:numel(fields_a)
                    fieldName = fields_a{k_field};
                    if isprop(b, fieldName)
                        % Special handling for object arrays if they were saved as struct arrays
                        if strcmp(fieldName, 'SpeciesList') && isstruct(a.(fieldName))
                            b.(fieldName) = ndi.database.metadata_app.class.Species.empty(0,numel(a.(fieldName)));
                            for idx_s = 1:numel(a.(fieldName))
                                b.(fieldName)(idx_s) = ndi.database.metadata_app.class.Species.fromStruct(a.(fieldName)(idx_s));
                            end
                        elseif strcmp(fieldName, 'StrainList') && isstruct(a.(fieldName))
                             b.(fieldName) = ndi.database.metadata_app.class.Strain.empty(0,numel(a.(fieldName)));
                            for idx_s = 1:numel(a.(fieldName))
                                b.(fieldName)(idx_s) = ndi.database.metadata_app.class.Strain.fromStruct(a.(fieldName)(idx_s));
                            end
                        elseif ~strcmp(fieldName, 'StrainMap') % Don't try to load StrainMap directly if it's complex
                            b.(fieldName) = a.(fieldName);
                        end
                    end
                end
                % Re-initialize StrainMap if it was not loaded or if it's empty
                if ~isprop(b,'StrainMap') || isempty(b.StrainMap) || ~isa(b.StrainMap, 'containers.Map')
                    b.StrainMap = containers.Map;
                end

            else
                fprintf('DEBUG (Subject.loadobj): Input is not a struct. Returning as is.\n');
                b=a; % Assume it's already an object
            end
        end

        function obj = fromStruct(s_array)
            %FROMSTRUCT Creates an array of Subject objects from an array of plain structs.
            %   s_array: An array of structs, where each struct contains subject data.
            
            fprintf('DEBUG (Subject.fromStruct): Received input of type: %s\n', class(s_array));
            if isstruct(s_array) && isscalar(s_array) && isempty(fieldnames(s_array))
                 fprintf('DEBUG (Subject.fromStruct): Input is an empty scalar struct. Returning empty Subject array.\n');
                 obj = ndi.database.metadata_app.class.Subject.empty(0,1);
                 return;
            end
            if ~isstruct(s_array) || isempty(s_array)
                if ~isstruct(s_array)
                    fprintf(2, 'ERROR (Subject.fromStruct): Input `s_array` is not a struct. Type: %s. Value: %s\n', class(s_array), dispstr(s_array));
                else
                    fprintf('DEBUG (Subject.fromStruct): Input `s_array` is empty. Returning empty Subject array.\n');
                end
                obj = ndi.database.metadata_app.class.Subject.empty(0,1);
                return;
            end

            numSubjects = numel(s_array);
            obj = repmat(ndi.database.metadata_app.class.Subject(), numSubjects, 1); % Preallocate object array

            for k = 1:numSubjects
                s = s_array(k);
                fprintf('DEBUG (Subject.fromStruct): Processing subject struct #%d\n', k);
                % disp(s); % Display the struct being processed

                props = fieldnames(s);
                for i = 1:length(props)
                    propName = props{i};
                    propValue = s.(propName);
                    
                    fprintf('DEBUG (Subject.fromStruct):  Field: %s, Type: %s\n', propName, class(propValue));

                    if isprop(obj(k), propName)
                        if strcmp(propName, 'SpeciesList')
                            if isstruct(propValue) && ~isempty(propValue)
                                % Assuming propValue is an array of structs for Species
                                tempSpeciesList = ndi.database.metadata_app.class.Species.empty(0,numel(propValue));
                                for sp_idx = 1:numel(propValue)
                                     if ismethod('ndi.database.metadata_app.class.Species', 'fromStruct')
                                        tempSpeciesList(sp_idx) = ndi.database.metadata_app.class.Species.fromStruct(propValue(sp_idx));
                                     else % Fallback if fromStruct is missing in Species
                                        tempSpeciesList(sp_idx).Name = propValue(sp_idx).name;
                                        if isfield(propValue(sp_idx),'preferredOntologyIdentifier')
                                            tempSpeciesList(sp_idx).PreferredOntologyIdentifier = propValue(sp_idx).preferredOntologyIdentifier;
                                        end
                                     end
                                end
                                obj(k).(propName) = tempSpeciesList;
                            elseif isempty(propValue)
                                obj(k).(propName) = ndi.database.metadata_app.class.Species.empty(0,1);
                            else
                                fprintf(2, 'Warning (Subject.fromStruct): SpeciesList is not a struct or is empty. Skipping for subject %d.\n',k);
                            end
                        elseif strcmp(propName, 'StrainList')
                            if isstruct(propValue) && ~isempty(propValue)
                                % Assuming propValue is an array of structs for Strain
                                tempStrainList = ndi.database.metadata_app.class.Strain.empty(0,numel(propValue));
                                for st_idx = 1:numel(propValue)
                                    if ismethod('ndi.database.metadata_app.class.Strain', 'fromStruct')
                                        tempStrainList(st_idx) = ndi.database.metadata_app.class.Strain.fromStruct(propValue(st_idx));
                                    else % Fallback
                                        tempStrainList(st_idx).Name = propValue(st_idx).name; 
                                    end
                                end
                                obj(k).(propName) = tempStrainList;
                            elseif isempty(propValue)
                                obj(k).(propName) = ndi.database.metadata_app.class.Strain.empty(0,1);
                            else
                                 fprintf(2, 'Warning (Subject.fromStruct): StrainList is not a struct or is empty. Skipping for subject %d.\n',k);
                            end
                        elseif strcmp(propName, 'StrainMap')
                            % StrainMap is initialized in constructor, typically not set from struct
                            continue; 
                        else
                            try
                                obj(k).(propName) = propValue;
                            catch ME_propSet
                                fprintf(2, 'Error (Subject.fromStruct) setting property %s: %s\n', propName, ME_propSet.message);
                            end
                        end
                    else
                        fprintf(2, 'Warning (Subject.fromStruct): Property "%s" not found in Subject class.\n', propName);
                    end
                end
            end
            fprintf('DEBUG (Subject.fromStruct): Finished processing all subject structs.\n');
        end
    end
end

% Helper for dispstr in debug messages
function out = dispstr(in)
    if ischar(in) || isstring(in)
        out = ['"' char(in) '"'];
    elseif isnumeric(in) || islogical(in)
        out = mat2str(in);
    elseif iscell(in)
        out = '{';
        for k_cell=1:numel(in)
            out = [out dispstr(in{k_cell})]; %#ok<AGROW>
            if k_cell < numel(in), out = [out ', ']; end %#ok<AGROW>
        end
        out = [out '}'];
    else
        out = ['<' class(in) ' object>'];
    end
end
