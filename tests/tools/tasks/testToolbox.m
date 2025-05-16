function testToolbox(varargin)
    installMatBox()
    projectRootDir = matboxtools.projectdir();
    matbox.tasks.testToolbox(projectRootDir, varargin{:})
end
