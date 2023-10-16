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

        function speciesList = sortSpeciesList(obj)
            speciesList = obj.SpeciesList;
        end

        function strArr = toStringArr(obj, name)
            strArr = [];
            for i = 1:numel(obj.(name))
                strArr(end + 1) = obj.(name)(i).toString();
            end
        end

        function S = formatTable(obj)
            arr = [numel(obj.BiologicalSexList) numel(obj.SpeciesList) numel(obj.StrainList) numel(obj.SubjectNameList)];
            len = max(arr);
            S = struct;
            subjectNameList = obj.SubjectNameList;
            subjectNameList(max(1,end), len) = "";
            S.Subject = subjectNameList;
            biologicalSexList = obj.BiologicalSexList;
            biologicalSexList(max(1,end), len) = "";
            S.Subject = biologicalSexList;

            speciesList = obj.toStringArr("SpeciesList");
            speciesList(max(1,end), len) = "";
            S.speciesList = speciesList;

            strainList = obj.toStringArr("StrainList");
            strainList(max(1,end), len) = "";
            S.Subject = strainList;
        end

        function equal = isEqual(obj, subject)
            speciesList1 = obj.sortSpeciesList();
            speciesList2 = subject.sortSpeciesList();
            equal = 1;
            if numel(speciesList1) == numel(speciesList2)
                for i = 1:numel(speciesList1)
                    if (~speciesList1(i).getUuid == speciesList2(i).getUuid)
                        equal = 0;
                        break;
                    end
                end
            else
                equal = 0;
            end
        end
    end
end

