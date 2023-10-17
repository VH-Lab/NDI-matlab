classdef Subject < handle
    %SUBJECT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        SubjectNameList (1,:)
        BiologicalSexList (1,:)
        SpeciesList (1,:) ndi.database.metadata_app.class.Species
        StrainList (1,:) ndi.database.metadata_app.class.Strain
    end
    
    methods
        
        function updateProperty(obj, name, idx, value)
            obj.(name)(idx)=value;
        end

        function addItem(obj, name, value)
            obj.(name)(end+1) = value;
        end

        function speciesList = getSpeciesList(obj)
            speciesList = obj.SpeciesList;
        end

        function deleteItem(obj, name, idx)
            obj.(name)(idx)=[];
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

        function strArr = toStringArr(obj, name)
            strArr = {};
            for i = 1:numel(obj.(name))
                strArr{end + 1} = obj.(name)(i).toString();
            end
        end

        function formattedStruct = formatTable(obj)
            maxLen = max([numel(obj.BiologicalSexList) numel(obj.SpeciesList) numel(obj.StrainList) numel(obj.SubjectNameList)]);
            paddedLists = cell(1, 4);
            paddedLists{1} = obj.padList(obj.SubjectNameList, maxLen, '');
            paddedLists{2} = obj.padList(obj.BiologicalSexList, maxLen, '');
            speciesList = obj.toStringArr("SpeciesList");
            paddedLists{3} = obj.padList(speciesList, maxLen, '');
            strainList = obj.toStringArr("StrainList");
            paddedLists{4} = obj.padList(strainList, maxLen, '');
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
end

