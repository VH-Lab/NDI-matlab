classdef Subject < handle
    %SUBJECT Summary of this class goes here
    %   Detailed explanation goes here

    properties
        SubjectName (1,1) string = missing
        BiologicalSexList (1,:)
        SpeciesList (1,:) ndi.database.metadata_app.class.Species
        StrainList (1,:) ndi.database.metadata_app.class.Strain
        StrainMap
        sessionIdentifier (1,1) string
    end

    methods
        function obj = Subject()
            obj.StrainMap = containers.Map;
        end

        function updateProperty(obj, name, idx, value)
            obj.(name)(idx)=value;
        end

        function addItem(obj, name, value)
            obj.(name)(end+1) = value;
        end

        function addStrain(obj, strainName)
            strain = ndi.database.metadata_app.class.Strain(strainName);
            obj.StrainList = strain;

            % % if ~isKey(obj.StrainMap, strainName)
            % %     obj.StrainMap(strainName) = true;
            % %     strain = ndi.database.metadata_app.class.Strain(strainName);
            % %     obj.addItem("StrainList",strain);
            % % end
        end

        function speciesList = getSpeciesList(obj)
            speciesList = obj.SpeciesList;
        end

        function deleteItem(obj, name)
            obj.(name)=[];
        end

        function deleteSpeciesList(obj)
            obj.SpeciesList = ndi.database.metadata_app.class.Species.empty();
        end

        function deleteStrainList(obj)
            obj.StrainList = ndi.database.metadata_app.class.Strain.empty();
            obj.StrainMap = containers.Map;
        end

        function deleteBiologicalSex(obj)
            obj.BiologicalSexList = [];
        end

        function sortedSpeciesList = sortSpeciesList(obj)
            speciesList = obj.SpeciesList;
            uuids = zeros(1, numel(speciesList));
            for i = 1:numel(speciesList)
                uuids(i) = speciesList(i).getUuid();
            end
            [~, sortedIndices] = sort(uuids);
            sortedSpeciesList = speciesList(sortedIndices);
        end

        function str = toStringArr(obj, name)
            if numel(obj.(name)) == 0
                str = "";
            else
                str1 = obj.(name)(1).toString();
                str = str1;
                for i = 2:numel(obj.(name))
                    str1 = obj.(name)(i).toString();
                    str = str + ", ";
                    str = str + str1;
                end
            end
        end

        function str = biologicalSexToString(obj)
            if numel(obj.BiologicalSexList) == 0
                str = "";
            else
                str = obj.BiologicalSexList;
            end
        end

        function formattedStruct = formatTable(obj)
            paddedLists{1} = obj.SubjectName;
            paddedLists{2} = obj.biologicalSexToString();
            speciesList = obj.toStringArr("SpeciesList");
            % speciesList = speciesList{1};
            paddedLists{3} = speciesList;
            strainList = obj.toStringArr("StrainList");
            paddedLists{4} = strainList;
            %
            % paddedLists{1} = paddedLists{1}';
            % paddedLists{2} = paddedLists{2}';
            % paddedLists{3} = paddedLists{3}';
            % paddedLists{4} = paddedLists{4}';

            % placeholder = '';
            % paddedLists(cellfun('isempty', paddedLists)) = {placeholder};
            formattedStruct = struct(...
                'Subject', paddedLists{1}, ...
                'BiologicalSex', paddedLists{2}, ...
                'Species', paddedLists{3}, ...
                'Strain', paddedLists{4} ...
                );
        end

        function equal = isEqual(obj, subject)
            speciesList1 = obj.sortSpeciesList();
            speciesList2 = subject.sortSpeciesList();
            equal = 1;
            if numel(speciesList1) == numel(speciesList2)
                for i = 1:numel(speciesList1)
                    if (~(str2double(speciesList1(i).getUuid) == str2double(speciesList2(i).getUuid)))
                        equal = 0;
                        break;
                    end
                end
            else
                equal = 0;
            end
        end

        function s = toStruct(obj)
            props = properties(obj); % Get all properties of the class
            s = struct();
            for j = 1:length(props)
                propName = props{j};
                propValue = obj.(propName);
                if isobject(propValue) && ismethod(propValue, 'toStruct')
                    if ~isempty(propValue) % Check if the object is not empty
                        s.(propName) = propValue.toStruct(); % Recursively convert to struct
                    end
                elseif isa(propValue, 'containers.Map')
                    continue;
                else
                    if ~isempty(propValue)
                        s.(propName) = propValue;
                    end
                end
            end
        end
    end

    methods (Static)
        function paddedList = padList(list, targetLength, placeholder)
            % Helper function to pad a list with a placeholder to match the target length
            paddedList = list;
            if length(list) < targetLength
                padding = cell(1, targetLength - length(list));
                padding(:) = {placeholder};
                paddedList = [list, padding];
            end
        end
    end

    methods (Static)
        function b = loadobj(a)
            if isa(a, 'struct')
                b = ndi.database.metadata_app.class.Subject();
                b.SubjectName = a.SubjectNameList{1};
                b.BiologicalSexList = a.BiologicalSexList;
                b.SpeciesList = a.SpeciesList;
                b.StrainList = a.StrainList;
                b.StrainMap = a.StrainMap;
            else
                b=a;
            end
        end
        function obj = fromStruct(s)
            obj = ndi.database.metadata_app.class.Subject();
            props = fieldnames(s); 
            for i = 1:length(props)
                propName = props{i};
                propValue = s.(propName);
                if isempty(propValue)
                    obj.(propName) = '';
                elseif numel(propValue) == 0
                    obj.(propName) = '';
                elseif propName == "SpeciesList"
                    obj.(propName) = ndi.database.metadata_app.class.Species.fromStruct(propValue);
                elseif propName == "StrainList"
                    obj.(propName) = ndi.database.metadata_app.class.Strain.fromStruct(propValue);
                elseif propName == "StrainMap"
                    obj.(propName) = propValue;
                else
                    obj.(propName) = propValue;
                end
            end
        end
    end    
end

