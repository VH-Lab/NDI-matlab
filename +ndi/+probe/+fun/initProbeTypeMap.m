function probeTypeMap = initProbeTypeMap()
    jsonFilePath = fullfile(ndi.toolboxdir, 'ndi_common', 'probe', 'probetype2object.json');
    probeTypeMap = jsondecode( fileread(jsonFilePath) );

    keys = string( {probeTypeMap.type} );
    values = string( {probeTypeMap.classname} );

    if isMATLABReleaseOlderThan('R2022b')
        probeTypeMap = containers.Map(keys, values);
    else
        probeTypeMap = dictionary(keys, values);
    end
end
