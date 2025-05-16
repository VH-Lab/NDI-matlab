function testToolbox(varargin)
    nditools.installMatBox()
    if isempty(userpath); userpath(pwd); end
    ndi_install()
    projectRootDir = nditools.projectdir();
    matbox.tasks.testToolbox(projectRootDir, ...
        "SourceFolderName", "", ...
        "ToolsFolderName", "", ...
        varargin{:})
end
