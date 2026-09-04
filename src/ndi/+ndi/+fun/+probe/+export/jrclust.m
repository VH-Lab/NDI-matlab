function prmFile = jrclust(S, probe, options)
% NDI.FUN.PROBE.EXPORT.JRCLUST - create a JRCLUST parameter file for an NDI probe
%
% PRMFILE = NDI.FUN.PROBE.EXPORT.JRCLUST(S, PROBE, ...)
%
% Prepares the ndi.probe (or ndi.element) PROBE of the ndi.session S for spike
% sorting with JRCLUST, by writing a JRCLUST parameter (.prm) file at
%
%       [S.path]/.JRCLUST/[element string]/jrclust.prm
%
% and returns its path. This is the "export" step of the NDI/JRCLUST pipeline:
%
%    ndi.fun.probe.export.jrclust(S, p);            % this function - write jrclust.prm
%    edit(prmFile)                                  % adjust parameters by hand
%    ndi.fun.probe.import.jrclust.run(S, p);        % 'jrc detect' then 'jrc sort'
%    ndi.fun.probe.import.jrclust.curate(S, p);     % 'jrc manual' - annotate the units
%    ndi.fun.probe.import.jrclust.probe(S, p);      % import the neurons into NDI
%
% No sample data is copied: the parameter file uses JRCLUST's 'ndi' recording format,
% so JRCLUST reads the probe's data directly out of NDI, epoch by epoch. That format
% is provided by the VH Lab fork of JRCLUST (https://github.com/VH-Lab/JRCLUST,
% branch 'ndi_import'); NDI.FUN.PROBE.IMPORT.JRCLUST.INSTALL checks for it, and this
% function errors if it is not installed.
%
% The parameter file lists every epoch of PROBE (in ndi.element/epochtable order) as
% a recording to sort, unless 'epochs' names a subset. JRCLUST concatenates those
% recordings in the listed order, and NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE maps the
% resulting spike times back into each epoch, so do not reorder the list by hand.
%
% PROBE GEOMETRY: if the probe has a 'probe_geometry' document, the site locations
% (siteLoc), shank ids (shankMap) and unconnected channels (ignoreChans) are filled
% in from it, via NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP; the channel map that was
% used is left next to the parameter file as 'channel_map.mat'. Otherwise a single
% column of sites spaced 'defaultSpacing' microns apart is written as a placeholder
% and a warning is issued - edit siteLoc/shankMap/siteMap before sorting.
%
% The written file is JRCLUST's complete parameter set, so every parameter can be
% adjusted by editing it (NDI.FUN.PROBE.IMPORT.JRCLUST.EDITPARAMETERS opens it).
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% | epochs ({})              | Cell array of epoch ids to sort, in order. {} means |
% |                          |   every epoch of the probe.                         |
% | useGPU (false)           | JRCLUST 'useGPU'. Off unless you have a supported   |
% |                          |   GPU.                                              |
% | maxSecLoad (100)         | JRCLUST 'maxSecLoad', seconds of data loaded at a   |
% |                          |   time. Raise it if your machine has the memory.    |
% | evtGroupRad (75)         | JRCLUST 'evtGroupRad', the maximum distance (in     |
% |                          |   microns) over which sites are grouped for spike   |
% |                          |   extraction. Use a large value (e.g. 800) to group |
% |                          |   every site of a tetrode-like probe.               |
% | ignoreChans ([])         | Channel numbers to ignore (e.g. dead channels).     |
% |                          |   Added to any unconnected channels found in the    |
% |                          |   probe's geometry.                                 |
% | geometry (true)          | Fill in site geometry from the probe's              |
% |                          |   'probe_geometry' document when one exists.        |
% | defaultSpacing (50)      | Site spacing (microns) of the placeholder geometry  |
% |                          |   used when the probe has no geometry document.     |
% | extraParams (struct())   | Any further JRCLUST parameters to set, as fields of |
% |                          |   a struct (e.g. struct('nSiteDir',4)).             |
% | overwrite (false)        | Overwrite an existing parameter file. When false,   |
% |                          |   an existing file is an error (JRCLUST also backs  |
% |                          |   the old file up as jrclust.prm.bak).              |
% | edit (false)             | Open the parameter file in the MATLAB editor.       |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.INSTALL, NDI.FUN.PROBE.IMPORT.JRCLUST.RUN,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE, NDI.FUN.PROBE.IMPORT.JRCLUST.PATHS,
%   NDI.GUI.APP.JRCLUST
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    prmFile = ndi.fun.probe.export.jrclust(S, p{1}, 'edit', true);
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
        options.epochs cell = {}
        options.useGPU (1,1) logical = false
        options.maxSecLoad (1,1) double {mustBePositive} = 100
        options.evtGroupRad (1,1) double {mustBePositive} = 75
        options.ignoreChans (1,:) double = []
        options.geometry (1,1) logical = true
        options.defaultSpacing (1,1) double {mustBePositive} = 50
        options.extraParams (1,1) struct = struct()
        options.overwrite (1,1) logical = false
        options.edit (1,1) logical = false
        options.verbose (1,1) double = 1
    end

    verbose = options.verbose;

    % Step 1: JRCLUST, with its NDI support, must be installed

    info = ndi.fun.probe.import.jrclust.install();
    if ~info.ok,
        error('ndi:fun:probe:export:jrclust:notInstalled', '%s', info.summary);
    end;

    % JRCLUST re-opens the session from the path recorded in the parameter file, as
    % ndi.session.dir(ndiPath), so a session that is not on disk that way cannot be
    % sorted in place.
    if ~isa(S,'ndi.session.dir'),
        warning('ndi:fun:probe:export:jrclust:notADirSession', ...
            ['This session is a %s, but JRCLUST reopens it with ndi.session.dir(''%s''). ' ...
            'If that path is not an NDI session directory, JRCLUST will not be able to ' ...
            'read the data.'], class(S), S.path);
    end;

    % Step 2: where the parameter file goes

    P = ndi.fun.probe.import.jrclust.paths(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);
    prmFile = P.prmFile;

    if isfile(prmFile) && ~options.overwrite,
        error('ndi:fun:probe:export:jrclust:exists', ...
            ['A JRCLUST parameter file already exists at %s. Edit it, or pass ' ...
            '''overwrite'',true to write a new one (the old one is backed up as ' ...
            '%s.bak).'], prmFile, options.prmName);
    end;

    if ~isfolder(P.directory),
        mkdir(P.directory);
    end;

    % Step 3: the epochs to sort, in the order JRCLUST will concatenate them

    et = probe.epochtable();
    if isempty(et),
        error('ndi:fun:probe:export:jrclust:noEpochs', ...
            'Probe %s has no epochs to sort.', P.elementString);
    end;
    allEpochs = {et.epoch_id};
    if isempty(options.epochs),
        epochIds = allEpochs;
    else,
        epochIds = cellfun(@char, options.epochs, 'UniformOutput', false);
        missing = setdiff(epochIds, allEpochs);
        if ~isempty(missing),
            error('ndi:fun:probe:export:jrclust:noSuchEpoch', ...
                'Probe %s has no epoch(s) named %s.', P.elementString, strjoin(missing,', '));
        end;
    end;

    % Step 4: channel count and sample rate, straight from the probe

    nChans = ndi.fun.probe.channelCount(probe);
    if isempty(nChans),
        t0 = et(1).t0_t1{1}(1);
        [d,~] = probe.readtimeseries(et(1).epoch_id, t0, t0);
        nChans = size(d,2);
    end;
    sampleRate = probe.samplerate(epochIds{1});

    % Step 5: geometry. Reuse the Kilosort-style channel map builder, which already
    % aligns the probe's sites to the channel order, then translate it to JRCLUST's
    % siteLoc/shankMap. JRCLUST requires nonnegative site locations, so the
    % coordinates are shifted to start at 0.

    siteLoc = [];
    shankMap = [];
    ignoreChans = options.ignoreChans(:)';

    if options.geometry,
        mapFile = fullfile(P.directory,'channel_map.mat');
        tf = false;
        try
            tf = ndi.fun.probe.geometry.toKilosortMap(S, probe, mapFile, ...
                'num_channels', nChans, 'verbose', verbose);
        catch ME
            warning(['Could not read the probe geometry (' ME.message '); using a ' ...
                'placeholder geometry instead.']);
        end;
        if tf,
            m = load(mapFile);
            x = double(m.xcoords(:));
            y = double(m.ycoords(:));
            siteLoc = [x-min(x) y-min(y)];
            if isfield(m,'kcoords') && ~isempty(m.kcoords),
                shankMap = double(m.kcoords(:));
                shankMap(shankMap<1) = 1;
            end;
            if isfield(m,'connected'),
                ignoreChans = union(ignoreChans, find(~logical(m.connected(:)))');
            end;
        end;
    end;

    if isempty(siteLoc),
        warning('ndi:fun:probe:export:jrclust:noGeometry', ...
            ['Probe %s has no geometry on file; writing a placeholder single-column ' ...
            'geometry with %g micron spacing. Edit siteLoc, siteMap and shankMap in %s ' ...
            'before sorting.'], P.elementString, options.defaultSpacing, prmFile);
        siteLoc = [zeros(nChans,1) options.defaultSpacing*(0:nChans-1)'];
    end;
    if isempty(shankMap),
        shankMap = ones(nChans,1);
    end;

    % Step 6: assemble the parameters and let JRCLUST write the file

    cfgData = struct();
    cfgData.recordingFormat      = 'ndi'; % JRCLUST reads the data out of NDI
    cfgData.outputDir            = P.directory;
    cfgData.rawRecordings        = epochIds;
    cfgData.nChans               = nChans;
    cfgData.sampleRate           = sampleRate;
    cfgData.headerOffset         = 0;     % meaningless for NDI
    cfgData.tallSkinny           = 1;     % ndiRecording returns channels x samples
    cfgData.dataTypeRaw          = 'int16';   % meaningless for NDI
    cfgData.dataTypeExtracted    = 'single';  % ndiRecording returns single
    cfgData.bitScaling           = 1;
    cfgData.ndiPath              = S.path;
    cfgData.ndiElementName       = probe.name;
    cfgData.ndiElementReference  = probe.reference;
    cfgData.ndiScale             = 1;
    cfgData.siteLoc              = siteLoc;
    cfgData.siteMap              = 1:nChans;  % the map above is already in channel order
    cfgData.shankMap             = shankMap;
    cfgData.ignoreChans          = ignoreChans;
    cfgData.useGPU               = options.useGPU;
    cfgData.useParfor            = 0;
    cfgData.maxSecLoad           = options.maxSecLoad;
    cfgData.evtGroupRad          = options.evtGroupRad;
    cfgData.nSiteDir             = [];  % let JRCLUST group by evtGroupRad
    cfgData.nSitesExcl           = [];

    fn = fieldnames(options.extraParams);
    for i=1:numel(fn),
        cfgData.(fn{i}) = options.extraParams.(fn{i});
    end;

    % feval: this function is itself named 'jrclust' within the package
    % ndi.fun.probe.export, so an unqualified 'jrclust.Config' would be resolved
    % against this function rather than JRCLUST's top-level 'jrclust' package.
    hCfg = feval('jrclust.Config', cfgData);
    if ~isfile(prmFile),
        fclose(fopen(prmFile,'w')); % touch the file so JRCLUST can bind to it
    end;
    hCfg.setConfigFile(prmFile, 0);
    hCfg.save('', 1); % 1: write every parameter, so all of them can be edited

    if verbose,
        disp(['Wrote JRCLUST parameter file ' prmFile ' (' int2str(nChans) ' channels, ' ...
            int2str(numel(epochIds)) ' epoch(s), ' num2str(sampleRate) ' Hz).']);
    end;

    if options.edit,
        edit(prmFile);
    end;

end % jrclust()
