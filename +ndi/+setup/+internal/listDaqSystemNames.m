function daqSystemNames = listDaqSystemNames(labName)

    ndi.globals; 
    importDir = fullfile(ndi_globals.path.commonpath, 'daq_systems', labName);
    
    if ~isfolder(importDir)
        error('No daq systems were found for "%s"', labName)
    end

    L = dir(fullfile(importDir, '*.json'));

    [~, daqSystemNames] = fileparts({L.name});
end
