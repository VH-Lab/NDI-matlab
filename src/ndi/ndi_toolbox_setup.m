function ndi_toolbox_setup(options)

    arguments
        options.SavePath (1,1) logical = true
    end

    % 1. Check if the user has all the needed toolboxes, and show warning if they do not
    ndi.fun.check_Matlab_toolboxes()

    % 2. Run any warnings on various architectures
    ndi.fun.run_Linux_checks

    addRequiredAdditionalSoftwareToPath()

    if options.SavePath
        savepath();
    end
end
