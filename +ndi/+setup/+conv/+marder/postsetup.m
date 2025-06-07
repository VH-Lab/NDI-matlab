function postsetup(S)
    % POSTSETUP - does all post-setup operations for Marder lab data
    %
    % POSTSETUP(S)
    %
    % 1) Generates epochprobemaps for ABF data
    % 2) Checks that the probes are available in S
    % 3) Generates the metadata with ndi.setup.conv.marder.pretemptable(S)
    %

    % Step 1:

    disp(['Setting up epochprobemaps...']);
    ndi.setup.conv.marder.abfprobetable2probemap(S)

    % Step 2:

    disp(['Verifying we can see the probes...']);
    S.cache.clear();
    p = S.getprobes()

    % Step 3:

    disp(['Charting temperature readings'])
    ndi.setup.conv.marder.preptemptable(S)

    disp(['Setting up stimulus parameters ...']);
    d = S.database_search(ndi.query('','isa','stimulus_parameter'));
    S.database_rm(d);
    d = ndi.setup.conv.marder.temptable2stimulusparameters(S);
    S.database_add(d);

    disp(['Setting probe locations...']);
    d = S.database_search(ndi.query('','isa','probe_location'));
    S.database_rm(d);
    d = ndi.setup.conv.marder.marderprobe2uberon(S)
    S.database_add(d);

    disp(['Setting sharp electrode offset measurements...']);
    ndi.setup.conv.marder.makeVoltageOffsets(S);

    disp(['Adding bath stimulation documents...']);
    d=S.database_search(ndi.query('','isa','stimulus_bath'));
    S.database_rm(d);
    d=ndi.setup.conv.marder.marderbath(S);
    S.database_add(d);

    disp(['Adding acclimation information...']);
    d = S.database_search(ndi.query('','isa','treatment'));
    S.database_rm(d);
    subs = S.database_search(ndi.query('','isa','subject'));
    if isfile([S.path filesep 'acclimate.txt'])
        for i=1:numel(subs)
            d = ndi.database.metadata.table2treatment(S,[S.path filesep 'acclimate.txt'],subs{i}.id());
        end
    else
        warning('no acclimation information found.')
    end

