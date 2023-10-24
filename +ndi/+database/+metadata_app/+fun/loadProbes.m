function probeData = loadProbes(S)
% LOADPROBES loads the probe data from ndi session
%
%  ndi.database.metadat_app.fun.loadProbes(S)
% Inputs:
%  S - ndi.session.dir object
% Output:
%  PROBEDATA - a ndi.database.metadat_app.class.ProbeData object that contains all the probe data in session S
    
    if ~isa(S,'ndi.session.dir')
       error('METADATA_APP:loadProbes:InvalidSession',...
          'Input must be an ndi.session object.'); 
    end
    probes = S.getprobes();
    probeData = ndi.database.metadata_app.class.ProbeData();
    probeTypeMap = containers.Map();
    %Patch, patch-VM, patch-I, patch-attached, sharp, sharp-Vm, sharp-I, are pipettes
    probeTypeMap('patch') = 'Pipette';
    probeTypeMap('patch-Vm') = 'Pipette';
    probeTypeMap('patch-I') = 'Pipette';
    probeTypeMap('patch-attached') = 'Pipette';
    probeTypeMap('sharp') = 'Pipette';
    probeTypeMap('sharp-Vm') = 'Pipette';
    probeTypeMap('sharp-I') = 'Pipette';
    
    %N-trodes, electrode-$, are electrodes
    probeTypeMap('n-trode') = 'Electrode';

    for i = 1:numel(probes)
        type = '';
        if isKey(probeTypeMap, lower(probes{i}.type))
            type = probeTypeMap(probes{i}.type);
        end
        % if probe{i}.type is electrode followed by any number then set probe{i}.type to electrode
        if regexp(probes{i}.type, 'electrode-\d')
            type = 'Electrode';
        end
    
        switch type
            case 'Pipette'
                probe_obj = ndi.database.metadata_app.class.Pipette();
                probe_obj.ClassType = 'Pipette';
            case 'Electrode'
                probe_obj = ndi.database.metadata_app.class.Electrode();
                probe_obj.ClassType = 'Electrode';
            otherwise
        end
        probe_obj.Name = probes{i}.elementstring();
        probe_obj.ProbeType = probes{i}.type;
        probe_obj.Complete = 0;
        probeData.addNewProbe(probe_obj);
    end
end