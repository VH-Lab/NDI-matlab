function ndi_setup(options)
    
    arguments
        options.InstallationLocation (1,1) string = missing 
        options.UseGit (1,1) logical = true % Todo
        options.InstallationMode (1,1) string ...
            {mustBeMember(options.InstallationMode, ["update", "missing"])} = "update"
    end
    
    if ismissing(options.InstallationLocation)
        if ~isempty(userpath)
            options.InstallationLocation = fullfile(userpath, 'NDI', 'NDI-Addons');
        else
            error(...
                'NDI:Setup:InstallationLocationMissing', ...
                ['MATLAB''s userpath is not configured and no installation ', ...
                'location is specified. Please specify a installation ', ...
                'location for installing NDI requirements.'])
        end
    end

    % Use MatBox to install dependencies/requirements
    downloadAndInstallMatBox();

    ndiRootDirectory = fileparts(mfilename('fullpath'));

    matbox.installRequirements(ndiRootDirectory, 'u', ...
        'InstallationLocation', options.InstallationLocation)
end

function downloadAndInstallMatBox()
    if ~exist('+matbox/installRequirements', 'file')
        sourceFile = 'https://raw.githubusercontent.com/ehennestad/matbox-actions/refs/heads/main/install-matbox/installMatBox.m';
        filePath = websave('installMatBox.m', sourceFile);
        installMatBox('commit')
        rehash()
        delete(filePath);
    end
end
