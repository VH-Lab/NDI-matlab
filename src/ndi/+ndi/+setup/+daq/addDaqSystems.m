function S = addDaqSystems(S, labName, force)
    % addDaqSystems - Add DAQ systems for a specified lab to an ndi session.
    %
    %   S = ndi.setup.daq.addDaqSystems(S, LABNAME)
    %
    %   Inputs:
    %       S - An NDI session object
    %       labName - The name of a lab with preconfigured DAQ systems (char)
    %       force - A boolean flag indicating if DAQ systems should be
    %               re-created if they already exists. When true, if a DAQ
    %               system with a given name already exists, it is removed from
    %               the session before it is re-created and added again.
    %
    %   Outputs:
    %       S - An NDI session object
    %
    %   Note: Assumes the lab is present in the ndi_common/daq_systems folder.

    if nargin < 3; force = false; end

    deviceNames = ndi.setup.daq.system.listDaqSystemNames(labName);

    for i = 1:numel(deviceNames)
        device = S.daqsystem_load('name', deviceNames{i});

        % Remove an existing DAQ system if "force" is true
        if force && ~isempty(device)
            S.daqsystem_rm(device);
            device = [];
        end

        % Add DAQ system / device to session if it does not already exist.
        if isempty(device)
            daqSystemConfig = ndi.setup.DaqSystemConfiguration.fromLabDevice(labName, deviceNames{i});
            S = daqSystemConfig.addToSession(S);
        end
    end
end
