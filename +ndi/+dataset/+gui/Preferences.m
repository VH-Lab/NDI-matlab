classdef Preferences < handle

    properties
        % Starting window position
        Position (1,4) double = [100 100 1000 700]

        DatasetFolderHistory (1,:) string

        FolderOrganizationTemplates (1,1) dictionary
    end

    methods
        function save(obj, className, subFolder)
            folderPath = fullfile(prefdir, subFolder);
            if ~isfolder(folderPath); mkdir(folderPath); end
            filename = fullfile(folderPath, strrep(className, '.', '_'));
            filename = [filename, '.mat'];
            save(filename, "obj")
        end
    end

    methods (Static)
        function obj = load(className, subFolder)
            folderPath = fullfile(prefdir, subFolder);
            filename = fullfile(folderPath, strrep(className, '.', '_'));
            filename = [filename, '.mat'];
            if isfile(filename)
                S = load(filename, "obj");
                obj = S.obj;
            else
                obj = ndi.dataset.gui.Preferences();
            end
        end
    end
end