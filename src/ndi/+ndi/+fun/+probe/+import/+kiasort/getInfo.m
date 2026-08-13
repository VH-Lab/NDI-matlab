function [info, summary] = getInfo(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.GETINFO - summarize the KIASORT output for a probe
%
% [INFO, SUMMARY] = NDI.FUN.PROBE.IMPORT.KIASORT.GETINFO(S, PROBE, ...)
%
% Reads the KIASORT output folder for the probe PROBE in the ndi.session S and
% returns a summary of what is there (without importing anything or touching the
% database). This is useful for inspecting a sort before calling
% NDI.FUN.PROBE.IMPORT.KIASORT.PROBE.
%
% The directory is located the same way as the importer:
%
%       [S.path]/[kiasort_dir]/[probe_elementstring]/[subdir]/
%
% INFO is a structure with fields:
%   directory          - the KIASORT output directory that was read
%   res_dir            - the RES_Sorted directory that was read
%   suffix             - '' or '_curated'
%   num_units          - number of KIASORT units
%   unit_ids           - vector of unit ids
%   unit_labels        - string array of the label for each unit
%   unique_tags        - string array of the distinct labels present
%   tag_counts         - number of units carrying each unique tag (parallel to
%                          unique_tags)
%   num_spikes_total   - total number of spikes across all units
%   num_spikes         - vector of spike counts per unit (parallel to unit_ids)
%   would_import       - logical vector, true for units whose tag is in
%                          quality_labels (i.e. would be imported by default)
%   num_would_import   - number of units that would be imported
%   samples_per_waveform - samples per mean waveform (NaN if unavailable)
%   num_channels       - channels in the mean waveforms (NaN if unavailable)
%
% SUMMARY is a multiline character array giving a human-readable version of INFO.
%
% Name/value pairs (defaults match NDI.FUN.PROBE.IMPORT.KIASORT.PROBE):
% ---------------------------------------------------------------------------------
% | Parameter (default)            | Description                                   |
% |--------------------------------|-----------------------------------------------|
% | kiasort_dir ('kiasort')        | Name of the directory holding KIASORT output  |
% | subdir ('kiasort_output')      | Subfolder within the probe's directory        |
% | noSubFolder (false)            | If true, read directly from the probe's dir   |
% | curated (false)                | Prefer the '_curated' output files if present |
% | quality_labels (["good"])      | Labels that would be imported (for would_import)|
% ---------------------------------------------------------------------------------
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    [info, summary] = ndi.fun.probe.import.kiasort.getInfo(S, p{1});
%    disp(summary);
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.PROBE

    arguments
        S
        probe
        options.kiasort_dir (1,:) char = 'kiasort'
        options.subdir (1,:) char = 'kiasort_output'
        options.noSubFolder (1,1) logical = false
        options.curated (1,1) logical = false
        options.quality_labels (1,:) string = "good"
    end

    % Step 1: locate the KIASORT output directory (same logic as the importer)
    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    subdir = options.subdir;
    if options.noSubFolder,
        subdir = '';
    end;
    kdir = fullfile(S.path, options.kiasort_dir, elestr, subdir);

    if ~isfolder(fullfile(kdir,'RES_Sorted')),
        error(['KIASORT RES_Sorted folder not found in ' kdir '.']);
    end;

    % Step 2: read the output and the unit labels
    R = ndi.fun.probe.import.kiasort.results(kdir, 'curated', options.curated);
    [unit_ids, unit_labels] = ndi.fun.probe.import.kiasort.labels(kdir, 'curated', options.curated);

    unit_ids = unit_ids(:);
    unit_labels = unit_labels(:);
    nC = numel(unit_ids);

    % Step 3: spike counts per unit
    num_spikes = zeros(nC,1);
    for i=1:nC,
        num_spikes(i) = sum(R.spike_units==unit_ids(i));
    end;

    % Step 4: unique tags and their unit counts
    [unique_tags, ~, ic] = unique(unit_labels);
    tag_counts = accumarray(ic(:), 1);

    % Step 5: which units would be imported under the quality filter
    want = lower(string(options.quality_labels));
    would_import = false(nC,1);
    for i=1:nC,
        would_import(i) = any(want==lower(string(unit_labels(i))));
    end;

    % Step 6: mean-waveform dimensions, if the per-unit stats are present
    samples_per_waveform = NaN; num_channels = NaN;
    if ~isempty(R.unit_stats) && isfield(R.unit_stats,'meanWaveforms') && ~isempty(R.unit_stats.meanWaveforms),
        sz = size(R.unit_stats.meanWaveforms); % nUnits x nSamples x nChannels
        if numel(sz)>=2, samples_per_waveform = sz(2); end;
        if numel(sz)>=3, num_channels = sz(3); end;
    end;

    % Step 7: assemble the info structure
    info = struct();
    info.directory = kdir;
    info.res_dir = R.res_dir;
    info.suffix = R.suffix;
    info.num_units = nC;
    info.unit_ids = unit_ids;
    info.unit_labels = unit_labels;
    info.unique_tags = unique_tags(:);
    info.tag_counts = tag_counts(:);
    info.num_spikes_total = numel(R.spike_units);
    info.num_spikes = num_spikes;
    info.would_import = would_import;
    info.num_would_import = sum(would_import);
    info.samples_per_waveform = samples_per_waveform;
    info.num_channels = num_channels;

    % Step 8: build the multiline character summary
    nl = newline;
    lines = {};
    lines{end+1} = ['KIASORT summary for probe ''' probe.elementstring() ''''];
    lines{end+1} = ['  Directory:        ' R.res_dir];
    if ~isempty(R.suffix),
        lines{end+1} =  '  Output:           curated';
    end;
    lines{end+1} = ['  Units:            ' int2str(nC)];
    lines{end+1} = ['  Total spikes:     ' int2str(info.num_spikes_total)];
    if nC>0,
        lines{end+1} = ['  Spikes/unit:      min ' int2str(min(num_spikes)) ...
            ', median ' int2str(round(median(num_spikes))) ...
            ', max ' int2str(max(num_spikes))];
    end;
    lines{end+1} = '  Tags:';
    for i=1:numel(unique_tags),
        lines{end+1} = ['     ' char(unique_tags(i)) ': ' int2str(tag_counts(i)) ' unit(s)'];
    end;
    lines{end+1} = ['  Would import (' char(strjoin(options.quality_labels,', ')) '): ' ...
        int2str(info.num_would_import) ' of ' int2str(nC) ' unit(s)'];
    if ~isnan(samples_per_waveform),
        lines{end+1} = ['  Mean waveforms:   ' num2str(num_channels) ' channels, ' ...
            num2str(samples_per_waveform) ' samples each'];
    else,
        lines{end+1} = '  Mean waveforms:   (sorted_samples.mat not present)';
    end;

    summary = strjoin(lines, nl);

end
