function codecheckToolbox()
    installMatBox()
    projectRootDir = matboxtools.projectdir();
    matbox.tasks.codecheckToolbox(projectRootDir)
end
