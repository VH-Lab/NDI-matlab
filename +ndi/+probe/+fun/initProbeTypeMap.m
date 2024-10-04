function probeTypeMap = initProbeTypeMap(legacy)
    arguments
        legacy (1,1) logical = false
    end
    
    jsonFilePath = fullfile(ndi.toolboxdir, 'ndi_common', 'probe', 'probetype2object.json');
    probeTypeMap = jsondecode( fileread(jsonFilePath) );

    keys = string( {probeTypeMap.type} );
    values = string( {probeTypeMap.classname} );

    if isMATLABReleaseOlderThan('R2022b') || legacy
        probeTypeMap = containers.Map(keys, values);
    else
        probeTypeMap = dictionary(keys, values);
    end
end
