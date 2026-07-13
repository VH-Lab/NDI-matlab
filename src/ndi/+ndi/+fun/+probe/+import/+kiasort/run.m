function outputFolder = run(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.RUN - run KIASORT on an exported NDI probe
%
% OUTPUTFOLDER = NDI.FUN.PROBE.IMPORT.KIASORT.RUN(S, PROBE, ...)
%
% Runs KIASORT on the binary that NDI.FUN.PROBE.EXPORT.ALL_BINARY / .BINARY (or the
% Electrode Data Export app) exported for the probe PROBE of the ndi.session S, then
% returns the KIASORT OUTPUTFOLDER. Because both NDI and KIASORT are MATLAB, this
% lets the whole export -> sort -> import loop run in one MATLAB session:
%
%    ndi.fun.probe.export.all_binary(S,'binary_dir','kiasort','binaryFileName','kiasort.bin');
%    ndi.fun.probe.import.kiasort.run(S, p);        % this function
%    ndi.fun.probe.import.kiasort.probe(S, p);      % import the results
%
% KIASORT must be on the MATLAB path. This function does NOT modify KIASORT; it only
% calls its public functions, so students can keep using KIASORT untouched.
%
% PROGRESS: when 'progressbar' is true (the default) and KIASORT's stage functions
% are available, this function runs the three KIASORT stages
% (kiaSort_main_extract_sample_data, kiaSort_main_sort_samples, kiaSort_main_sortData)
% directly and passes each a 'progressfcn' callback that drives an NDI progress bar
% (KIASORT's run_kiasort_nogui does not surface progress). Otherwise it calls
% run_kiasort_nogui. Either way KIASORT also writes a detailed log to
% [outputFolder]/KIASort_log.txt.
%
% KIASORT uses UMAP, so MATLAB must have a Python environment (pyenv) with
% umap-learn installed; otherwise the sort errors in pythonUMAP.
%
% The exported binary is expected at
%       [S.path]/[kiasort_dir]/[probe_elementstring]/[binaryFileName]
% and KIASORT writes its output into the [subdir] subfolder (default
% 'kiasort_output'), which is where NDI.FUN.PROBE.IMPORT.KIASORT.PROBE looks for it.
%
% The channel count and sampling rate are read directly from the probe. If no
% channel-map file is supplied and none exists next to the binary, this function
% builds one from the probe's geometry (NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP), or a
% default linear map if the probe has no geometry.
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | kiasort_dir ('kiasort')  | Directory (within S.path) holding the export.       |
% | binaryFileName           | Name of the exported binary in the probe's dir.     |
% |  ('kiasort.bin')         |                                                     |
% | subdir ('kiasort_output')| Subfolder for the KIASORT output.                   |
% | channelMapFile ('')      | Kilosort-style channel map .mat. '' => use/build.   |
% | cfg_overrides (struct()) | Extra KIASORT config overrides (win over defaults). |
% | dataType ('int16')       | Data type of the exported binary.                   |
% | progressbar (true)       | Show an NDI progress bar driven by KIASORT's        |
% |                          |   per-stage progressfcn (runs the stages directly). |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.PROBE, NDI.FUN.PROBE.IMPORT.KIASORT.CURATE,
%   NDI.FUN.PROBE.EXPORT.ALL_BINARY, NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP

    arguments
        S
        probe
        options.kiasort_dir (1,:) char = 'kiasort'
        options.binaryFileName (1,:) char = 'kiasort.bin'
        options.subdir (1,:) char = 'kiasort_output'
        options.channelMapFile (1,:) char = ''
        options.cfg_overrides (1,1) struct = struct()
        options.dataType (1,:) char = 'int16'
        options.progressbar (1,1) logical = true
        options.verbose (1,1) double = 1
    end

    % KIASORT must be present. The granular (progress) path needs the stage
    % functions; the fallback needs run_kiasort_nogui.
    stage_fns = {'kiaSort_main_configs','kiaSort_extended_configs','kiaSort_hidden_configs', ...
        'sorting_hyperparameters_in','load_channel_map','derive_num_channel_extract', ...
        'kiaSort_main_extract_sample_data','kiaSort_main_sort_samples','kiaSort_main_sortData'};
    have_stages = all(cellfun(@(f) exist(f,'file')==2, stage_fns));
    if ~have_stages && exist('run_kiasort_nogui','file')~=2,
        error(['KIASORT was not found on the MATLAB path. Add it (e.g. ' ...
            'addpath(genpath(''/path/to/KIASORT''))) before calling this function.']);
    end;

    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    probedir = fullfile(S.path, options.kiasort_dir, elestr);
    binaryfile = fullfile(probedir, options.binaryFileName);
    if ~isfile(binaryfile),
        error(['Exported binary not found: ' binaryfile '. Export the probe first ' ...
            '(ndi.fun.probe.export.all_binary or the Electrode Data Export app).']);
    end;

    outputFolder = fullfile(probedir, options.subdir);
    if ~isfolder(outputFolder),
        mkdir(outputFolder);
    end;

    % channel count and sampling rate straight from the probe (match the export)
    et = probe.epochtable();
    if isempty(et),
        error(['Probe ' elestr ' has no epochs.']);
    end;
    t0 = et(1).t0_t1{1}(1);
    [d,~] = probe.readtimeseries(et(1).epoch_id, t0, t0);
    num_channels = size(d,2);
    sampling_frequency = probe.samplerate(et(1).epoch_id);

    % channel map: given file, else use/build channel_map.mat next to the binary
    channelMapFile = options.channelMapFile;
    if isempty(channelMapFile),
        channelMapFile = fullfile(probedir, 'channel_map.mat');
        if ~isfile(channelMapFile),
            tf = ndi.fun.probe.geometry.toKilosortMap(S, probe, channelMapFile, ...
                'num_channels', num_channels, 'verbose', options.verbose);
            if ~tf,
                ndi.fun.probe.geometry.writeKilosortMap(channelMapFile, 'num_channels', num_channels, ...
                    'verbose', options.verbose);
            end;
        end;
    end;

    % build the KIASORT config: sensible defaults from the probe, then user overrides
    ovr = options.cfg_overrides;
    ovr = setDefault(ovr, 'numChannels', num_channels);
    ovr = setDefault(ovr, 'samplingFrequency', sampling_frequency);
    ovr = setDefault(ovr, 'dataType', options.dataType);

    if options.verbose,
        disp(['Running KIASORT on ' binaryfile ' (' int2str(num_channels) ' channels, ' ...
            num2str(sampling_frequency) ' Hz); output -> ' outputFolder '.']);
    end;

    % Prefer run_kiasort_nogui's own progressfcn passthrough when the (fork) version
    % supports it (declared varargin -> nargin < 0); this keeps NDI decoupled from
    % KIASORT's internal stage sequence. Fall back to driving the stages directly
    % (run_stages_with_progress) on an older KIASORT that lacks the passthrough.
    have_nogui = exist('run_kiasort_nogui','file')==2;
    nogui_supports_progress = false;
    if have_nogui,
        try, nogui_supports_progress = nargin('run_kiasort_nogui') < 0; catch, end
    end;

    if options.progressbar && nogui_supports_progress,
        pbtag = ['kiasort:' elestr];
        pbw = i_makeBar(['KIASORT: ' elestr], ['Sorting ' elestr], pbtag);
        cleanupObj = onCleanup(@() i_closeBar(pbw, pbtag)); %#ok<NASGU>
        cb = @(pct,msg) i_updateBar(pbw, pbtag, pct);
        run_kiasort_nogui(binaryfile, outputFolder, channelMapFile, ovr, ...
            'progressfcn', cb, 'verbose', logical(options.verbose));
    elseif options.progressbar && have_stages,
        ndi.fun.probe.import.kiasort.run_stages_with_progress(binaryfile, outputFolder, ...
            channelMapFile, ovr, elestr, options.verbose);
    elseif have_nogui,
        run_kiasort_nogui(binaryfile, outputFolder, channelMapFile, ovr);
    else,
        ndi.fun.probe.import.kiasort.run_stages_with_progress(binaryfile, outputFolder, ...
            channelMapFile, ovr, elestr, options.verbose);
    end;

    if options.verbose,
        disp(['KIASORT finished for probe ' elestr '. Import with ndi.fun.probe.import.kiasort.probe(S, probe).']);
    end;

end

function s = setDefault(s, field, value)
    if ~isfield(s, field) || isempty(s.(field)),
        s.(field) = value;
    end;
end

function pbw = i_makeBar(titleStr, labelStr, tag)
    % An ndi.gui.component.ProgressBarWindow docks into an open ndi.gui.navigator's
    % Progress pane (and falls back to a standalone window when none is open).
    pbw = [];
    try
        pbw = ndi.gui.component.ProgressBarWindow(titleStr);
        pbw.addBar('Label', labelStr, 'Tag', tag, 'Auto', false);
    catch
        pbw = [];
    end
end

function i_updateBar(pbw, tag, frac)
    try
        if ~isempty(pbw) && isvalid(pbw),
            pbw.updateBar(tag, max(0, min(1, frac)));
            drawnow limitrate;
        end;
    catch
    end
end

function i_closeBar(pbw, tag)
    try
        if ~isempty(pbw) && isvalid(pbw),
            pbw.removeBar(tag);
        end;
    catch
    end
end
