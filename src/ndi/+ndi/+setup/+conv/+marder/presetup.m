function S = presetup(dirname, n, options)
    % PRESETUP - set up the Marder lab directory based on the directory name
    %
    % S = PRESETUP(DIRNAME, N, Name, Value, ...)
    %
    % Sets up a Marderlab directory for import using NDI methods.
    %
    % Inputs:
    %   DIRNAME - The full path to the directory to be set up. Must be a valid folder.
    %   N - An integer identifier (e.g., experiment number), must be >= 1.
    %
    % Optional Name-Value Pair Arguments:
    %   makeSubjects (logical) - If true, creates subject entries based on N.
    %                            Defaults to false.
    %   makeProbeTable (logical) - If true, generates the probeTable.csv file from
    %                              .abf files and opens it for editing.
    %                              Defaults to true.
    %
    % Outputs:
    %   S - The NDI session object for the created/configured directory.
    %
    % Example:
    %   % Basic setup, creates probe table by default
    %   S = presetup('/path/to/my/experiment', 1);
    %
    %   % Setup without creating probe table
    %   S = presetup('/path/to/my/experiment', 2, 'makeProbeTable', false);
    %
    %   % Setup and create subject entries
    %   S = presetup('/path/to/my/experiment', 3, 'makeSubjects', true);
    %

    arguments
        % Positional arguments with validation
        dirname (1,:) char {mustBeFolder}
        n (1,1) {mustBeNumeric, mustBeInteger, mustBeGreaterThanOrEqual(n, 1)}

        % Optional Name-Value arguments with defaults
        options.makeSubjects (1,1) logical = false
        options.makeProbeTable (1,1) logical = true
    end

    [parentdir,this_dir] = fileparts(dirname);

    disp(['Setting up NDI session for directory: ' this_dir ' in ' parentdir]);
    S = ndi.setup.lab('marderlab',this_dir,dirname);
    disp('NDI session object created.');

    % Conditionally run makesubjects
    if options.makeSubjects
        disp(['Creating subject entries with identifier: ' num2str(n)]);
        ndi.setup.conv.marder.makesubjects(S,n);
        disp('Subject entries creation attempted.');
    else
        disp('Skipping subject entry creation (makeSubjects=false).');
    end

    % Conditionally run probe table generation and editing
    if options.makeProbeTable
        disp('Generating probeTable.csv...');
        % Pass n==1 as the value for 'forceIgnore2' parameter
        ndi.setup.conv.marder.abf2probetable(S,'forceIgnore2', n==1);
        probeTablePath = fullfile(dirname, 'probeTable.csv');
        if exist(probeTablePath, 'file')
            disp(['Probe table created at: ' probeTablePath]);
            disp('Opening probeTable.csv for editing...');
            edit(probeTablePath);
        else
            warning('ndi.setup.conv.marder.abf2probetable did not seem to create probeTable.csv');
        end
    else
        disp('Skipping probe table generation (makeProbeTable=false).');
    end

    disp('Presetup function finished.');

end % function
