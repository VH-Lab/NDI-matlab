function addRequiredAdditionalSoftwareToPath()
% addRequiredAdditionalSoftwareToPath - Add required additional software
% for a toolbox to MATLAB's search path.
    livescriptFile = findInstallationLocationLivescript();
    if ~isempty(livescriptFile)
        installationLocations = getInstallationLocations(livescriptFile);
        addInstallationLocationsToPath(installationLocations)
    end
end

function result = findInstallationLocationLivescript()
% findInstallationLocationLivescript - Find livescript with installation
% locations for toolbox' Additional Required Software
    parentFolder = fileparts( fileparts( mfilename("fullpath") ) ); % Two levels up

    L = dir( fullfile(parentFolder, '**', 'getInstallationLocation.mlx') );
    
    if isempty(L)
        result = string.empty;
    else
        result = fullfile(L.folder, L.name);
    end
end

function installationLocations = getInstallationLocations(livescriptFile) %#ok<STOUT>
% getInstallationLocations - "Break out" the installation locations from
% the livescript and return the value as a cell array N x 2 (name, pathStr)
    editorObj = matlab.desktop.editor.openDocument( livescriptFile );
    codeText = editorObj.Text;
    codeText = strsplit(codeText, newline);
    codeText = codeText(2:end-2);
    codeText = strjoin(codeText, newline);
    eval(codeText) % Should assign installationLocations

    assert(exist('installationLocations', 'var'), ...
        'Expected "installationLocations" to be available.')
end

function addInstallationLocationsToPath(installationLocations)
% addInstallationLocationsToPath - Add the installation locations to
% MATLAB's search path
    for i = 1:height(installationLocations)
        name = installationLocations{i, 1};
        pathStr = installationLocations{i, 2};
        addpath(genpath(pathStr))
        fprintf('Added "%s" to MATLAB''s search path\n', name)
    end
end
