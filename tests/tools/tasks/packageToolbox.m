function packageToolbox(releaseType, versionString)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end
    installMatBox()
    projectRootDir = nditools.projectdir();
    addpath(projectRootDir)
    matbox.tasks.packageToolbox(projectRootDir, releaseType, versionString)
end
