classdef DatasetInfo < handle

    properties
        DatasetTitle (1,1) string
        DatasetRootPathLog (1,:) string
    end

    properties (SetObservable)
        DatasetRootPath (1,1) string
    end

    methods
        function tf = isClean(obj, filePath)
            if isfile(filePath)
                S = load(filePath);
                tf = strcmp(S.DatasetInformation.DatasetTitle, obj.DatasetTitle);
            else
                tf = false;
            end
        end
    end

end