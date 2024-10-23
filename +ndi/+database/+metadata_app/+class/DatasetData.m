classdef DatasetData < handle
    %AuthorData A utility class for storing and retrieving information about Dataset.

    properties
        % A struct array holding information for dataset. See
        % DatasetData.getDefaultDatasetItem for the fields contained in the
        % struct
        DatasetInfo (:,1) struct
    end

    methods
        function updateProperty(obj, name, value)
            %updateProperty Update the value in a field

            if numel( obj.DatasetInfo ) == 0
                obj.DatasetInfo = obj.getDefaultDatasetItem();
            end
            obj.DatasetInfo.(name)=value;
        end

        function S = getItem(obj)
            %getItem Get a struct with dataset details for the given index
            if numel( obj.DatasetInfo ) == 0
                S = obj.getDefaultDatasetItem();
            else
                S = obj.DatasetInfo;
            end
        end

        function S = getDataset(obj)
            %getDataset - Same as S = datasetData.DatasetInfo
            S = obj.DatasetInfo;
        end

        function setDataset(obj, S)
            %setDataset - Same as datasetData.DatasetInfo = S
            obj.DatasetInfo = S;
        end
    end

    methods (Static)

        function S = getDefaultDatasetItem()
            S = struct;
            S.author = '';
            S.description = ''; %Abstract
            S.fullName = ''; %Dataset Branch Title
            S.hasVersion = '';
            S.shortName = '';
        end
    end
end
