function [daqSystemNames, daqSystemConfigFiles] = listDaqSystemNames(labName)
% listDaqSystemNames - List names of pre-configured DAQ systems for a lab
    
    arguments
        labName (1,1) string = missing
    end

    rootPath = fullfile(ndi.common.PathConstants.CommonFolder, 'daq_systems');

    if ~ismissing(labName)
        importDir = fullfile(rootPath, labName);
    
        if ~isfolder(importDir)
            error('No DAQ systems were found for "%s"', labName)
        end
        L = dir(fullfile(importDir, '*.json'));
    else
        L = recursiveDir(rootPath, 'FileType', 'json');
    end


    [~, daqSystemNames] = fileparts({L.name});

    if nargout == 2
        daqSystemConfigFiles = arrayfun(@(s) fullfile(s.folder, s.name), L, 'uni', 0);
    end
end
