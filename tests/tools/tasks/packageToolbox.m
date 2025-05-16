function packageToolbox(releaseType, versionString)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end
    installMatBox()
    projectRootDir = matboxtools.projectdir();
    addpath(genpath(projectRootDir))
    matbox.tasks.packageToolbox(projectRootDir, releaseType, versionString)
end
