function testToolbox(varargin)
    %nditools.installMatBox()
    if isempty(userpath)
        userFolder = fullfile(pwd, 'matlab-userdata');
        if ~isfolder(userFolder)
            mkdir(userFolder)
        end
        userpath(userFolder)
    end
    %ndi_install()
    projectRootDir = nditools.projectdir();
    matbox.installRequirements(fullfile(projectRootDir, 'tests'))
    matbox.tasks.testToolbox(projectRootDir, ...
        "SourceFolderName", "+ndi", ...
        "ToolsFolderName", "tests", ...
        varargin{:})
end
