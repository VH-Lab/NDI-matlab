classdef SubjectData < handle
    %SubjectData A utility class for storing and retrieving information about subjecs.

    properties
        % A struct array holding information for each subject. See
        SubjectList (1,:) ndi.database.metadata_app.class.Subject
    end

    methods

        function removeItem(obj, subjectIndex)
            %removeItem Remove the specified subject form the list.
            %
            %   Usage:
            %   subjectData.removeItem(subjectIndex) removes the author from the
            %   list where subjectIndex is the index in the struct.

            obj.SubjectList(subjectIndex) = [];
        end

        function newSubject = addItem(obj)
            %addItem Add a subject to the list.
            %
            %   Usage:
            %   newSubject = subjectData.addItem(subjectIndex) adds a subject 
            %   to the end of the list.

            newSubject = ndi.database.metadata_app.class.Subject;
            obj.SubjectList(end+1) = newSubject;
        end

        function assignName(obj)
            for i = 1:numel(obj.SubjectList)
                name = sprintf("subject%d", i);
                obj.SubjectList(i).SubjectName = name;
            end
        end

        function idx = getIndex(obj, subjectName)
            idx = -1;
            for i = 1:numel(obj.SubjectList)
                name = obj.SubjectList(i).SubjectName;
                if strcmp(name,subjectName)
                    idx = i;
                    break;
                end
            end
        end

        function S = getItem(obj, subjectIndex)
            %getItem Get a struct with subject details for the given index
            S = obj.SubjectList(subjectIndex);
        end

        function S = getSubjectList(obj)
            S = obj.SubjectList;
        end

        function setSubjectList(obj, S)
            obj.SubjectList = S;
        end

        function selected = biologicalSexSelected(obj, subjectName)
            idx = obj.getIndex(subjectName);
            selected = 1;
            sex = obj.SubjectList(idx).BiologicalSexList;
            if isempty(sex)
                selected = 0;
            end
        end

        function selected = SpeciesSelected(obj, subjectName)
            idx = obj.getIndex(subjectName);
            selected = 1;
            species = obj.SubjectList(idx).SpeciesList;
            if isempty(species)
                selected = 0;
            end
        end

        function data = formatTable(obj)
            data = [];
            subjectList = obj.getSubjectList();
            for i = 1:numel(subjectList)
                data = vertcat(data, subjectList(i).formatTable);
            end
        end
    end
end
