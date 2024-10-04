function ndi_probe_obj = probestruct2probe(probestruct, exp)
% NDI.PROBE.FUN.PROBESTRUCT2PROBE - Convert probe structures to NDI_PROBE objects
%
% NDI_PROBE_OBJ = ndi.probe.fun.probestruct2probe(PROBESTRUCT, EXP)
%
% Given an array of structures PROBESTRUCT with field 
% 'name', 'reference', and 'type', and an ndi.session EXP,
% this function generates the appropriate subclass of ndi.probe for
% dealing with the PROBE and returns the objects in a cell array NDI_PROBE_OBJ.
%

    arguments
        probestruct (1,:) struct
        exp % (1,1) ndi.session ?
    end

    persistent probeTypeMap
    if isempty(probeTypeMap)
        probeTypeMap = ndi.probe.fun.initProbeTypeMap; 
    end
    
    ndi_probe_obj = cell(1, numel(probestruct));
    
    for i = 1:numel(probestruct)
        if ~isKey(probeTypeMap, probestruct(i).type)
            throwProbeTypeNotFoundError(probestruct(i).type)
        end
        probeClass = probeTypeMap(probestruct(i).type);
        probeArgs = struct2cell(probestruct(i));
        ndi_probe_obj{i} = feval(probeClass, exp, probeArgs{:});
    end
end

function throwProbeTypeNotFoundError(probeType)
    arguments
        probeType (1,1) string % Name/type of probe
    end

    error('NDI:Probe:ProbeTypeNotFound', ...
          'Could not find exact match for "%s" in probe type map.', ...
          probeType);
end
