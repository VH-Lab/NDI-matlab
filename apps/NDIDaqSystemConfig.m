function app = NDIDaqSystemConfig(datasetFolder, epochFolder, epochOrganization, daqSystemConfiguration)
% NDIDaqSystemConfig - Launcher for the DAQ System Configuration App
%
%   Syntax: 
%       NDIDaqSystemConfig(datasetFolder)
    
    % Todo: Add detailed docstring
    
    arguments
        datasetFolder (1,1) string = missing
        epochFolder (1,1) string = missing
        epochOrganization (1,1) string ...
            {mustBeMember(epochOrganization, ["flat", "nested"])} = "flat"
        daqSystemConfiguration (1,1) ndi.setup.DaqSystemConfiguration = ndi.setup.DaqSystemConfiguration;
    end


    app = ndi.setup.gui.DAQSystemConfigurator(...
        datasetFolder, ...
        epochFolder, ...
        epochOrganization, ...
        daqSystemConfiguration);

    if nargout < 1
        clear app
    end
end
