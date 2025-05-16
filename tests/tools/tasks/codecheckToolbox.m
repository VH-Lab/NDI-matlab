function codecheckToolbox()
    installMatBox()
    projectRootDir = nditools.projectdir();
    matbox.tasks.codecheckToolbox(projectRootDir)
end
