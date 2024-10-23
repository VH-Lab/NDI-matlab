function probeData = loadProbes(S)
    % LOADPROBES loads the probe data from ndi session
    %
    %  ndi.database.metadat_app.fun.loadProbes(S)
    % Inputs:
    %  S - ndi.session.dir object
    % Output:
    %  PROBEDATA - a ndi.database.metadat_app.class.ProbeData object that contains all the probe data in session S

    if (~(isa(S,'ndi.dataset.dir') || isa(S,'ndi.session.dir')))
        error('METADATA_APP:loadProbes:InvalidSession, InvalidDataset',...
            'Input must be an ndi.session object or ndi.dataset object.');
    end
    probes = {};
    if isa(S,'ndi.session.dir')
        probes = S.getprobes();
    else
        d = S.session.database_search(ndi.query('','isa','dataset_session_info'));
        session_info = d{1, 1}.document_properties.dataset_session_info.dataset_session_info;
        for i = 1:numel(session_info)
            session_id = session_info(1).session_id;
            ndi_session_obj = D3.open_session(session_id);
            probes = [probes, ndi_session_obj.getprobes()];
        end
    end
    probeData = ndi.database.metadata_app.class.ProbeData();
    probeTypeMap = containers.Map();
    % Patch, patch-VM, patch-I, patch-attached, sharp, sharp-Vm, sharp-I, are pipettes
    probeTypeMap('patch') = 'Pipette';
    probeTypeMap('patch-Vm') = 'Pipette';
    probeTypeMap('patch-I') = 'Pipette';
    probeTypeMap('patch-attached') = 'Pipette';
    probeTypeMap('sharp') = 'Pipette';
    probeTypeMap('sharp-Vm') = 'Pipette';
    probeTypeMap('sharp-I') = 'Pipette';

    % N-trodes, electrode-$, are electrodes
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
                continue;
        end
        probe_obj.Name = probes{i}.elementstring();
        probe_obj.DeviceType = probes{i}.type;
        probe_obj.ProbeType = probes{i}.type;
        probe_obj.Complete = 0;
        probe_obj.sessionIdentifier = probes{i}.session.identifier;
        probeData.addNewProbe(probe_obj);
    end
end