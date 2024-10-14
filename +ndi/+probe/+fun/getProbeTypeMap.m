function probeTypeMap = getProbeTypeMap()
    persistent cahcedProbeTypeMap
    if isempty(cahcedProbeTypeMap)
        cahcedProbeTypeMap = ndi.probe.fun.initProbeTypeMap();
    end
    probeTypeMap = cahcedProbeTypeMap;
end