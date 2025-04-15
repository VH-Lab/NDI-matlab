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
            {mustBeMember(epochOrganization, ["flat", "nested", ""])} = ""
        daqSystemConfiguration (1,1) ndi.setup.DaqSystemConfiguration = ndi.setup.DaqSystemConfiguration;
    end

    if ismissing(datasetFolder)
        answer = questdlg('Please select an NDI dataset folder', 'Select folder', 'Ok', 'Cancel', 'Ok');
        if ~strcmp(answer, 'Ok'); error("User canceled."); end
        datasetFolder = uigetdir();
        if datasetFolder == 0; error("User canceled."); end
    end

    if ismissing(epochFolder)
        answer = questdlg('Please select a subfolder containing epoch files', 'Select folder', 'Ok', 'Cancel', 'Ok');
        if ~strcmp(answer, 'Ok'); error("User canceled."); end
        epochFolder = uigetdir(datasetFolder);
        if epochFolder == 0; error("User canceled."); end
        epochFolder = strrep(epochFolder, datasetFolder, '');
    end

    if epochOrganization == ""
        answer = questdlg('Is the epochs organised in a flat or nested folder hierachy?', 'Select hierarchy type', 'Flat', 'Nested', 'Flat');
        epochOrganization = string(lower(answer));
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
