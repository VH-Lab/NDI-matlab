function installWidgetsToolbox()
    toolboxIdentifier = "78895307-cc36-4970-8b66-0697da8f9352";

    % Check if toolbox is installed
    addonsTable = matlab.addons.installedAddons();

    isMatch = addonsTable.Identifier == toolboxIdentifier;

    if any(isMatch)
        if sum(isMatch) == 1
            toolboxVersion = addonsTable.Version(isMatch);
        elseif sum(isMatch) > 1
            idx = find(isMatch, 1, 'first');
            toolboxVersion = addonsTable.Version(idx);
            warning('Selected version %s', toolboxVersion)
        end
        toolboxFolder = matlab.internal.addons.util.retrieveInstallationFolderForAddOn(toolboxIdentifier, toolboxVersion);
        addpath(genpath(toolboxFolder));
    else
        fprintf('Please wait, installing widgets toolbox... ')
        fex = matlab.addons.repositories.FileExchangeRepository();
        addonUrl = fex.getAddonURL(toolboxIdentifier);

        tempFile = websave(fullfile(tempdir,'temp.mltbx'), addonUrl );
        matlab.addons.install(tempFile);
        delete(tempFile)
        fprintf('Done\n')
    end
    