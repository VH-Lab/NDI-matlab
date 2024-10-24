function S = presetup(dirname, n)
    % PRESETUP - set up the Marder lab directory based on the directory name
    %
    % S = PRESETUP(DIRNAME, N)
    %
    % Sets up a Marderlab directory for import

    [parentdir,this_dir] = fileparts(dirname);

    S = ndi.setup.lab('marderlab',this_dir,dirname);
    ndi.setup.conv.marder.makesubjects(S,n);

    ndi.setup.conv.marder.abf2probetable(S,'forceIgnore2',n==1)

    edit([dirname filesep 'probeTable.csv']);
