classdef FolderLevel < matlab.mixin.SetGet

    properties
        Name (1,1) string = ""
        Type (1,1) ndi.dataset.gui.enum.FolderLevelType
        IgnoreList (1,:) string
        Expression (1,1) string
        FolderNamePrefix (1,1) string = ""
    end

    methods % Constructor
        function obj = FolderLevel(propertyValues)
            arguments
                propertyValues.?ndi.dataset.gui.models.FolderLevel
            end
            obj.set(propertyValues)
        end
    end

    methods
        function getFolderPath(obj, rootPathName, id)
            % Get path of subfolder given a root directory path and a folder id
        end

        function createFolder(obj, rootPathName, id)
            % Create a subfolder in a root directory with a given id
        end

        function listFolders(obj, rootPathName)
            % List all folders in the rootDirectory 
        end
    end

end