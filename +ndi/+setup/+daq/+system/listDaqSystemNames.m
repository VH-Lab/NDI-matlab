function daqSystemNames = listDaqSystemNames(labName)
% listDaqSystemNames - List names of pre-configured DAQ systems for a lab
    
    ndi.globals; 
    importDir = fullfile(ndi_globals.path.commonpath, 'daq_systems', labName);
    
    if ~isfolder(importDir)
        error('No DAQ systems were found for "%s"', labName)
    end

    L = dir(fullfile(importDir, '*.json'));

    [~, daqSystemNames] = fileparts({L.name});
end
