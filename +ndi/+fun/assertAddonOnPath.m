function assertAddonOnPath(addonName, options)
        
    arguments
        addonName (1,:) string = ""
        options.RequiredFor (1,1) string = ""
    end

    % Get struct array listing installed toolboxes
    V = ver;

    % Get the required toolboxes
    requirements = getRequirements();
    
    if addonName == ""
        requiredAddonNames = requirements.addons.required;
    else
        requiredAddonNames = addonName;
    end

    numRequiredAddons = numel(requiredAddonNames);

    % Check if all the required addons are installed
    isInstalled = false(1, numRequiredAddons);

    for j = 1:numRequiredAddons
        isInstalled(j) = any( strcmp(requiredAddonNames(j), {V.Name}) );
    end

    if any(~isInstalled)
        if sum(isInstalled) == 1
            messageHeader = "The following addon is required but was not found on MATLAB's searchpath:";
        else
            messageHeader = "The following addons are required but was not found on MATLAB's searchpath:";
        end

        if options.RequiredFor ~= ""
            messageHeader = replace(messageHeader, 'required', ...
                sprintf('required for "%s"', options.RequiredFor) );
        end

        missingAddonNames = requiredAddonNames(~isInstalled);
        missingAddonNames = "   " + missingAddonNames;
        error("NDI:RequiredAddonMissing", ...
            "%s\n%s\n", messageHeader, strjoin(missingAddonNames, newline))
    end
end

function requirements = getRequirements()
    
    ndi.globals
    
    filename = fullfile(ndi_globals.path.commonpath, ...
        'requirements', 'ndi-matlab-addons.json');
    
    t = vlt.file.textfile2char(filename);
    
    requirements = jsondecode(t);

end