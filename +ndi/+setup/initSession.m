function S = initSession(dirname, ref, labName)

    S = ndi.session.dir(ref, dirname);
    
    deviceNames = ndi.setup.internal.listDaqSystemNames(labName);
    
    for i = 1:numel(deviceNames)
	    dev = S.daqsystem_load('name', deviceNames{i});
	    
        if isempty(dev)
            daqSystemConfig = ndi.setup.DaqSystemConfiguration.fromLabDevice(labName, deviceNames{i});
            S = daqSystemConfig.create(S);
        end
    end
end
