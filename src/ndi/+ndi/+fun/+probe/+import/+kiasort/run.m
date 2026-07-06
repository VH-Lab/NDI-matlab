function outputFolder = run(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.RUN - run KIASORT on an exported NDI probe
%
% OUTPUTFOLDER = NDI.FUN.PROBE.IMPORT.KIASORT.RUN(S, PROBE, ...)
%
% Runs KIASORT (via its headless entry point run_kiasort_nogui) on the binary that
% NDI.FUN.PROBE.EXPORT.ALL_BINARY / .BINARY exported for the probe PROBE of the
% ndi.session S, then returns the KIASORT OUTPUTFOLDER. Because both NDI and KIASORT
% are MATLAB, this lets the whole export -> sort -> import loop run in one MATLAB
% session:
%
%    ndi.fun.probe.export.all_binary(S,'binary_dir','kiasort','binaryFileName','kiasort.bin');
%    ndi.fun.probe.import.kiasort.run(S, p);        % this function
%    ndi.fun.probe.import.kiasort.probe(S, p);      % import the results
%
% KIASORT must be on the MATLAB path (its run_kiasort_nogui function must be
% visible). This function does NOT modify KIASORT; it only calls its public
% headless entry point, so students can keep using KIASORT untouched.
%
% The exported binary is expected at
%       [S.path]/[kiasort_dir]/[probe_elementstring]/[binaryFileName]
% and KIASORT writes its output into the [subdir] subfolder of that directory
% (default 'kiasort_output'), which is exactly where NDI.FUN.PROBE.IMPORT.KIASORT.PROBE
% looks for it.
%
% The channel count and sampling rate are read directly from the probe, so the
% KIASORT config matches the exported data. If no channel-map file is supplied and
% none exists next to the binary, a default Kilosort-style map is written with
% NDI.FUN.PROBE.EXPORT.CHANNELMAP (pass 'channelMapFile' for the real geometry).
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | kiasort_dir ('kiasort')  | Directory (within S.path) holding the export.       |
% | binaryFileName           | Name of the exported binary in the probe's dir.     |
% |  ('kiasort.bin')         |                                                     |
% | subdir ('kiasort_output')| Subfolder for the KIASORT output.                   |
% | channelMapFile ('')      | Kilosort-style channel map .mat. '' => use/create a |
% |                          |   'channel_map.mat' next to the binary.             |
% | cfg_overrides (struct()) | Extra KIASORT config overrides (merged last, so     |
% |                          |   they win over numChannels/samplingFrequency).     |
% | dataType ('int16')       | Data type of the exported binary.                   |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.PROBE, NDI.FUN.PROBE.EXPORT.ALL_BINARY,
%   NDI.FUN.PROBE.EXPORT.CHANNELMAP

    arguments
        S
        probe
        options.kiasort_dir (1,:) char = 'kiasort'
        options.binaryFileName (1,:) char = 'kiasort.bin'
        options.subdir (1,:) char = 'kiasort_output'
        options.channelMapFile (1,:) char = ''
        options.cfg_overrides (1,1) struct = struct()
        options.dataType (1,:) char = 'int16'
        options.verbose (1,1) double = 1
    end

    if exist('run_kiasort_nogui','file')~=2,
        error(['run_kiasort_nogui was not found on the MATLAB path. Add KIASORT to the ' ...
            'path (e.g. addpath(genpath(''/path/to/KIASORT''))) before calling this function.']);
    end;

    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    probedir = fullfile(S.path, options.kiasort_dir, elestr);
    binaryfile = fullfile(probedir, options.binaryFileName);
    if ~isfile(binaryfile),
        error(['Exported binary not found: ' binaryfile '. Run ndi.fun.probe.export.all_binary ' ...
            '(with ''binary_dir'',''' options.kiasort_dir ''' and ''binaryFileName'',''' ...
            options.binaryFileName ''') first.']);
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

    % channel map: use the given file, else use/create channel_map.mat by the binary
    channelMapFile = options.channelMapFile;
    if isempty(channelMapFile),
        channelMapFile = fullfile(probedir, 'channel_map.mat');
        if ~isfile(channelMapFile),
            ndi.fun.probe.export.channelmap(channelMapFile, 'num_channels', num_channels, ...
                'verbose', options.verbose);
        end;
    end;

    % build the KIASORT config: sensible defaults from the probe, then user overrides
    cfg = options.cfg_overrides;
    cfg = setDefault(cfg, 'numChannels', num_channels);
    cfg = setDefault(cfg, 'samplingFrequency', sampling_frequency);
    cfg = setDefault(cfg, 'dataType', options.dataType);

    if options.verbose,
        disp(['Running KIASORT on ' binaryfile ' (' int2str(num_channels) ' channels, ' ...
            num2str(sampling_frequency) ' Hz); output -> ' outputFolder '.']);
    end;

    run_kiasort_nogui(binaryfile, outputFolder, channelMapFile, cfg);

    if options.verbose,
        disp(['KIASORT finished for probe ' elestr '. Import with ndi.fun.probe.import.kiasort.probe(S, probe).']);
    end;

end

function s = setDefault(s, field, value)
    if ~isfield(s, field) || isempty(s.(field)),
        s.(field) = value;
    end;
end
