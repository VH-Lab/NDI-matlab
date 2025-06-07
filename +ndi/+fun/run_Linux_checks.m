function run_Linux_checks
    % RUN_LINUX_CHECKS - run any Linux compatibility checks
    %
    % RUN_LINUX_CHECKS
    %
    % Run Linux compatibility checks and provide any warnings needed.
    %
    %

    archstr = computer('arch');

    if strcmpi(archstr,'GLNXA64') % Linux
        v = ver('MATLAB');
        if strcmpi(v(1).Version,'9.11')
            % this problem was fixed by no longer requiring Simulink
        end
    end
