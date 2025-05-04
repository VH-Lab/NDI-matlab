function app = NDIDaqSystemConfig(datasetFolder, epochFolder, epochOrganization, daqSystemConfiguration)
% NDIDaqSystemConfig - Launcher for the DAQ System Configuration App
%
% Syntax: 
%   app = NDIDaqSystemConfig(datasetFolder) opens the NDI DAQ System
%        Configurator for a selected dataset.
%
% Input Arguments:
%   datasetFolder (string)      - The path to a root dataset folder for an NDI dataset.
%   epochFolder (string)        - The relative path (relative to datasetFolder) to
%                                 one subfolder containing epoch files
%   epochOrganization (string)  - The organization type of the epochs, which can
%                                 be "flat" or "nested".
%   daqSystemConfiguration (1,1) ndi.setup.DaqSystemConfiguration - An instance
%                                 of the DAQ system configuration class.
%
% Output Arguments:
%   app - An instance of the DAQ System Configurator GUI.
%
% If inputs are not provided, a set of dialogs will prompt the user for the
% necessary information to launch the app.

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
