function daqSystemNames = listDaqSystemNames(labName)
% listDaqSystemNames - List names of pre-configured DAQ systems for a lab
    
    importDir = fullfile(ndi.common.PathConstants.CommonFolder, 'daq_systems', labName);
    
    if ~isfolder(importDir)
        error('No DAQ systems were found for "%s"', labName);
    end

    L = dir(fullfile(importDir, '*.json'));

    [~, daqSystemNames] = fileparts({L.name});

    if ~isa(daqSystemNames,'cell'),
        daqSystemNames = {daqSystemNames};
    end;
end
