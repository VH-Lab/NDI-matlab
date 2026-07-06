function R = results(kdir, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.RESULTS - read the KIASORT output for a probe
%
% R = NDI.FUN.PROBE.IMPORT.KIASORT.RESULTS(KDIR, ...)
%
% Reads the sorted-spike output that KIASORT writes into the output folder KDIR.
% KIASORT (via run_kiasort_nogui / the GUI) writes its results into two
% subfolders of the output folder:
%
%       KDIR/RES_Sorted/spike_idx.h5      - absolute sample index of each spike
%       KDIR/RES_Sorted/unifiedLabels.h5  - cross-channel unit id of each spike
%       KDIR/RES_Sorted/channelNum.h5     - detection channel of each spike
%       KDIR/Sorted_Samples/sorted_samples.mat - per-unit stats (mean waveforms)
%
% If 'curated' is true, the '_curated' variants (spike_idx_curated.h5, etc.) are
% preferred and the function falls back to the non-curated files (with a warning)
% if they are absent.
%
% IMPORTANT: KIASORT spike indices are 1-based (the sample index into the sorted
% recording, MATLAB convention). To match ndi.fun.probe.import.kilosort (and the
% concatenated-stream sample bookkeeping of ndi.fun.probe.export.binary, which is
% 0-based), the returned R.spike_samples_global is converted to 0-based here by
% subtracting 1. Downstream code should treat it exactly like the 0-based
% spike_times.npy values from Kilosort.
%
% R is a structure with fields:
%   res_dir             - the RES_Sorted directory that was read
%   suffix              - '' or '_curated', indicating which files were read
%   spike_samples_global- 0-based sample index of each spike (Nx1 double)
%   spike_units         - unit id of each spike (Nx1 double)
%   spike_channels      - detection channel of each spike (Nx1 double), or [] if absent
%   unit_stats          - the crossChannelStats.unified_labels struct loaded from
%                          sorted_samples.mat (fields .label, .channelID,
%                          .meanWaveforms, ...), or [] if the file is absent. Used
%                          by ndi.fun.probe.import.kiasort.meanwaveform.
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default) | Description                                              |
% |---------------------|----------------------------------------------------------|
% | curated (false)     | Prefer the '_curated' output files when present.         |
% | need_stats (true)   | Load per-unit stats from sorted_samples.mat (for         |
% |                     |   waveforms). If false, R.unit_stats is [].              |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.PROBE, NDI.FUN.PROBE.IMPORT.KIASORT.LABELS,
%   NDI.FUN.PROBE.IMPORT.KIASORT.MEANWAVEFORM

    arguments
        kdir (1,:) char
        options.curated (1,1) logical = false
        options.need_stats (1,1) logical = true
    end

    res_dir = fullfile(kdir, 'RES_Sorted');
    if ~isfolder(res_dir),
        error(['KIASORT RES_Sorted folder not found at ' res_dir '. Was KIASORT run with this folder as its output?']);
    end;

    % choose curated vs non-curated files
    suffix = '';
    if options.curated,
        if isfile(fullfile(res_dir,'spike_idx_curated.h5')) && ...
                isfile(fullfile(res_dir,'unifiedLabels_curated.h5')),
            suffix = '_curated';
        else,
            warning('ndi:fun:probe:import:kiasort:results:noCurated', ...
                ['Curated KIASORT outputs missing in ' res_dir '. Loading non-curated output.']);
        end;
    end;

    spike_idx_file = fullfile(res_dir, ['spike_idx' suffix '.h5']);
    unified_file = fullfile(res_dir, ['unifiedLabels' suffix '.h5']);
    if ~isfile(spike_idx_file) || ~isfile(unified_file),
        error(['Expected KIASORT files spike_idx' suffix '.h5 and unifiedLabels' suffix ...
            '.h5 in ' res_dir '.']);
    end;

    % KIASORT stores each field as a single dataset named '/<field>'
    spike_idx_1based = double(h5read(spike_idx_file, ['/spike_idx' suffix]));
    spike_units = double(h5read(unified_file, ['/unifiedLabels' suffix]));

    R = struct();
    R.res_dir = res_dir;
    R.suffix = suffix;
    R.spike_samples_global = spike_idx_1based(:) - 1; % 1-based -> 0-based
    R.spike_units = spike_units(:);

    R.spike_channels = [];
    chan_file = fullfile(res_dir, ['channelNum' suffix '.h5']);
    if isfile(chan_file),
        R.spike_channels = double(h5read(chan_file, ['/channelNum' suffix]));
        R.spike_channels = R.spike_channels(:);
    end;

    % per-unit statistics (mean waveforms) from the sample-sorting stage
    R.unit_stats = [];
    if options.need_stats,
        R.unit_stats = ndi.fun.probe.import.kiasort.unitstats(kdir, suffix);
    end;

end
