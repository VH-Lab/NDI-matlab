function ndi_toolbox_setup(options)

    arguments
        options.SavePath (1,1) logical = true
    end
    
    % 1. Add dependencies to path
    addRequiredAdditionalSoftwareToPath()

    % 2. Check if the user has all the needed toolboxes, and show warning if they do not
    ndi.fun.check_Matlab_toolboxes()

    % 3. Run any warnings on various architectures
    ndi.fun.run_Linux_checks

    if options.SavePath
        savepath();
    end
end
