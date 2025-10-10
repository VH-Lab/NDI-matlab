function check_Matlab_toolboxes

    V = ver;
    installedToolboxNames = {V.Name};

    filename = fullfile(ndi.common.PathConstants.CommonFolder, ...
        'requirements', 'ndi-matlab-toolboxes.json');
    t = fileread(filename);
    r = jsondecode(t);
    requiredToolboxNames = r.toolboxes.required;

    missingToolboxNames = setdiff(requiredToolboxNames, installedToolboxNames);
    missingToolboxNames = string(missingToolboxNames);

    if ~isempty(missingToolboxNames)
        missingToolboxNames = "  - " + missingToolboxNames;
        
        warningMessage = sprintf(...
            "The following required toolboxes were not found in your " + ...
            "MATLAB installation:\n%s\n" + ...
            "Key components of NDI-matlab will likely not work.", ...
            strjoin(missingToolboxNames, newline));

        warning("NDI:ToolboxCheck:MissingRequiredToolboxes", warningMessage) %#ok<SPWRN>
    end
